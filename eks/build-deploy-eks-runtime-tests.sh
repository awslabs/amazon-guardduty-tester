# Script that is focused on creating the resources needed to perform tests
# on an EKS cluster for GuardDuty runtime monitoring.

# Steps that will be performed:
# 1) Build the docker image
# 2) Authenticate to ECR
# 3) Create an ECR repository
# 4) Push the docker image to ECR
# 5) Deploy an EKS pod with the docker image

# Inputs:
# 1) Region

# This script is written with an assumption that it is being run
# from the amazon-guardduty-tester/eks directory
#--------------------------------

# Get the region from the script parameter
region=$1

## Get account ID associated with current session
acctid=`aws sts get-caller-identity --query Account|sed 's/"//g'`


#### Build docker image ####
echo '******************************'
echo 'Beginning steps for docker image build'

docker build --platform=linux/amd64 -t $acctid.dkr.ecr.$region.amazonaws.com/gd-eks-tester:latest ../docker


#### Authenticate to ECR ####
echo '******************************'
echo 'Beginning ECR authentication'

aws ecr get-login-password --region $region | \
docker login --username AWS --password-stdin $acctid.dkr.ecr.$region.amazonaws.com


#### Create ECR repository ####
echo '******************************'
echo 'Beginning creation of ECR repository'
aws ecr create-repository \
--repository-name gd-eks-tester \
--region $region


#### Push docker image to ECR ####
echo '******************************'
echo 'Beginning push of docker image to ECR'
docker push $acctid.dkr.ecr.$region.amazonaws.com/gd-eks-tester:latest

#### Deploy EKS pod for testing ####
echo '******************************'
echo 'Beginning deploy of pod to EKS'

cat gd-eks-tester-pod.yaml |sed -e "s/aws_account_id/$acctid/" -e "s/region/$region/"|kubectl apply -f -
