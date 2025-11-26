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

import { Effect, ManagedPolicy, PolicyDocument, PolicyStatement, Role, ServicePrincipal } from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

/**
 * Define IAM Role for Ubuntu instance with SSM access
 */

export interface UbuntuRoleProps {
  bucketName: string;
  region: string;
  accountId: string;
}

export class UbuntuRole extends Construct {
  public readonly role: Role;

  constructor(scope: Construct, id: string, props: UbuntuRoleProps) {
    super(scope, id);

    this.role = new Role(this, 'UbuntuInstanceRole', {
      assumedBy: new ServicePrincipal('ec2.amazonaws.com'),
      description: 'IAM role for Ubuntu GuardDuty tester instance',
      managedPolicies: [ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore')],
      inlinePolicies: {
        UbuntuInlinePolicy: new PolicyDocument({
          statements: [
            new PolicyStatement({
              sid: 'TesterS3BucketSpecific',
              effect: Effect.ALLOW,
              actions: ['s3:GetObject', 's3:ListBucket'],
              resources: [`arn:aws:s3:::${props.bucketName}`, `arn:aws:s3:::${props.bucketName}/*`],
            }),
            new PolicyStatement({
              sid: 'InstallGuardDutyAgent',
              effect: Effect.ALLOW,
              actions: ['ssm:SendCommand'],
              resources: [
                `arn:aws:ec2:${props.region}:${props.accountId}:instance/*`,
                `arn:aws:ssm:${props.region}::document/AmazonGuardDuty-ConfigureRuntimeMonitoringSsmPlugin`,
              ],
            }),
	  ]
	})
      }
    });

    // Add SSM managed policy for SSM access
    //this.role.addManagedPolicy(
    //  ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore')
    //);
  }
}
