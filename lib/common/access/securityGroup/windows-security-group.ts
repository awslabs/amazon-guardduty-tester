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

import { Peer, Port, SecurityGroup } from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

import { type SecGroupProps } from './security-group-props';

/**
 * Defines the permissible traffic to and from the Windows Instance
 */
export class WindowsSecurityGroup extends Construct {
  public readonly sg: SecurityGroup;

  constructor(scope: Construct, id: string, props: SecGroupProps) {
    super(scope, id);
    this.sg = new SecurityGroup(this, id, {
      vpc: props.vpc,
    });

    // only allow RDP traffic from within VPC
    this.sg.addIngressRule(Peer.ipv4(props.vpc.vpcCidrBlock), Port.tcp(3389), 'allow rdp connection from within vpc');
  }
}
