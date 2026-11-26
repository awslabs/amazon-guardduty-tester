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

import { type Tag, Tags } from 'aws-cdk-lib';
import {
  BlockDeviceVolume,
  EbsDeviceVolumeType,
  Instance,
  MachineImage,
  SecurityGroup,
  SubnetType,
  UserData,
} from 'aws-cdk-lib/aws-ec2';
import { Effect, ManagedPolicy, PolicyStatement, Role, ServicePrincipal } from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

import { type Ec2Props } from './ec2-props';

export interface CdrAmazonLinuxProps extends Ec2Props {
  accountId: string;
  // Extra tag that lets the test harness find this host at run time.
  hostTag: Tag;
}

/**
 * Amazon Linux 2023 EC2 instance in a private subnet that runs runtime Custom
 * Detection Rule tests. It has no inbound access: the driver reaches it only
 * through SSM, and the GuardDuty Runtime Monitoring agent is installed at boot.
 */
export class CdrAmazonLinuxInstance extends Construct {
  public readonly ec2: Instance;
  public readonly role: Role;

  constructor(scope: Construct, id: string, props: CdrAmazonLinuxProps) {
    super(scope, id);

    const region = props.region!;

    this.role = new Role(this, 'Role', {
      assumedBy: new ServicePrincipal('ec2.amazonaws.com'),
      description: 'IAM role for a GuardDuty tester Custom Detection Rule host',
      managedPolicies: [ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore')],
    });
    // The instance installs the GuardDuty Runtime Monitoring agent on itself at boot.
    this.role.addToPolicy(
      new PolicyStatement({
        sid: 'InstallGuardDutyAgent',
        effect: Effect.ALLOW,
        actions: ['ssm:SendCommand'],
        resources: [
          `arn:aws:ec2:${region}:${props.accountId}:instance/*`,
          `arn:aws:ssm:${region}::document/AmazonGuardDuty-ConfigureRuntimeMonitoringSsmPlugin`,
        ],
      }),
    );

    const securityGroup = new SecurityGroup(this, 'SecurityGroup', {
      vpc: props.vpc,
      description: 'Security group for a GuardDuty tester Custom Detection Rule host (no inbound)',
      allowAllOutbound: true,
    });

    // The Amazon Linux 2023 AMI already ships the SSM agent and the AWS CLI.
    const userData = UserData.forLinux();
    userData.addCommands(
      'TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`',
      'INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)',
      `aws ssm send-command --region ${region} --instance-ids $INSTANCE_ID --document-name "AmazonGuardDuty-ConfigureRuntimeMonitoringSsmPlugin" --parameters "action=Install,name=AmazonGuardDuty-RuntimeMonitoringSsmPlugin" --output text`,
    );

    this.ec2 = new Instance(this, 'Instance', {
      vpc: props.vpc,
      vpcSubnets: { subnetType: SubnetType.PRIVATE_WITH_EGRESS },
      instanceType: props.instanceType,
      machineImage: MachineImage.latestAmazonLinux2023(),
      role: this.role,
      securityGroup,
      userData,
      userDataCausesReplacement: true,
      requireImdsv2: true,
      blockDevices: [
        {
          deviceName: '/dev/xvda',
          volume: BlockDeviceVolume.ebs(8, {
            volumeType: EbsDeviceVolumeType.GP3,
            encrypted: true,
          }),
        },
      ],
    });

    Tags.of(this.ec2).add(props.tag.key, props.tag.value);
    Tags.of(this.ec2).add(props.createdBy.key, props.createdBy.value);
    Tags.of(this.ec2).add(props.hostTag.key, props.hostTag.value);
    Tags.of(this.ec2).add('Name', props.instanceName);
  }
}
