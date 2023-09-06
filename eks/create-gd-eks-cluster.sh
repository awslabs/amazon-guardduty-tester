set -e

if [[ $# -lt 2 ]]; then
  echo "usage: create-gd-eks-cluster.sh <cluster-name> <region>"
  exit
fi

EKS_CLUSTER_NAME=$1
REGION=$2

function install_dependencies() {

  # Check if AWS CLI is already installed
  if ! [ -x "$(command -v aws)" ]; then
    echo "AWS CLI not found, installing now..."
    # Install the AWS CLI using the bundled installer
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    # Remove the downloaded zip file and the installation directory
    rm -rf awscliv2.zip aws/
  else
    echo "AWS CLI is already installed."
  fi

  # Installing kubectl if not already installed
  if ! [ -x "$(command -v kubectl)" ]; then
    echo "kubectl not found, installing now..."
    # Download the kubectl binary
    KUBECTL_VERSION=v1.27.1
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    # Make the binary executable
    chmod +x ./kubectl
    # Move the binary to a directory in your PATH
    sudo mv ./kubectl /usr/local/bin/kubectl
  else
    echo "kubectl is already installed."
  fi

  # Installing eksctl if not already installed
  if ! [ -x "$(command -v eksctl)" ]; then
    echo "eksctl not found, installing now..."
    # Download the latest eksctl binary
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    # Move the eksctl binary to a directory in your PATH
    sudo mv /tmp/eksctl /usr/local/bin/
  else
    echo "eksctl is already installed."
  fi

  # Installing awk if not already installed
  if ! [ -x "$(command -v awk)" ]; then
    echo "awk not found, installing now..."
    # Install awk using apt-get
    sudo apt-get update
    sudo apt-get install -y awk
  else
    echo "awk is already installed."
  fi
}

function create_eks_cluster_and_deploy_resources() {
  echo "Creating EKS cluster and deploying resources"

  echo "Deploying EKS Cluster"
  eksctl create cluster --name $EKS_CLUSTER_NAME --region $REGION --nodegroup-name guardduty-tester-nodegroup --node-type t2.medium --nodes 1 --nodes-min 1
  
  echo "Connecting to K8s Cluster"
  aws eks --region $REGION update-kubeconfig --name $EKS_CLUSTER_NAME

  sleep 60
  echo "Deploying K8s dashboard"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
}


start_time=$(date +%s)
echo "Starting Guardduty EKS tester (Start time - $(date +'%Y-%m-%d %H:%M:%S %Z'), Estimated time to complete - 30 mins)"
install_dependencies
create_eks_cluster_and_deploy_resources

end_time=$(date +%s)                      # Capture the end time in seconds since the Unix epoch
execution_time=$((end_time - start_time)) # Calculate the execution time in seconds

#Printing it to minutes and seconds.
minutes=$((execution_time / 60))
remaining_seconds=$((execution_time % 60))
echo "Execution time: $minutes minutes, $remaining_seconds seconds"
