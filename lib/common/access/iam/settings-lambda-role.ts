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

import { SettingRestorationLambdaProps } from '../../compute/lambda/test-settings-lambda';

/**
 * IAM role for Setting Restore lambda
 */
export class SettingRestorationLambdaRole extends Construct {
  public readonly role: Role;
  constructor(scope: Construct, id: string, props: SettingRestorationLambdaProps) {
    super(scope, id);
    this.role = new Role(this, id, {
      assumedBy: new ServicePrincipal('lambda.amazonaws.com'),
      inlinePolicies: {
        SettingRestorationLambdaPolicy: new PolicyDocument({
          statements: [
            new PolicyStatement({
              sid: 'LambdaLogging',
              effect: Effect.ALLOW,
              actions: ['logs:CreateLogGroup', 'logs:CreateLogStream', 'logs:PutLogEvents'],
              resources: [`arn:aws:logs:${props.region}:${props.accountId}:*`],
            }),
            new PolicyStatement({
              sid: 'RestoreGuardDutySettings',
              effect: Effect.ALLOW,
              actions: ['guardduty:UpdateDetector'],
              resources: [`arn:aws:guardduty:${props.region}:${props.accountId}:detector/*`],
            }),
            new PolicyStatement({
              sid: 'GuardDutyServicePolicy',
              effect: Effect.ALLOW,
              actions: ['iam:GetRole', 'iam:PutRolePolicy'],
              resources: [
                `arn:aws:iam::${props.accountId}:role/aws-service-role/guardduty.amazonaws.com/AWSServiceRoleForAmazonGuardDuty`,
                `arn:aws:iam::${props.accountId}:role/aws-service-role/guardduty.amazonaws.com/AWSServiceRoleForAmazonGuardDutyMalwareProtection`,
              ],
            }),
            new PolicyStatement({
              sid: 'RestoreS3PublicAccessBlock',
              effect: Effect.ALLOW,
              actions: ['s3:PutAccountPublicAccessBlock'],
              resources: ['*'],
            }),
          ],
        }),
      },
    });
  }
}
