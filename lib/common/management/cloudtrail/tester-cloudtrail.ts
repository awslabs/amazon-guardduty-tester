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

import { Trail } from 'aws-cdk-lib/aws-cloudtrail';
import { type Bucket } from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

export interface CloudTrailProps {
  bucket: Bucket;
  name: string;
}

/**
 * Cloud trail that logs to the given bucket for GuardDuty testing purposes
 */
export class TesterCloudTrail extends Construct {
  public readonly trailArn: string;
  constructor(scope: Construct, id: string, props: CloudTrailProps) {
    super(scope, id);
    const trail = new Trail(this, id, {
      bucket: props.bucket,
      trailName: props.name,
    });
    this.trailArn = trail.trailArn;
  }
}
