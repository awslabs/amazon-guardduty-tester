#!/usr/bin/env node
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

import "source-map-support/register";
import { App } from "aws-cdk-lib";
import { GuardDutyTesterStack } from "../lib/stacks/tester-stack";

const account: string = "";
const region: string = "";

const validRegions: string[] = [
  "eu-west-1",
  "us-east-1",
  "us-west-2",
  "eu-west-3",
  "us-east-2",
  "eu-central-1",
  "ap-northeast-2",
  "eu-north-1",
  "ap-east-1",
  "me-south-1",
  "eu-west-2",
  "ap-northeast-1",
  "ap-southeast-1",
  "ap-south-1",
  "ap-southeast-3",
  "sa-east-1",
  "ap-northeast-3",
  "eu-south-1",
  "af-south-1",
  "ap-southeast-2",
  "me-central-1",
  "us-west-1",
  "ca-central-1",
  "ap-south-2",
  "eu-south-2",
  "eu-central-2",
  "ap-southeast-4",
  "il-central-1",
];

if (
  (!region &&
    process.env.CDK_DEFAULT_REGION &&
    !validRegions.includes(process.env.CDK_DEFAULT_REGION)) ||
  (region && !validRegions.includes(region))
) {
  const errorMessage: string = `INVALID REGION
      Please set region to valid deployment region!
      Either set CDK_DEFAULT_REGION through AWS CLI or environment variables
      see https://docs.aws.amazon.com/cli/latest/reference/configure/set.html
      Alternatively, set the region variable in /bin/cdk-gd-tester.ts file
      `;

  throw new Error(errorMessage);
}

const app = new App();

new GuardDutyTesterStack(app, "GuardDutyTesterStack", {
  description:
    "VPC infrastructure and other cloud resources for an isolated GuardDuty testing environment.",
  env: {
    account: account || process.env.CDK_DEFAULT_ACCOUNT,
    region: region || process.env.CDK_DEFAULT_REGION,
  },
});
