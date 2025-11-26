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

import { Effect, PolicyDocument, PolicyStatement, Role, ServicePrincipal } from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

import { type CfnLambdaProps } from '../../compute/lambda/lambda-props';

/**
 * IAM role for Custom Resource lambda for cleaning up the
 * environment after testing
 * The permissions needed to handle the CFN events
 * Delete objects in tester bucket
 * Delete custom threat list if uploaded
 * Delete ECR repo from EKS runtime testing
 */
export class CfnActionLambdaRole extends Construct {
  public readonly role: Role;
  constructor(scope: Construct, id: string, props: CfnLambdaProps) {
    super(scope, id);
    this.role = new Role(this, id, {
      assumedBy: new ServicePrincipal('lambda.amazonaws.com'),
      inlinePolicies: {
        CfnActionLambdaPolicy: new PolicyDocument({
          statements: [
            new PolicyStatement({
              sid: 'LambdaLogging',
              effect: Effect.ALLOW,
              actions: ['logs:CreateLogGroup', 'logs:CreateLogStream', 'logs:PutLogEvents'],
              resources: [`arn:aws:logs:${props.region}:${props.accountId}:*`],
            }),
            new PolicyStatement({
              sid: 'GuardDutyCleanupOnDelete',
              effect: Effect.ALLOW,
              actions: [
                'guardduty:DeleteThreatIntelSet',
                'guardduty:GetDetector',
                'guardduty:GetThreatIntelSet',
                'guardduty:ListDetectors',
                'guardduty:ListThreatIntelSets',
              ],
              resources: [`arn:aws:guardduty:${props.region}:${props.accountId}:detector/*`],
            }),
            new PolicyStatement({
              sid: 'GuardDutyServiceRoleThreatListCleanup',
              effect: Effect.ALLOW,
              actions: ['iam:DeleteRolePolicy'],
              resources: [
                `arn:aws:iam::${props.accountId}:role/aws-service-role/guardduty.amazonaws.com/AWSServiceRoleForAmazonGuardDuty`,
              ],
            }),
            new PolicyStatement({
              sid: 'FindDebianImagePermission',
              effect: Effect.ALLOW,
              actions: ['ec2:DescribeImages'],
              resources: ['*'], // this EC2 api is only supported with all resources wildcard('*').
            }),
            new PolicyStatement({
              sid: 'EksPodImageRepositoryDelete',
              effect: Effect.ALLOW,
              actions: ['ecr:DeleteRepository'],
              resources: [`arn:aws:ecr:${props.region}:${props.accountId}:repository/${props.ecrRepo}`],
            }),
          ],
        }),
      },
    });
  }
}
