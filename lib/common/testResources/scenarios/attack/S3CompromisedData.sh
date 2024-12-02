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

CREDS=$(aws sts assume-role --role-arn ${TEMP_ROLE_ARN} --role-session-name s3_compromised_data)
export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq .Credentials.AccessKeyId | xargs)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq .Credentials.SecretAccessKey | xargs)
export AWS_SESSION_TOKEN=$(echo $CREDS | jq .Credentials.SessionToken | xargs)

# List users
aws iam list-users --region $REGION &> /dev/null || true

# List roles
aws iam list-roles --region $REGION &> /dev/null || true

# List buckets
aws s3api list-buckets --region $REGION &> /dev/null || true

# List objects
aws s3api list-objects --bucket "$ATTACK_BUCKET_NAME" --region $REGION &> /dev/null || true

# Put a ransom note object
RANSOM_NOTE="Test ransom note"
echo "$RANSOM_NOTE" > ransom_note.txt
aws s3 cp ransom_note.txt "s3://$ATTACK_BUCKET_NAME/RANSOM_NOTE.txt" --region $REGION &> /dev/null || true
rm -f ransom_note.txt

# Delete the ransom note object
aws s3api delete-object --bucket "$ATTACK_BUCKET_NAME" --key "RANSOM_NOTE.txt" --region $REGION &> /dev/null || true

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN