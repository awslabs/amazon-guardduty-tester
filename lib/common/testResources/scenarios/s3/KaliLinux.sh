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
TEMP_ACCESS_KEY=$(jq -r '.Credentials.AccessKeyId' <<< ${CREDS})
TEMP_SECRET_KEY=$(jq -r '.Credentials.SecretAccessKey' <<< ${CREDS})
TEMP_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' <<< ${CREDS})

python3 -c "import boto3; s3 = boto3.client('s3', region_name = '$REGION', aws_access_key_id = '$TEMP_ACCESS_KEY', aws_secret_access_key = '$TEMP_SECRET_KEY', aws_session_token = '$TEMP_SESSION_TOKEN'); s3.list_objects_v2(Bucket='$S3_BUCKET_NAME');" 