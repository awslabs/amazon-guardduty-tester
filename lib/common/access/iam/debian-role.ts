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

export interface DebianRoleProps {
  bucketName: string;
  accountId: string;
  region: string;
  eks: string;
  tempRoleArn: string;
}

/**
 * Define IAM Role assumed by Debian Linux Instance
 * Gives permissions required to run specific subset
 * of the tests on the Debian Instance
 */
export class DebianLinuxRole extends Construct {
  public readonly role: Role;
  constructor(scope: Construct, id: string, props: DebianRoleProps) {
    super(scope, id);

    this.role = new Role(this, id, {
      assumedBy: new ServicePrincipal('ec2.amazonaws.com'),
      managedPolicies: [ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore')],
      inlinePolicies: {
        DebianInlinePolicy: new PolicyDocument({
          statements: [
            new PolicyStatement({
              sid: 'S3FindingSpecific',
              effect: Effect.ALLOW,
              actions: ['s3:GetObject', 's3:ListBucket'],
              resources: [`arn:aws:s3:::${props.bucketName}`, `arn:aws:s3:::${props.bucketName}/*`],
            }),
            new PolicyStatement({
              sid: 'S3Finding',
              effect: Effect.ALLOW,
              actions: ['s3:ListAllMyBuckets'],
              resources: ['*'],
            }),
            new PolicyStatement({
              sid: 'IamFinding',
              effect: Effect.ALLOW,
              actions: ['iam:GetUser'],
              resources: [`arn:aws:iam::${props.accountId}:user/*`],
            }),
            new PolicyStatement({
              sid: 'AssumeTempRole',
              effect: Effect.ALLOW,
              actions: ['sts:AssumeRole'],
              resources: [props.tempRoleArn],
            }),
            new PolicyStatement({
              sid: 'KubectlPermissions',
              effect: Effect.ALLOW,
              actions: ['eks:DescribeCluster', 'eks:DescribeNodegroup'],
              resources: [`arn:aws:eks:${props.region}:${props.accountId}:cluster/${props.eks}`],
            }),
          ],
        }),
      },
    });
  }
}
