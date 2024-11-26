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

export interface EcsTaskRoleProps {
  bucketName: string;
}

/**
 * ECS Task role for GuardDuty ECS Runtime findings testing
 */
export class EcsTaskRole extends Construct {
  public readonly role: Role;
  constructor(scope: Construct, id: string, props: EcsTaskRoleProps) {
    super(scope, id);

    this.role = new Role(this, id, {
      assumedBy: new ServicePrincipal('ecs-tasks.amazonaws.com'),
    });
  }
}
