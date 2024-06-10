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

import { GenericLinuxImage, Instance, SubnetType, UserData } from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

import { KaliLinuxRole } from '../../access/iam/kali-role';
import { KaliSecurityGroup } from '../../access/securityGroup/kali-security-group';
import { type CfnActionLambda } from '../lambda/cfn-action-lambda';
import { type Ec2Props } from './ec2-props';

export interface KaliProps extends Ec2Props {
  amiLambda: CfnActionLambda;
  bucketName: string;
  accountId: string;
  eksCluster: string;
  tempRole: string;
}

/**
 * Defines the resources for a Kali Linux instance in GaurdDuty
 * Tester public sunet.  Kali goes in the public subnet so that it
 * has a public IP address as required by some tests
 */
export class KaliLinuxInstance extends Construct {
  public readonly ec2: Instance;
  public readonly instanceRole: KaliLinuxRole;
  public readonly sgId: string;

  constructor(scope: Construct, id: string, props: KaliProps) {
    super(scope, id);

    // IAM role that instance will assume
    this.instanceRole = new KaliLinuxRole(scope, 'Role', {
      bucketName: props.bucketName,
      accountId: props.accountId,
      region: props.region!,
      eks: props.eksCluster,
      tempRoleArn: props.tempRole,
    });

    // kali security group that defines permissible traffic
    const securityGroup = new KaliSecurityGroup(this, 'SecurityGroup', {
      vpc: props.vpc,
      ingressSgId: props.securityGroupIngress!,
    });

    this.sgId = securityGroup.sg.securityGroupId;

    this.ec2 = new Instance(this, id, {
      vpc: props.vpc,
      instanceType: props.instanceType,
      machineImage: new GenericLinuxImage(this.getKaliImage(props)),
      vpcSubnets: props.vpc.selectSubnets({ subnetType: SubnetType.PUBLIC }),
      associatePublicIpAddress: true,
      userData: this.getUserData(),
      role: this.instanceRole.role,
      securityGroup: securityGroup.sg,
      instanceName: props.instanceName,
    });
  }

  /**
   * With Custom Resource Lambda query Kali Linux Image AMI for the given region
   * @param props
   * @returns map of [region] -> instance-ami
   */
  private getKaliImage(props: KaliProps): Record<string, string> {
    return {
      [props.region!]: props.amiLambda.customResourceLambda.getAtt('Id').toString(),
    };
  }

  /**
   * Defines user data for Kali Linux that installs necessary libraries for testing
   * @returns
   */
  private getUserData(): UserData {
    const homeDir = '/home/ssm-user';
    const install = 'apt-get install -y';

    const userData = UserData.forLinux();
    userData.addCommands(
      '#!/bin/bash',
      'export DEBIAN_FRONTEND=noninteractive',
      'mkdir /etc/systemd/resolved.conf.d',
      `echo '[Resolve]\nDNS=169.254.169.253' | tee /etc/systemd/resolved.conf.d/aws.conf`,
      'adduser ssm-user',
      'echo "ssm-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ssm-agent-users',
      'chmod 440 /etc/sudoers.d/ssm-agent-users',
      'systemctl restart systemd-resolved',
      'export PATH=$PATH:/usr/local/bin:/usr/sbin:/root/.local/bin',
      `echo 'export PATH=/root/.local/bin:/usr/sbin:/home/kali/.local/bin:$PATH' >> /home/kali/.bash_profile`,
      'apt-get update -y',
      `${install} nmap hydra jq python3-pip python3 tor freerdp2-dev libssl-dev postgresql-common libpq-dev`,
      'curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"',
      'unzip awscliv2.zip',
      './aws/install',
      `mkdir ${homeDir}/passwords`,
      `curl -L https://raw.githubusercontent.com/awslabs/amazon-guardduty-tester/master/artifacts/password_list.txt > ${homeDir}/passwords/password_list.txt`,
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
      'curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.27.1/bin/linux/amd64/kubectl',
      'chmod +x ./kubectl',
      'mv ./kubectl /usr/local/bin/kubectl',
      'mkdir /tmp/ssm',
      'cd /tmp/ssm',
      'wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb',
      'dpkg -i amazon-ssm-agent.deb',
      'systemctl enable amazon-ssm-agent',
      'systemctl start amazon-ssm-agent',
      `bash -c 'echo "ControlPort 9051" >> /etc/tor/torrc'`,
      `bash -c 'echo "CookieAuthentication 0" >> /etc/tor/torrc'`,
      'pip3 install awscurl aws-consoler',
      'service tor start',
      `chown -R ssm-user: ${homeDir}`,
      'nc -k -l 8009',
    );
    return userData;
  }
}
