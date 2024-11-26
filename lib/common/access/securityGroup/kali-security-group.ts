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

import { CfnEIP, Peer, Port, SecurityGroup } from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

import { type SecGroupProps } from './security-group-props';

/**
 * Defines the permissible traffic to and from the Kali Linux Instance
 */
export class KaliSecurityGroup extends Construct {
  public readonly sg: SecurityGroup;

  constructor(scope: Construct, id: string, props: SecGroupProps) {
    super(scope, id);
    this.sg = new SecurityGroup(this, id, {
      vpc: props.vpc,
      allowAllOutbound: true,
    });

    // Add ingress rules for NAT Gateway EIPs
    props.vpc.publicSubnets.forEach((subnet, index) => {
      const eipAllocation = subnet.node.findChild('EIP') as CfnEIP;
      if (eipAllocation) {
        this.sg.addIngressRule(
            Peer.ipv4(eipAllocation.attrPublicIp + '/32'),
            Port.allTraffic(),
            `Allow traffic from NAT Gateway ${index + 1}`
        );
      }
    });

    // allow TCP, UDP from within the VPC
    this.sg.addIngressRule(Peer.ipv4(props.vpc.vpcCidrBlock), Port.tcp(8009), 'allow tcp connection from within vpc'); // for ec2 malicious IP custom finding
    this.sg.addIngressRule(Peer.ipv4(props.vpc.vpcCidrBlock), Port.tcp(22), 'allow ssh connection from within vpc'); // for ssh brute force finding
    this.sg.addIngressRule(
      Peer.ipv4(props.vpc.vpcCidrBlock),
      Port.udp(80),
      'allow udp port 80 connection from within vpc',
    ); // for udp dos finding
    this.sg.addIngressRule(
      Peer.ipv4(props.vpc.vpcCidrBlock),
      Port.udp(53),
      'allow udp port 53 connection from within vpc',
    ); // for dns dos finding
  }
}
