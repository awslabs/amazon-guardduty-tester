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

import { AccountPrincipal, Effect, PolicyDocument, PolicyStatement, Role } from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export interface TempRoleProps {
  accountId: string;
  bucketArn: string;
}

/**
 * Temporary role to be assumed by kali instance during testing
 */
export class TempRole extends Construct {
  public readonly arn: string;
  constructor(scope: Construct, id: string, props: TempRoleProps) {
    super(scope, id);

    const role = new Role(this, id, {
      assumedBy: new AccountPrincipal(props.accountId),
      inlinePolicies: {
        TempRolePolicy: new PolicyDocument({
          statements: [
            new PolicyStatement({
              sid: 'ListBucketForTest',
              effect: Effect.ALLOW,
              actions: ['s3:ListBucket'],
              resources: [props.bucketArn],
            }),
            new PolicyStatement({
              sid: 'ListAllMyBucketsForTest',
              effect: Effect.ALLOW,
              actions: ['s3:ListAllMyBuckets'],
              resources: ['*'],
            }),
          ],
        }),
      },
    });

    this.arn = role.roleArn;
  }
}
