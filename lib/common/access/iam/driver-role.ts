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

import { Effect, ManagedPolicy, PolicyDocument, PolicyStatement, Role, ServicePrincipal } from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export interface DriverRoleProps {
  bucketName: string;
  emptyBucketName: string;
  accountId: string;
  trailArn: string;
  lambdaArn: string;
  region: string;
  kaliId: string;
  cluster: string;
  eks: string;
  stepFuncArn: string;
  ec2TaskFamily: string;
  fargateTaskFamily: string;
  clusterName: string;
  taskRole: string;
  execRole: string;
}

/**
 * IAM role and policies assumed by the ECS host instance
 * Permissions required to perform test set/clean up + testing tasks
 */
export class DriverRole extends Construct {
  public readonly role: Role;
  constructor(scope: Construct, id: string, props: DriverRoleProps) {
    super(scope, id);

    this.role = new Role(this, id, {
      assumedBy: new ServicePrincipal('ec2.amazonaws.com'),
      inlinePolicies: {
        DriverPolicy: new PolicyDocument({
          statements: [
            new PolicyStatement({
              sid: 'S3AccessPolicy',
              effect: Effect.ALLOW,
              actions: ['s3:GetAccountPublicAccessBlock', 's3:ListAllMyBuckets', 's3:PutAccountPublicAccessBlock'],
              resources: ['*'], // Selected actions only support the all resources wildcard('*')
            }),
            new PolicyStatement({
              sid: 'TesterS3BucketSpecific',
              effect: Effect.ALLOW,
              actions: ['s3:GetObject', 's3:ListBucket', 's3:PutObject', 's3:PutBucketLogging'],
              resources: [`arn:aws:s3:::${props.bucketName}`, `arn:aws:s3:::${props.bucketName}/*`],
            }),
            new PolicyStatement({
              sid: 'EmptyS3BucketSpecific',
              effect: Effect.ALLOW,
              actions: ['s3:PutBucketPolicy', 's3:PutBucketPublicAccessBlock'],
              resources: [`arn:aws:s3:::${props.emptyBucketName}`],
            }),
            new PolicyStatement({
              sid: 'IAMPasswordPolicyAccess',
              effect: Effect.ALLOW,
              actions: [
                  'iam:DeleteAccountPasswordPolicy', // Required to restore password policy to default if not previously set
                  'iam:GetAccountPasswordPolicy',
                  'iam:UpdateAccountPasswordPolicy'
              ],
              resources: ['*'], // Selected actions only support the all resources wildcard('*').
            }),
            new PolicyStatement({
              sid: 'CloudTrail',
              effect: Effect.ALLOW,
              actions: ['cloudtrail:StopLogging'],
              resources: [props.trailArn],
            }),
            new PolicyStatement({
              sid: 'EC2EIPList',
              effect: Effect.ALLOW,
              actions: ['ec2:DescribeAddresses'],
              resources: ['*'], // Selected actions only support the all resources wildcard('*')
            }),
            new PolicyStatement({
              sid: 'GuardDuty',
              effect: Effect.ALLOW,
              actions: [
                'guardduty:CreateThreatIntelSet',
                'guardduty:GetDetector',
                'guardduty:ListDetectors',
                'guardduty:UpdateDetector',
              ],
              resources: [`arn:aws:guardduty:${props.region}:${props.accountId}:detector/*`],
            }),
            new PolicyStatement({
              sid: 'GuardDutyServicePolicy',
              effect: Effect.ALLOW,
              actions: ['iam:GetRole', 'iam:PutRolePolicy'],
              resources: [
                `arn:aws:iam::${props.accountId}:role/aws-service-role/guardduty.amazonaws.com/AWSServiceRoleForAmazonGuardDuty`,
                `arn:aws:iam::${props.accountId}:role/aws-service-role/guardduty.amazonaws.com/AWSServiceRoleForAmazonGuardDutyMalwareProtection`,
              ],
            }),
            new PolicyStatement({
              sid: 'LambdaExecute',
              effect: Effect.ALLOW,
              actions: ['lambda:InvokeFunction'],
              resources: [props.lambdaArn],
            }),
            new PolicyStatement({
              sid: 'SsmDocs',
              effect: Effect.ALLOW,
              actions: ['ssm:SendCommand'],
              resources: [
                `arn:aws:ec2:${props.region}:${props.accountId}:instance/${props.kaliId}`,
                `arn:aws:ssm:${props.region}::document/AWS-RunShellScript`,
              ],
            }),
            new PolicyStatement({
              sid: 'InstallGuardDutyAgent',
              effect: Effect.ALLOW,
              actions: ['ssm:SendCommand'],
              resources: [
                `arn:aws:ec2:${props.region}:${props.accountId}:instance/*`,
                `arn:aws:ssm:${props.region}::document/AmazonGuardDuty-ConfigureRuntimeMonitoringSsmPlugin`,
              ],
            }),
            new PolicyStatement({
              sid: 'RunEcsTask',
              effect: Effect.ALLOW,
              actions: ['ecs:RunTask'],
              resources: [
                `arn:aws:ecs:${props.region}:${props.accountId}:task-definition/${props.fargateTaskFamily}:*`,
                `arn:aws:ecs:${props.region}:${props.accountId}:task-definition/${props.ec2TaskFamily}:*`,
              ],
            }),
            new PolicyStatement({
              sid: 'PassEcsTaskRole',
              effect: Effect.ALLOW,
              actions: ['iam:PassRole'],
              resources: [props.taskRole, props.execRole],
            }),
            new PolicyStatement({
              sid: 'RegisterEcsTask',
              effect: Effect.ALLOW,
              actions: ['ecs:RegisterTaskDefinition'],
              resources: ['*'], // Selected actions only support the all resources wildcard('*').
            }),
            new PolicyStatement({
              sid: 'EksImageUploadToRepo',
              effect: Effect.ALLOW,
              actions: [
                'ecr:CreateRepository',
                'ecr:CompleteLayerUpload',
                'ecr:GetAuthorizationToken',
                'ecr:InitiateLayerUpload',
                'ecr:PutImage',
                'ecr:UploadLayerPart',
              ],
              resources: [`arn:aws:ecr:${props.region}:${props.accountId}:repository/*`],
            }),
            new PolicyStatement({
              sid: 'EksKubeCtlPermissions',
              effect: Effect.ALLOW,
              actions: ['eks:DescribeCluster', 'eks:DescribeNodegroup'],
              resources: [`arn:aws:eks:${props.region}:${props.accountId}:cluster/${props.eks}`],
            }),
            new PolicyStatement({
              sid: 'StartStepFunction',
              effect: Effect.ALLOW,
              actions: ['states:StartExecution'],
              resources: [props.stepFuncArn],
            }),
            new PolicyStatement({
              sid: 'GuardDutyEksAddOnPermissions',
              effect: Effect.ALLOW,
              actions: ['eks:CreateAddon', 'eks:DescribeAddon'],
              resources: [
                `arn:aws:eks:${props.region}:${props.accountId}:addon/${props.eks}/aws-guardduty-agent/*`,
                `arn:aws:eks:${props.region}:${props.accountId}:cluster/${props.eks}`,
              ],
              conditions: {
                'ForAllValues:StringEquals': {
                  'aws:TagKeys': 'GuardDutyManaged',
                },
              },
            }),
          ],
        }),
      },
      managedPolicies: [
        ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
        ManagedPolicy.fromManagedPolicyArn(
          this,
          'ManagedPolicy',
          'arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role',
        ),
      ],
    });
  }
}
