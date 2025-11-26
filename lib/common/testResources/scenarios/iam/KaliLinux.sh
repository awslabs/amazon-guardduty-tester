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
export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq .Credentials.AccessKeyId | xargs)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq .Credentials.SecretAccessKey | xargs)
export AWS_SESSION_TOKEN=$(echo $CREDS | jq .Credentials.SessionToken | xargs)

export KALI_USER_AGENT_HEADER='aws-cli/2.23.6 md/awscrt#1.0.0.dev0 ua/2.0 os/linux#6.12.13-cloud-amd64 md/arch#x86_64 lang/python#3.13.2 md/pyimpl#CPython cfg/retry-mode#standard md/installer#source md/distrib#kali.2025 md/prompt#off md/command#iam.get-user'

source /home/ssm-user/gd_tester_pyenv/bin/activate

awscurl --access_key=$AWS_ACCESS_KEY_ID \
        --secret_key=$AWS_SECRET_ACCESS_KEY \
        --session_token=$AWS_SESSION_TOKEN \
        --service iam \
        --header "User-Agent: $KALI_USER_AGENT_HEADER" \
        "https://iam.amazonaws.com/?Action=GetUser&Version=2010-05-08" >> /dev/null 2>&1

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset IAM_REGION
unset KALI_USER_AGENT_HEADER
