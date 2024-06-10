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



# check ecs, ec2, and eks remote scripts
if [ -f ecs.sh ]; then
  aws s3 cp ecs.sh s3://$S3_BUCKET_NAME/remote/ecs.sh
  COMMAND="/bin/bash -c 'aws s3 cp s3://$S3_BUCKET_NAME/remote/ecs.sh . && bash ecs.sh'"

  aws ecs execute-command \
      --cluster $ECS_CLUSTER \
      --container $CONTAINER \
      --region $REGION \
      --interactive \
      --command "$COMMAND" \
      --task $(aws ecs list-tasks \
          --cluster $ECS_CLUSTER \
          --region $REGION \
          --query "taskArns[0]" \
          --output text)
  
  rm ecs.sh
fi

if [ -f ec2.sh ]; then
  aws s3 cp ec2.sh s3://$S3_BUCKET_NAME/remote/ec2.sh
  COMMAND="aws s3 cp s3://$S3_BUCKET_NAME/remote/ec2.sh . && bash ec2.sh"
  PARAMS='commands="'$COMMAND'"'

  aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids $LINUX_INSTANCE --parameters "$PARAMS" > /dev/null
  rm ec2.sh
fi

if [ -f eks.sh ]; then
  echo '$@' >> eks.sh

  POD="gd-eks-runtime-tester"
  REPO_NAME="gd-eks-tester"

  # update config and delete pod if exists
  aws eks --region $REGION update-kubeconfig --name $EKS_CLUSTER_NAME
  kubectl delete pod $POD > /dev/null 2>&1
  
  # build docker image with specified tests and push to ECR
  IMAGE="$ACCNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest"
  sudo docker build --platform=linux/amd64 -t $IMAGE ./
  aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin $ACCNT_ID.dkr.ecr.$REGION.amazonaws.com
  aws ecr create-repository --repository-name $REPO_NAME --region $REGION > /dev/null
  sudo docker push $IMAGE

  # deploy pod
  kubectl apply -f -<<EOF
  apiVersion: v1
  kind: Pod
  metadata: 
      name: $POD
  spec:
    containers: 
      - name: $POD
        imagePullPolicy: Always
        image: $IMAGE
        args: ["sleep","infinity"]
        securityContext:
            privileged: true
EOF
  rm eks.sh
fi


echo
echo "***********************************************************************"
if [ ${#EXPECTED_FINDINGS[@]} -eq 0 ]; then
  echo "No tests matched parameters! No expected GuardDuty findings."
else
  echo "Expected GuardDuty Findings"
  echo
  for i in ${!EXPECTED_FINDINGS[@]}; do
    FINDING="${EXPECTED_FINDINGS[i]}"
    echo $FINDING
  done
fi
echo "***********************************************************************"

