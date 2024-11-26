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

CREDS=$(aws sts assume-role --role-arn ${TEMP_ROLE_ARN} --role-session-name s3_pentest)
export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq .AccessKeyId | xargs)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq .SecretAccessKey | xargs)
export AWS_SESSION_TOKEN=$(echo $CREDS | jq .Token | xargs)

aws s3api list-objects-v2 --region $REGION --bucket $S3_BUCKET_NAME