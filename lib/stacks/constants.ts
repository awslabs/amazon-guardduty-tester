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

import { InstanceClass, InstanceSize, InstanceType } from 'aws-cdk-lib/aws-ec2';

// Constant hard coded names of testing environment resources
export const EKS_CLUSTER_NAME: string = 'EksGuardDutyTester';
export const ECS_CLUSTER_NAME: string = 'EcsGuardDutyTester';
export const ECR_REPO_NAME: string = 'gd-eks-tester';
export const ASG_NAME: string = 'GuardDutyTesterASG';
export const TRAIL_NAME: string = 'GuardDutyTesterCloudTrail';
export const KALI_INSTANCE_NAME: string = 'Kali-GuardDutyTester';
export const WINDOWS_INSTANCE_NAME: string = 'Windows-GuardDutyTester';
export const ECS_INSTANCE_NAME: string = 'Driver-GuardDutyTester';
export const EKS_INSTANCE_NAME: string = 'Kube-GuardDutyTester';
export const EC2_INSTANCE_TYPE: InstanceType = InstanceType.of(InstanceClass.T3, InstanceSize.MICRO);
