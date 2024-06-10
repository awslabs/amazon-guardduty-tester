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

import { RemovalPolicy } from 'aws-cdk-lib';
import { InterfaceVpcEndpoint, InterfaceVpcEndpointService, IpAddresses, SubnetType, Vpc } from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

export interface VpcProps {
  region: string;
}

/**
 * VPC infrastructure for GuardDuty tester
 * Two subnets over two availability zones
 */
export class CdkGdTesterVPC extends Construct {
  public readonly vpc: Vpc;
  constructor(scope: Construct, id: string, props: VpcProps) {
    super(scope, id);

    const quarterSplitMask = 26;

    this.vpc = new Vpc(this, 'vpc', {
      ipAddresses: IpAddresses.cidr('172.16.0.0/24'),
      maxAzs: 2,
      subnetConfiguration: [
        {
          cidrMask: quarterSplitMask,
          name: 'private-subnet',
          subnetType: SubnetType.PRIVATE_WITH_EGRESS,
        },
        {
          cidrMask: quarterSplitMask,
          name: 'public-subnet',
          subnetType: SubnetType.PUBLIC,
        },
      ],
    });

    // GuardDuty runtime monitoring vpc endpoint
    const vpcEndpoint = new InterfaceVpcEndpoint(this, 'GuardDutyEndpoint', {
      vpc: this.vpc,
      service: new InterfaceVpcEndpointService(`com.amazonaws.${props.region}.guardduty-data`, 443),
      privateDnsEnabled: true,
    });

    vpcEndpoint.applyRemovalPolicy(RemovalPolicy.DESTROY);
    this.vpc.applyRemovalPolicy(RemovalPolicy.DESTROY);
  }
}
