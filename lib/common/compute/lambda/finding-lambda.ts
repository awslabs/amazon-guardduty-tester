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

import path = require('path');
import { Duration } from 'aws-cdk-lib';
import { Code, Function, Runtime } from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';

import { FindingLambdaRole } from '../../access/iam/finding-lambda-role';

export interface FindingLambdaProps {
  accountId: string;
  region: string;
}

/**
 * TesterLambda class defines a lambda function that is used
 * to generate findings to demonstrate GuardDuty Lambda protection
 */
export class TesterLambda extends Construct {
  public readonly functionName: string;
  public readonly functionArn: string;
  constructor(scope: Construct, id: string, props: FindingLambdaProps) {
    super(scope, id);
    const func = new Function(this, id, {
      runtime: Runtime.PYTHON_3_11,
      handler: 'tester_lambda.lambda_handler',
      code: Code.fromAsset(path.join(__dirname, 'tester_lambda'), {
        bundling: {
          image: Runtime.PYTHON_3_11.bundlingImage,
          command: ['bash', '-c', 'pip install -r requirements.txt -t /asset-output && cp -au . /asset-output'],
        },
      }),
      timeout: Duration.seconds(900),
      role: new FindingLambdaRole(this, 'ExecutionRole', props).role,
    });

    this.functionName = func.functionName;
    this.functionArn = func.functionArn;
  }
}
