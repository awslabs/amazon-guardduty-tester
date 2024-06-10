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

import {
  Capability,
  type Cluster,
  ContainerImage,
  Ec2Service,
  Ec2TaskDefinition,
  LinuxParameters,
} from 'aws-cdk-lib/aws-ecs';
import { Construct } from 'constructs';

import { EcsTaskExecutionRole } from '../../access/iam/ecs-task-execution-role';
import { EcsTaskRole } from '../../access/iam/ecs-task-role';

export interface ServiceProps {
  cluster: Cluster;
  bucketName: string;
  region: string;
  accountId: string;
}

/**
 * Container definitions for ECS Task running as a Service to allow command execution
 * for GuardDuty Runtime testing
 */
export class TesterEcsService extends Construct {
  public readonly taskArn: string;
  constructor(scope: Construct, id: string, props: ServiceProps) {
    super(scope, id);

    const taskDefinition = new Ec2TaskDefinition(this, 'TaskDef', {
      executionRole: new EcsTaskExecutionRole(this, 'TaskExecutionRole', {
        region: props.region,
        accountId: props.accountId,
      }).role,
      taskRole: new EcsTaskRole(this, 'TaskRole', {
        bucketName: props.bucketName,
      }).role,
    });

    // include kernel capabilities for certain runtime finding tests
    const kernelCap = new LinuxParameters(this, 'LinuxCapabilities');
    kernelCap.addCapabilities(Capability.SYS_PTRACE, Capability.SYS_ADMIN);

    const commands: string = [
      'sleep 30',
      'apt update -y',
      'apt install python3 gcc netcat-openbsd g++ sudo zip -y',
      'curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install',
      "echo -n 'X5O!P%@AP[4\\PZX54(P^)7CC)7}\\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\\$H+H*' >/tmp/eicar.com && cp /tmp/eicar.com /tmp/eicar.com.txt && zip -j /tmp/eicar_com.zip /tmp/eicar.com && zip -j /tmp/eicarcom2.zip /tmp/eicar_com.zip",
      'sleep 3600',
    ].join(';');

    // create container with kernel capabilities and necessary libraries/filesx
    taskDefinition.addContainer('ContainerInfo', {
      image: ContainerImage.fromRegistry('public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest'),
      memoryLimitMiB: 512,
      cpu: 256,
      linuxParameters: kernelCap,
      privileged: true,
      containerName: 'amazon-linux',
      command: [commands],
      entryPoint: ['sh', '-c'],
    });

    // set task as service and enable command execution
    new Ec2Service(this, id, {
      cluster: props.cluster,
      taskDefinition,
      enableExecuteCommand: true,
    });

    this.taskArn = taskDefinition.taskDefinitionArn;
  }
}
