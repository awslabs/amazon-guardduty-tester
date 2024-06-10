#Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#  
#  Licensed under the Apache License, Version 2.0 (the "License").
#  You may not use this file except in compliance with the License.
#  A copy of the License is located at
#  
#      http://www.apache.org/licenses/LICENSE-2.0
#  
#  or in the "license" file accompanying this file. This file is distributed 
#  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either 
#  express or implied. See the License for the specific language governing 
#  permissions and limitations under the License.

POLICY='{"Version":"2012-10-17","Statement":[{"Sid":"PublicReadGetObject","Effect":"Allow","Principal":{"AWS":"*"},"Action":["s3:GetObject"],"Resource":["arn:aws:s3:::'$EMPTY_BUCKET_NAME'/*"],"Condition":{"StringLike":{"aws:PrincipalArn":"arn:aws:iam::*"}}}]}'
aws s3api put-bucket-policy --bucket $EMPTY_BUCKET_NAME --policy $POLICY