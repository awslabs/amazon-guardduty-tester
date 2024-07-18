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

import { Stack, type StackProps } from 'aws-cdk-lib';
import { type Construct } from 'constructs';

import { TempRole } from '../common/access/iam/tester-temp-tole';
import { KaliLinuxInstance } from '../common/compute/ec2/kali-instance';
import { BasicWindowsInstance } from '../common/compute/ec2/windows-instance';
import { TestDriverEcsCluster } from '../common/compute/ecs/driver-cluster';
import { TesterEksCluster } from '../common/compute/eks/tester-eks';
import { CfnActionLambda } from '../common/compute/lambda/cfn-action-lambda';
import { TesterLambda } from '../common/compute/lambda/finding-lambda';
import { TesterCloudTrail } from '../common/management/cloudtrail/tester-cloudtrail';
import { SettingRestoreStepFunc } from '../common/management/step-function/step-function';
import { CdkGdTesterVPC } from '../common/network/vpc';
import { EmptyBucket } from '../common/storage/s3/empty-bucket';
import { TesterBucket } from '../common/storage/s3/tester-bucket';
import {
  ASG_NAME,
  EC2_INSTANCE_TYPE,
  EC2_TASK_FAMILY,
  ECR_REPO_NAME,
  ECS_CLUSTER_NAME,
  ECS_INSTANCE_NAME,
  EKS_CLUSTER_NAME,
  EKS_INSTANCE_NAME,
  FARGATE_TASK_FAMILY,
  INSTANCE_TAG,
  CREATED_BY_TAG,
  KALI_INSTANCE_NAME,
  TRAIL_NAME,
  WINDOWS_INSTANCE_NAME,
} from './constants';

/**
 * GuardDuty Tester Stack deploys resources to test GuardDuty non-behavioral findings
 */
export class GuardDutyTesterStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const testerBucket = new TesterBucket(this, 'testerBucket');
    const emptyBucket = new EmptyBucket(this, 'emptyBucket');
    const testerLambda = new TesterLambda(this, 'testerLambda', {
      accountId: this.account,
      region: this.region,
    });
    const cloudtrail = new TesterCloudTrail(this, 'testerCloudTrail', {
      bucket: testerBucket.bucket,
      name: TRAIL_NAME,
    });
    const cfnLambda = new CfnActionLambda(this, 'testerCfnLambda', {
      accountId: this.account,
      region: this.region,
      bucketName: testerBucket.bucketName,
      bucketArn: testerBucket.bucketArn,
      ecrRepo: ECR_REPO_NAME,
      asgName: ASG_NAME,
    });
    const tempRole = new TempRole(this, 'TempRole', {
      accountId: this.account,
      bucketArn: testerBucket.bucketArn,
    });
    const stepFunction = new SettingRestoreStepFunc(this, 'StepFunction', {
      accountId: this.account,
      region: this.region,
    });

    // dedicated vpc for testing
    const testerVpc = new CdkGdTesterVPC(this, 'vpc', { region: this.region });

    // public subnet instance
    const kaliInstance = new KaliLinuxInstance(this, 'kaliLinuxInstance', {
      vpc: testerVpc.vpc,
      amiLambda: cfnLambda,
      region: this.region,
      instanceName: KALI_INSTANCE_NAME,
      bucketName: testerBucket.bucketName,
      accountId: this.account,
      eksCluster: EKS_CLUSTER_NAME,
      tempRole: tempRole.arn,
      instanceType: EC2_INSTANCE_TYPE,
      tag: INSTANCE_TAG,
      createdBy: CREATED_BY_TAG,
    });

    // private subnet resources
    const windowsInstance = new BasicWindowsInstance(this, 'windowsInstance', {
      vpc: testerVpc.vpc,
      instanceName: WINDOWS_INSTANCE_NAME,
      instanceType: EC2_INSTANCE_TYPE,
      tag: INSTANCE_TAG,
      createdBy: CREATED_BY_TAG,
    });
    const driverCluster = new TestDriverEcsCluster(this, 'driverCluster', {
      accountId: this.account,
      region: this.region,
      asgName: ASG_NAME,
      eksCluster: EKS_CLUSTER_NAME,
      ecsCluster: ECS_CLUSTER_NAME,
      instanceName: ECS_INSTANCE_NAME,
      instanceType: EC2_INSTANCE_TYPE,
      bucketName: testerBucket.bucketName,
      vpc: testerVpc.vpc,
      maliciousIp: kaliInstance.ec2.instancePublicIp,
      kaliIp: kaliInstance.ec2.instancePrivateIp,
      kaliInstance: kaliInstance.ec2.instanceId,
      kaliRoleName: kaliInstance.instanceRole.role.roleName,
      windowsIp: windowsInstance.ec2.instancePrivateIp,
      windowsInstance: windowsInstance.ec2.instanceId,
      cloudTrailName: TRAIL_NAME,
      cloudTrailArn: cloudtrail.trailArn,
      lambdaName: testerLambda.functionName,
      lambdaArn: testerLambda.functionArn,
      ingressSecurityGroup: kaliInstance.sgId,
      tempRole: tempRole.arn,
      stepFuncArn: stepFunction.machineArn,
      emptyBucketName: emptyBucket.bucketName,
      tag: INSTANCE_TAG,
      ec2TaskFamily: EC2_TASK_FAMILY,
      fargateTaskFamily: FARGATE_TASK_FAMILY,
      createdBy: CREATED_BY_TAG,
    });
    new TesterEksCluster(this, 'eksCluster', {
      vpc: testerVpc.vpc,
      masterRole: driverCluster.instanceRole.role,
      kubectlRole: kaliInstance.instanceRole.role,
      name: EKS_CLUSTER_NAME,
      instanceName: EKS_INSTANCE_NAME,
      tag: INSTANCE_TAG,
      createdBy: CREATED_BY_TAG,
    });

    // Lambda requires Test VPC
    cfnLambda.node.addDependency(testerVpc);
  }
}
