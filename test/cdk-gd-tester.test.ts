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

import { App } from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';

import { GuardDutyTesterStack } from '../lib//stacks/tester-stack';

test('Check All Test Resources', () => {
  const app = new App();
  const stack = new GuardDutyTesterStack(app, 'MyTestStack', {
    env: {
      account: 'test-account',
      region: 'us-west-2',
    },
  });

  const template = Template.fromStack(stack);
  expect(template.toJSON()).toMatchSnapshot();
});
