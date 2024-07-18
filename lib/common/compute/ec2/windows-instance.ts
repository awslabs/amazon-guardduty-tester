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
import { Instance, SubnetType, WindowsImage, WindowsVersion } from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

import { WindowsSecurityGroup } from '../../access/securityGroup/windows-security-group';
import { type Ec2Props } from './ec2-props';

/**
 * Defines Windows Instance for GuardDuty testing
 * Resides in private subnet and only allows rdp ingress from within vpc
 */
export class BasicWindowsInstance extends Construct {
  public readonly ec2: Instance;
  constructor(scope: Construct, id: string, props: Ec2Props) {
    super(scope, id);

    this.ec2 = new Instance(this, id, {
      vpc: props.vpc,
      instanceType: props.instanceType,
      machineImage: new WindowsImage(WindowsVersion.WINDOWS_SERVER_2022_ENGLISH_FULL_BASE),
      vpcSubnets: props.vpc.selectSubnets({
        subnetType: SubnetType.PRIVATE_WITH_EGRESS,
      }),
      securityGroup: new WindowsSecurityGroup(this, 'SecurityGroup', {
        vpc: props.vpc,
        ingressSgId: props.securityGroupIngress!,
      }).sg,
      associatePublicIpAddress: false,
      instanceName: props.instanceName,
    });

    Tags.of(this.ec2).add(props.tag.key, props.tag.value);
    Tags.of(this.ec2).add(props.createdBy.key, props.createdBy.value);
  }
}
