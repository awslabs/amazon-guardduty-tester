//Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License").
//  You may not use this file except in compliance with the License.
//  A copy of the License is located at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  or in the "license" file accompanying this file. This file is distributed
//  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
//  express or implied. See the License for the specific language governing
//  permissions and limitations under the License.

import { Tags } from 'aws-cdk-lib';
import { AutoScalingGroup } from 'aws-cdk-lib/aws-autoscaling';
import { LaunchTemplate, MachineImage, UserData } from 'aws-cdk-lib/aws-ec2';
import { AsgCapacityProvider, Cluster } from 'aws-cdk-lib/aws-ecs';
import { InstanceProfile } from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

import { DriverRole } from '../../access/iam/driver-role';
import { ClusterSecurityGroup } from '../../access/securityGroup/cluster-security-group';
import { type Ec2Props } from '../ec2/ec2-props';
import { TesterEcsService } from './tester-service';

export interface EcsProps extends Ec2Props {
  ingressSecurityGroup: string;
  maliciousIp: string;
  kaliIp: string;
  kaliInstance: string;
  kaliRoleName: string;
  windowsIp: string;
  windowsInstance: string;
  bucketName: string;
  tempRole: string;
  accountId: string;
  cloudTrailName: string;
  cloudTrailArn: string;
  lambdaName: string;
  lambdaArn: string;
  eksCluster: string;
  asgName: string;
  ecsCluster: string;
  stepFuncArn: string;
  emptyBucketName: string;
}

/**
 * Class that defines ECS Driver Cluster host and containers
 */
export class TestDriverEcsCluster extends Construct {
  public readonly instanceRole: DriverRole;
  constructor(scope: Construct, id: string, props: EcsProps) {
    super(scope, id);

    const cluster = new Cluster(this, id, {
      vpc: props.vpc,
      clusterName: props.ecsCluster,
    });

    // ECS service with task for ECS runtime tests
    const service = new TesterEcsService(this, 'Service', {
      cluster,
      bucketName: props.bucketName,
      accountId: props.accountId,
      region: props.region!,
    });

    // role to be assumed by host instance
    this.instanceRole = new DriverRole(this, 'InstanceRole', {
      bucketName: props.bucketName,
      emptyBucketName: props.emptyBucketName,
      accountId: props.accountId,
      trailArn: props.cloudTrailArn,
      lambdaArn: props.lambdaArn,
      region: props.region!,
      kaliId: props.kaliInstance,
      cluster: cluster.clusterName,
      eks: props.eksCluster,
      stepFuncArn: props.stepFuncArn,
      taskArn: service.taskArn,
      clusterName: props.ecsCluster,
    });

    // launch template for cluster
    const launchTemplate = new LaunchTemplate(this, 'LaunchTemplate', {
      instanceType: props.instanceType,
      machineImage: MachineImage.fromSsmParameter(
        '/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id',
      ),
      userData: this.getUserData(props),
      securityGroup: new ClusterSecurityGroup(this, 'ClusterSecurityGroup', {
        vpc: props.vpc,
        ingressSgId: props.ingressSecurityGroup,
      }).sg,
      instanceProfile: new InstanceProfile(this, 'InstanceProfile', {
        role: this.instanceRole.role,
      }),
    });

    // host instance name
    Tags.of(launchTemplate).add('Name', props.instanceName);

    // Define cluster capacity provider with defined launch template
    cluster.addAsgCapacityProvider(
      new AsgCapacityProvider(this, 'CapacityProvider', {
        enableManagedTerminationProtection: false,
        autoScalingGroup: new AutoScalingGroup(this, 'ASG', {
          vpc: props.vpc,
          minCapacity: 1,
          maxCapacity: 1,
          desiredCapacity: 1,
          launchTemplate,
          autoScalingGroupName: props.asgName,
        }),
      }),
    );
  }

  /**
   * ECS Cluster host user data installs testing libraries, writes variables used by the tester
   * and installs GuardDuty and SSM agents
   * @param props
   * @param roleName
   * @param clusterName
   * @returns UserData for instance
   */
  private getUserData(props: EcsProps): UserData {
    const region = props.region!;
    const homeDir = '/home/ssm-user';
    const install = 'yum install -y';

    const userData = UserData.forLinux();
    userData.addCommands(
      '#!/bin/bash',
      'systemctl stop amazon-ssm-agent',
      `echo ECS_CLUSTER='${props.ecsCluster}'>> /etc/ecs/ecs.config`,
      'adduser -m ssm-user',
      'echo "ssm-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ssm-agent-users',
      'chmod 440 /etc/sudoers.d/ssm-agent-users',
      'yum update -y',
      `${install} zip unzip wget nmap git python3-pip gcc glib2-devel cmake3 gcc-c++ openssl-devel libX11-devel libXi-devel libXtst-devel libXinerama-devel libusb-devel libusb-devel bind-utils jq libpcap-devel`,
      'curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip',
      'unzip awscliv2.zip',
      './aws/install',
      'PATH=$PATH:/usr/local/bin',
      'pip3 install argparse envbash boto3 paramiko scapy',
      'systemctl start amazon-ssm-agent',
      'TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`',
      'INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)',
      `aws ssm send-command --region ${region} --instance-ids \$INSTANCE_ID --document-name "AmazonGuardDuty-ConfigureRuntimeMonitoringSsmPlugin" --parameters "action=Install,name=AmazonGuardDuty-RuntimeMonitoringSsmPlugin" --output text`,
      `mkdir ${homeDir}/compromised_keys`,
      `mkdir ${homeDir}/domains`,
      `mkdir ${homeDir}/passwords`,
      `curl -L https://raw.githubusercontent.com/awslabs/amazon-guardduty-tester/master/artifacts/queries.txt > ${homeDir}/domains/queries.txt`,
      `curl -L https://raw.githubusercontent.com/awslabs/amazon-guardduty-tester/master/artifacts/password_list.txt > ${homeDir}/passwords/password_list.txt`,
      `curl -L https://raw.githubusercontent.com/awslabs/amazon-guardduty-tester/master/artifacts/never_used_sample_key.foo > ${homeDir}/compromised_keys/compromised.pem`,
      `FILE="${homeDir}/compromised_keys/compromised.pem"`,
      `for FILE in {1..20}; do cp ${homeDir}/compromised_keys/compromised.pem ${homeDir}/compromised_keys/compromised$FILE.pem; done`,
      `sed -i 's/loganding123test.com/guarddutyc2activityb.com/g' ${homeDir}/domains/queries.txt`,
      `aws s3 cp --recursive s3://${props.bucketName}/py_tester ${homeDir}/py_tester`,
      `echo "LINUX_IP = '${props.kaliIp}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "WINDOWS_IP = '${props.windowsIp}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "RED_TEAM_INSTANCE = '\$INSTANCE_ID'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "RED_TEAM_IP = '$(curl -H "X-aws-ec2-metadata-token: \$TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4 | grep "172")'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "LINUX_INSTANCE = '${props.kaliInstance}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "WINDOWS_INSTANCE = '${props.windowsInstance}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "S3_BUCKET_NAME = '${props.bucketName}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "EMPTY_BUCKET_NAME = '${props.emptyBucketName}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "TEMP_ROLE_ARN = '${props.tempRole}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "REGION = '${region}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "ACCNT_ID = '${props.accountId}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "CLOUD_TRAIL_NAME = '${props.cloudTrailName}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "EKS_CLUSTER_NAME = '${props.eksCluster}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "MALICIOUS_IP = '${props.maliciousIp}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "LAMBDA_NAME = '${props.lambdaName}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "ROLE_NAME = '${props.kaliRoleName}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "CLUSTER = '${props.ecsCluster}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "CONTAINER = 'amazon-linux'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo "STEP_FUNCTION = '${props.stepFuncArn}'" >> ${homeDir}/py_tester/tester_vars.py`,
      `echo ${props.maliciousIp} >> ${homeDir}/py_tester/tester_script_custom_threat.txt`,
      'pip3 install cmake',
      `wget -q -O ${homeDir}/libssh.tar.xz https://www.libssh.org/files/0.9/libssh-0.9.4.tar.xz`,
      `cd ${homeDir}`,
      'cat << EOF >> users',
      'ec2-user',
      'root',
      'admin',
      'administrator',
      'ftp',
      'www',
      'nobody',
      'EOF',
      `tar -xvf ${homeDir}/libssh.tar.xz`,
      `cd ${homeDir}/libssh-0.9.4`,
      'mkdir build',
      'cd build',
      'cmake3 -DUNIT_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release ..',
      'make && make install',
      `cd ${homeDir}`,
      'git clone https://github.com/vanhauser-thc/thc-hydra',
      'cd thc-hydra',
      './configure',
      'make && make install',
      `cd ${homeDir}`,
      `git clone https://github.com/galkan/crowbar ${homeDir}/crowbar`,
      `cd ${homeDir}`,
      'curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.27.1/bin/linux/amd64/kubectl',
      'chmod +x ./kubectl',
      'mv ./kubectl /usr/local/bin/kubectl',
      'curl --silent --location https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz | tar xz -C /tmp',
      'mv /tmp/eksctl /usr/local/bin/',
      `chown -R ssm-user: ${homeDir}`,
      `chmod +x ${homeDir}/crowbar/crowbar.py`,
      `${install} https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm`,
      'wget https://secure.eicar.org/eicar.com',
      'wget https://secure.eicar.org/eicar.com.txt',
      'wget https://secure.eicar.org/eicar_com.zip',
      'wget https://secure.eicar.org/eicarcom2.zip',
      'echo DONE',
    );
    return userData;
  }
}
