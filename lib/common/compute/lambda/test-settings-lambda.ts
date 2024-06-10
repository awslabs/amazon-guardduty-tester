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
import { Code, Function as LambdaFunction, Runtime } from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';

import { SettingRestorationLambdaRole } from '../../access/iam/settings-lambda-role';

export interface SettingRestorationLambdaProps {
  region: string;
  accountId: string;
}

/**
 * SettingRestorationLambda class defines a lambda function that is used
 * to restore account settings after enough time to allow GuardDuty
 * to generate findings
 */
export class SettingRestorationLambda extends Construct {
  public readonly func: LambdaFunction;
  constructor(scope: Construct, id: string, props: SettingRestorationLambdaProps) {
    super(scope, id);
    this.func = new LambdaFunction(this, id, {
      runtime: Runtime.PYTHON_3_11,
      handler: 'setting_restore.lambda_handler',
      code: Code.fromAsset(path.join(__dirname, 'setting_restore'), {
        bundling: {
          image: Runtime.PYTHON_3_11.bundlingImage,
          command: ['bash', '-c', 'pip install -r requirements.txt -t /asset-output && cp -au . /asset-output'],
        },
      }),
      timeout: Duration.seconds(900),
      role: new SettingRestorationLambdaRole(this, 'ExecutionRole', props).role,
    });
  }
}
