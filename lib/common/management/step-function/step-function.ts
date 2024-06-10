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

import { Duration } from 'aws-cdk-lib';
import { DefinitionBody, StateMachine, Wait, WaitTime } from 'aws-cdk-lib/aws-stepfunctions';
import { LambdaInvoke } from 'aws-cdk-lib/aws-stepfunctions-tasks';
import { Construct } from 'constructs';

import { SettingRestorationLambda } from '../../compute/lambda/test-settings-lambda';

export interface SettingRestoreStepFuncProps {
  accountId: string;
  region: string;
}

export class SettingRestoreStepFunc extends Construct {
  public readonly machineArn: string;
  constructor(scope: Construct, id: string, props: SettingRestoreStepFuncProps) {
    super(scope, id);
    const settingLambda = new SettingRestorationLambda(this, 'Lambda', {
      region: props.region,
      accountId: props.accountId,
    });

    const definition = new Wait(this, 'Wait15Min', {
      time: WaitTime.duration(Duration.minutes(15)),
    }).next(
      new LambdaInvoke(this, 'SettingsJob', {
        lambdaFunction: settingLambda.func,
      }),
    );

    const stateMachine = new StateMachine(this, 'StateMachine', {
      definitionBody: DefinitionBody.fromChainable(definition),
      timeout: Duration.minutes(25),
    });

    settingLambda.func.grantInvoke(stateMachine);
    this.machineArn = stateMachine.stateMachineArn;
  }
}
