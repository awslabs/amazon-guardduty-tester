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
import { BlockDevice, BlockDeviceVolume, EbsDeviceVolumeType, Instance, MachineImage, Peer, Port, SecurityGroup, SubnetType, UserData } from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

import { UbuntuRole } from '../../access/iam/ubuntu-role';
import { type Ec2Props } from './ec2-props';

/**
 * Ubuntu 22 EC2 instance in private subnet with SSM access
 */
export interface UbuntuProps extends Ec2Props {
  bucketName: string;
  accountId: string;
}

export class UbuntuInstance extends Construct {
  public readonly ec2: Instance;
  public readonly instanceRole: UbuntuRole;

  constructor(scope: Construct, id: string, props: UbuntuProps) {
    super(scope, id);

    // Create Ubuntu-specific IAM role
    
    this.instanceRole = new UbuntuRole(scope, 'UbuntuRole', {
      bucketName: props.bucketName,
      region: props.region!,
      accountId: props.accountId,
    });

    // Security group for Ubuntu instance
    const securityGroup = new SecurityGroup(this, 'UbuntuSecurityGroup', {
      vpc: props.vpc,
      description: 'Security group for Ubuntu GuardDuty tester instance',
      allowAllOutbound: true,
    });

    // User data for basic setup
    const userData = UserData.forLinux();
    const homeDir = '/home/ssm-user';
    const region = props.region!;

    userData.addCommands(
      'apt-get update -y',
      'apt-get install -y awscli',
      'snap install amazon-ssm-agent --classic',
      'systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service',
      'systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service',
      'apt install awscli -y',
      `aws s3 cp --recursive s3://${props.bucketName}/py_tester ${homeDir}/py_tester`,
      `find  ${homeDir}/py_tester/runtimeScenarios -name "*.sh" -exec chmod +x {} \\;`,
      `find  ${homeDir}/py_tester/runtimeScenarios -name "*.py" -exec chmod +x {} \\;`,
      `chown -R ssm-user: ${homeDir}`, 
      'TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`',
      'INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)',
      `aws ssm send-command --region ${region} --instance-ids \$INSTANCE_ID --document-name "AmazonGuardDuty-ConfigureRuntimeMonitoringSsmPlugin" --parameters "action=Install,name=AmazonGuardDuty-RuntimeMonitoringSsmPlugin" --output text`
    );

    // Create Ubuntu 22.04 LTS instance
    this.ec2 = new Instance(this, 'UbuntuInstance', {
      vpc: props.vpc,
      vpcSubnets: { subnetType: SubnetType.PRIVATE_WITH_EGRESS },
      instanceType: props.instanceType,
      machineImage: MachineImage.fromSsmParameter(
        '/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id'
      ),
      role: this.instanceRole.role,
      securityGroup: securityGroup,
      userData: userData,
      userDataCausesReplacement: true,
      requireImdsv2: true,
      blockDevices: [
        {
          deviceName: '/dev/sda1',
          volume: BlockDeviceVolume.ebs(32, {
            volumeType: EbsDeviceVolumeType.GP3,
          }),
        },
      ],
    });

    // Apply tags
    Tags.of(this.ec2).add(props.tag.key, props.tag.value);
    Tags.of(this.ec2).add(props.createdBy.key, props.createdBy.value);
    Tags.of(this.ec2).add('Name', props.instanceName);
  }
}
