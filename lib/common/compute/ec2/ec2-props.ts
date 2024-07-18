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

import { Tag } from 'aws-cdk-lib';
import { type InstanceType, type Vpc } from 'aws-cdk-lib/aws-ec2';
/**
 * Defining base props for EC2/ECS parameters
 */
export interface Ec2Props {
  vpc: Vpc;
  instanceName: string;
  instanceType: InstanceType;
  securityGroupIngress?: string;
  region?: string;
  tag: Tag;
  createdBy: Tag;
}
