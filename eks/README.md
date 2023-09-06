# Amazon GuardDuty tester for Amazon Elastic Kubernetes Service (EKS)

These scripts can be used as proof-of-concept to generate Amazon GuardDuty findings for the [GuardDuty EKS Protection](https://docs.aws.amazon.com/guardduty/latest/ug/kubernetes-protection.html) feature.  There scripts will generate findings based on threats detected via Kubernetes audit logs and runtime activity.  


## Prerequisites

You must enable GuardDuty in the same account and region where you want to run the tests. For more information about enabling GuardDuty, see:  https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_settingup.html#guardduty_enable-gd.

Additionally, the EKS Protection feature of GuardDuty also needs to be enabled.  To enable EKS Audit Log Monitoring see: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty-eks-audit-log-monitoring.html.   To enable EKS Runtime Monitoring see: https://docs.aws.amazon.com/guardduty/latest/ug/eks-protection-configuration.html.


The script that will create an EKS cluster and deploy containers and configuration to the cluster will also attempt to install the [awscli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), [eksctl](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html), and [kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html) tools.  If you would prefer to install these yourself you can do this before running the overall tester script and the tester script will skip trying to install the tools.  

Docker needs to be installed on the operating system that you are performing the test steps on.  For more information about how to install Docker on your particular operating system, go to the [Docker installation guide](https://docs.docker.com/engine/install/#installation)

### Permissions

An IAM Policy listing the minimal permissions for deploying and deleting the resources for this test are located in the [gd-eks-iam-policy.json](gd-eks-iam-policy.json) file.


## Deployment Steps
### 1. Setup execution environment
* Ensure you have the necessary AWS credentials setup on your local machine.
* Clone the repository:
	* git clone https://github.com/awslabs/amazon-guardduty-tester

### 2. Execute Scripts
#### 2a. Create EKS cluster
This step will create the EKS cluster that is used for both the audit logs and runtime activity findings. 

* cd to the amazon-guardduty-tester/eks directory
* Run the **create-gd-eks-cluster.sh** script to install tools and create the cluster.   This script will take 20-30 minutes to deploy and configure the initial EKS cluster.
```
usage: create-gd-eks-cluster.sh <CLUSTER-NAME> <AWS-REGION>

required arguments:
	CLUSTER-NAME: name that the EKS cluster should have
	AWS-REGION: aws region that the cluster should be deployed to

```

```
Example usage:
$ bash create-gd-eks-cluster.sh gd-eks-tester-cluster us-west-2
```
#### 2b. Generate Kubernetes Audit Logs findings
* Run the **generate-eks-audit-logs-findings.sh** script that will run commands against the EKS cluster to generate audit logs based findings

```
usage: generate-eks-audit-logs-findings.sh <CLUSTER-NAME> <AWS-REGION>

required arguments
	CLUSTER-NAME: name that the EKS cluster should have
	AWS-REGION: aws region that the cluster is located in
```

```
Example usage:
$ bash generate-eks-audit-logs-findings.sh gd-eks-tester-cluster us-west-2
```
##### Generated GuardDuty findings
Below is a list of the GuardDuty finding types that are expected to be generated as a result of running the generate-eks-audit-logs-findings.sh script.

* Policy:Kubernetes/ExposedDashboard
* Execution:Kubernetes/ExecInKubeSystemPod
* Policy:Kubernetes/AdminAccessToDefaultServiceAccount
* Policy:Kubernetes/AnonymousAccessGranted

#### 2c. Generate EKS runtime findings
* cd to the amazon-guardduty-tester/eks directory
* Run the **build-deploy-eks-runtime-tests.sh** script to create a docker image and deply it to the EKS cluster.  This script will build the docker image, create a repository in Amazon ECR, store the image in ECR, and deploy the image to a pod in the EKS test cluster.  The docker image contains commands that will result in GuardDuty findings related to threats happening within the container.

```
usage: build-deploy-eks-runtime-tests.sh <AWS-REGION>

required arguments:
	AWS-REGION: aws region that the cluster is located in
```
```
Example usage:
$ bash build-deploy-eks-runtime-tests.sh us-west-2
```

##### Generated Findings
Below is a list of the GuardDuty finding types that are expected to be generated as a result of deploying the eks-tester-pod.

* PrivilegeEscalation:Runtime/DockerSocketAccessed
* PrivilegeEscalation:Runtime/RuncContainerEscape
* PrivilegeEscalation:Runtime/CGroupsReleaseAgentModified
* Execution:Runtime/ReverseShell

## Clean up test resources
When done testing, use the following steps to clean up the resources created by the above deployment steps.

### 1. Remove GuardDuty specific VPC endpoints and security groups 
With the EKS Runtime Protection feature GuardDuty creates a VPC Endpoint and security group that is used to enable the transfer of the cluster runtime information to the GuardDuty service.   Before the test cluster can be deleted the VPC endpoint and Security Group must first be deleted.  

Each of the below commands has a placeholder for a parameter that needs to be replaced with either the name of your cluster or the output from previous commands. 

#### 1a. Get the VPC ID that the test cluster is deployed into
```
eksctl get cluster --name REPLACE_CLUSTER_NAME -o yaml|grep VpcId|awk '{print $2}'
```

#### 1b. Get the VPC endpoint ID associated with the VPC
```
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=REPLACE_VPC_ID --query "VpcEndpoints[*].VpcEndpointId" --output text
```

#### 1c. Delete the VPC endpoint
```
aws ec2 delete-vpc-endpoints --vpc-endpoint-ids REPLACE_VPC_ENDPOINT_ID
```

#### 1d. Confirm VPC endpoint delete.
It takes 5-10 minutes for the VPC endpoint to delete. The next steps cannot proceed until the endpoint has been deleted.
Run this command periodically until no status is returned.
```
aws ec2 describe-vpc-endpoints --filters Name=vpc-endpoint-id,Values=REPLACE_VPC_ENDPOINT_ID --query "VpcEndpoints[*].State" --output text
```

#### 1e. Get GuardDuty security group ID
```
aws ec2 describe-security-groups --filters Name=group-name,Values=GuardDutyManagedSecurityGroup-REPLACE_VPC_ID --query "SecurityGroups[*].GroupId" --output text
```

#### 1f. Delete GuardDuty security group
```
aws ec2 delete-security-group --group-id REPLACE_SECURITY_GROUP_ID
```

### 2. Delete test EKS cluster
```
eksctl delete cluster --name CLUSTER_NAME
```







