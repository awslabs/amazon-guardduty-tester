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

import { FindingLambdaProps } from '../../compute/lambda/finding-lambda';

/**
 * Simple IAM role with no permissions that can be assumed by lambda function
 * Used for GuardDuty finding generating lambda function.
 */
export class FindingLambdaRole extends Construct {
  public readonly role: Role;
  constructor(scope: Construct, id: string, props: FindingLambdaProps) {
    super(scope, id);

    this.role = new Role(this, id, {
      assumedBy: new ServicePrincipal('lambda.amazonaws.com'),
      inlinePolicies: {
        EcsTaskExecInline: new PolicyDocument({
          statements: [
            new PolicyStatement({
              effect: Effect.ALLOW,
              actions: ['logs:CreateLogStream', 'logs:CreateLogGroup', 'logs:PutLogEvents'],
              resources: [`arn:aws:logs:${props.region}:${props.accountId}:*`],
            }),
          ],
        }),
      },
    });
  }
}
