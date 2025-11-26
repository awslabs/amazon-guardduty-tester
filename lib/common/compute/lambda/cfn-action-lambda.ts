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
import { CustomResource, Duration } from 'aws-cdk-lib';
import { Code, Function, Runtime } from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';

import { CfnActionLambdaRole } from '../../access/iam/cfn-action-lambda-role';
import { type CfnLambdaProps } from './lambda-props';

/**
 * Lambda function Custom Resource to handle Cloud Formation events
 * On create fetches Debian Linux ami
 * On delete cleans s3 bucket and deletes resources Cloud Formation cannot
 * Also deletes custom threat list if one was uploaded during testing
 */
export class CfnActionLambda extends Construct {
  public readonly customResourceLambda: CustomResource;
  constructor(scope: Construct, id: string, props: CfnLambdaProps) {
    super(scope, id);

    // declare lambda function
    const onEvent = new Function(this, 'onEventFunction', {
      runtime: Runtime.PYTHON_3_11,
      handler: 'cfn_on_event.on_event',
      code: Code.fromAsset(path.join(__dirname, 'cfn_on_event'), {
        bundling: {
          image: Runtime.PYTHON_3_11.bundlingImage,
          command: ['bash', '-c', 'pip install -r requirements.txt -t /asset-output && cp -au . /asset-output'],
        },
      }),
      timeout: Duration.seconds(900),
      memorySize: 512,
      role: new CfnActionLambdaRole(this, 'CfnGdTesterLambdaExecutionRole', {
        bucketArn: props.bucketArn,
        accountId: props.accountId,
        region: props.region,
        asgName: props.asgName,
        ecrRepo: props.ecrRepo,
      }).role,
    });

    // custom resource + event parameters
    this.customResourceLambda = new CustomResource(this, 'CfnGdTesterLambda', {
      serviceToken: onEvent.functionArn,
      properties: {
        region: props.region!,
        s3BucketName: props.bucketName!,
        asgName: props.asgName!,
        ecrRepoName: props.ecrRepo!,
      },
    });
  }
}
