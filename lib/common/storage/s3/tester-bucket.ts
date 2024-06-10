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

import { RemovalPolicy } from 'aws-cdk-lib';
import { BlockPublicAccess, Bucket, BucketEncryption } from 'aws-cdk-lib/aws-s3';
import { BucketDeployment, Source } from 'aws-cdk-lib/aws-s3-deployment';
import { Construct } from 'constructs';

/**
 * TesterBucket class defines an S3 bucket for GuardDuty tester
 * The bucket is used for S3 protection tests
 * and contains some testing resources as well
 */
export class TesterBucket extends Construct {
  public readonly bucket: Bucket;
  public readonly bucketName: string;
  public readonly bucketArn: string;
  constructor(scope: Construct, id: string) {
    super(scope, id);

    this.bucket = new Bucket(this, id, {
      blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
      encryption: BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      versioned: false,
      removalPolicy: RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    // upload tester python + bash code to bucket
    new BucketDeployment(this, 'DeployTester', {
      sources: [Source.asset('./lib/common/testResources')],
      destinationBucket: this.bucket,
      destinationKeyPrefix: 'py_tester',
    });

    this.bucketName = this.bucket.bucketName;
    this.bucketArn = this.bucket.bucketArn;
  }
}
