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

EC2_TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
ROLE=$(curl -s -H "X-aws-ec2-metadata-token: $EC2_TOKEN" -v http://169.254.169.254/latest/meta-data/iam/security-credentials/${ROLE_NAME})
AWS_ACCESS_KEY_ID=$(echo $ROLE | jq .AccessKeyId | xargs)
AWS_SECRET_ACCESS_KEY=$(echo $ROLE | jq .SecretAccessKey | xargs)
AWS_SESSION_TOKEN=$(echo $ROLE | jq .Token | xargs)

echo -e 'AUTHENTICATE ""\r\nsignal NEWNYM\r\nQUIT' | nc 127.0.0.1 9051
torify curl $(aws_consoler -a $AWS_ACCESS_KEY_ID -s $AWS_SECRET_ACCESS_KEY -t $AWS_SESSION_TOKEN -R $REGION)