#!/bin/bash

sudo yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm

echo "Getting region from IMDSv2..."
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

aws ssm start-session   --region $REGION   --document-name AWS-StartInteractiveCommand   --parameters command="/home/ssm-user/py_tester/runtimeScenarios/hadoop-yarn-job/files/attack.sh" --target $(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=Ubuntu-GuardDutyTester" --query "Reservations[].Instances[?State.Name=='running'].InstanceId" --output text)
