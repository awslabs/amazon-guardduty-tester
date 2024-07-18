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

function configure_aws(){
    aws configure set aws_access_key_id $1
    aws configure set aws_secret_access_key $2
    aws configure set aws_session_token $3
}

EC2_TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
ROLE=$(curl -s -H "X-aws-ec2-metadata-token: $EC2_TOKEN" -v http://169.254.169.254/latest/meta-data/iam/security-credentials/${ROLE_NAME})
PREV_AWS_ACCESS_KEY_ID=$(echo $ROLE | jq .AccessKeyId | xargs)
PREV_AWS_SECRET_ACCESS_KEY=$(echo $ROLE | jq .SecretAccessKey | xargs)
PREV_AWS_SESSION_TOKEN=$(echo $ROLE | jq .Token | xargs)

CREDS=$(aws sts assume-role --role-arn ${TEMP_ROLE_ARN} --role-session-name s3_pentest)
TEMP_ACCESS_KEY=$(echo $CREDS | jq -r '.Credentials.AccessKeyId')
TEMP_SECRET_KEY=$(echo $CREDS | jq -r '.Credentials.SecretAccessKey')
TEMP_SESSION_TOKEN=$(echo $CREDS | jq -r '.Credentials.SessionToken')

configure_aws $TEMP_ACCESS_KEY $TEMP_SECRET_KEY $TEMP_SESSION_TOKEN

aws s3api list-objects-v2 --region $REGION --bucket $S3_BUCKET_NAME

configure_aws $PREV_AWS_ACCESS_KEY_ID $PREV_AWS_SECRET_ACCESS_KEY $PREV_AWS_SESSION_TOKEN