#!/bin/bash
echo "Getting region from IMDSv2..."
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

echo "Region is $REGION"

echo "Configuring kubectl to connect to EksGuardDutyTester cluster... "
aws eks update-kubeconfig --region $REGION --name EksGuardDutyTester

# Java Web Application Deployment Script for GuardDuty Tester EKS Cluster
if [[ -z "$REGION" ]]; then
  echo "Error: REGION is not set or is empty. Please set by running \"export REGION=<your aws region>\". For example, export REGION=us-west-1." >&2
  exit 1
fi

# Check if the 'docker' command exists
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not found in the system's PATH." >&2
    exit 1
fi

# Check if the Docker daemon is running
if ! sudo docker info &> /dev/null; then
    echo "Error: Docker is installed but the Docker daemon is not running." >&2
    echo "Please ensure the Docker daemon is started." >&2
    exit 1
fi

echo "Checking for previous Tomcat pods"
if [ $(kubectl get pods | grep tomcat-pod | wc -l) -ne 0 ]; then
    echo "Previous deployment found, removing"
    kubectl delete -f ./files/tomcat.yaml
    if [ $? -eq 0 ]; then
        echo "Delete successful"
    else
        echo "Delete failed"
        exit 1
    fi
else
    echo "No previous Tomcat pod found"
fi

echo
echo "Preparing Tomcat container image for Java web app..."

# Generate random tag
RANDOM_TAG=$(openssl rand -hex 6)
REPO_NAME="java-app-$RANDOM_TAG"

# Get AWS account ID and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Check if ECR repository exists and delete it if it does
echo "Checking if ECR repository '$REPO_NAME' exists..."
if aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION >/dev/null 2>&1; then
    echo "Repository '$REPO_NAME' exists. Deleting it..."
    aws ecr delete-repository --repository-name $REPO_NAME --region $REGION --force
    if [ $? -eq 0 ]; then
        echo "Repository '$REPO_NAME' deleted successfully"
    else
        echo "Failed to delete repository '$REPO_NAME'"
        exit 1
    fi
else
    echo "Repository '$REPO_NAME' does not exist"
fi

# Create ECR repository
echo "Creating ECR repository '$REPO_NAME'..."
aws ecr create-repository --repository-name $REPO_NAME --region $REGION

# Get ECR login token
aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Pull Tomcat image
sudo docker pull public.ecr.aws/docker/library/tomcat:9.0-jdk11

export IMAGE_NAME=`echo  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$RANDOM_TAG`
# Tag image for ECR
sudo docker tag public.ecr.aws/docker/library/tomcat:9.0-jdk11 $IMAGE_NAME

# Push to ECR
sudo docker push $IMAGE_NAME

echo "Image pushed to: $IMAGE_NAME"

echo
echo "Deploying Tomcat and Java Web Application to EKS cluster..."

envsubst < ./files/tomcat.yaml > ./files/temp_tomcat.yaml

echo "Creating Deployment..."
kubectl apply -f ./files/temp_tomcat.yaml

echo "Deployment completed!"
echo "Checking deployment status..."
kubectl get pods tomcat-pod

echo "Waiting for 30 seconds for deployment to complete..."
sleep 30

echo "Deleting the repository $REPO_NAME for cleanup...."
aws ecr delete-repository --repository-name $REPO_NAME --region $REGION --force

echo
echo
echo "Getting pod name"
export pod_name=`kubectl get pods tomcat-pod -o jsonpath='{.metadata.name}'`
echo $pod_name | tee .tomcat_pod_name

echo
echo
echo "Setup Tomcat and a Java web application...."
# Install netcat
kubectl exec -it $pod_name -- apt update -y
kubectl exec -it $pod_name -- apt install netcat-openbsd -y

echo "Installing iptables and setting NAT rules to redirect connects to the CnC IP to localhost..."
kubectl exec -it $pod_name -- apt install -y iptables
kubectl exec -it $pod_name -- iptables -t nat -A OUTPUT -d 203.0.113.1 -p tcp --dport 33333 -j DNAT --to-destination 127.0.0.1:8081
kubectl exec -it $pod_name -- iptables -t nat -A OUTPUT -d 203.0.113.1 -p tcp --dport 4444 -j DNAT --to-destination 127.0.0.1:4444

echo "Deploying index.jsp..."
kubectl exec -it $pod_name -- mkdir /usr/local/tomcat/webapps/ROOT
kubectl cp ./files/index.jsp $pod_name:/usr/local/tomcat/webapps/ROOT/index.jsp

echo "Deploying and starting Python server to act as CnC..."
kubectl cp ./files/python_server.py $pod_name:/python_server.py
kubectl exec -it $pod_name -- apt install -y python3
nohup kubectl exec -it $pod_name -- bash -c 'python3 /python_server.py' > /dev/null 2>&1 &
