set -e

if [[ $# -lt 2 ]]; then
  echo "usage: generate_guardduty_findings.sh <cluster-name> <region>"
  exit
fi

EKS_CLUSTER_NAME=$1
REGION=$2

function connect_to_eks() {
  echo "Connecting to K8s Cluster"
  aws eks --region $REGION update-kubeconfig --name $EKS_CLUSTER_NAME
}
echo "Generating guardduty EKS findings"
#Policy:Kubernetes/ExposedDashboard: (severity Medium)
function exposed_dashboard() {
  echo "Generating finding - Policy:Kubernetes/ExposedDashboard: (severity Medium)"
  echo "Patching K8s dashboard. Exposing it as a service"
  kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard -p '{"spec": {"type": "LoadBalancer"}}'
}

#Execution:Kubernetes/ExecInKubeSystemPod (severity Medium)
function exec_in_kube_system_pod() {
  echo "Generating finding - Execution:Kubernetes/ExecInKubeSystemPod (severity Medium)"
  echo "Executing a sample command in a in kube-system namespace"
  # To generate findings using kube-proxy pod
  kubectl exec -n kube-system $(kubectl get pods -n kube-system | awk '{if ($1 ~ /kube-proxy/) print $1}') -- ls || true
  # To generate findings using kube-proxy pod
  #kubectl exec -n kube-system $(kubectl get pods -n kube-system | awk '{if ($1 ~ /aws-node/) print $1}') -- ls || true
}

#Policy:Kubernetes/AdminAccessToDefaultServiceAccount (severity High)
function admin_access_to_default_service_account() {
  echo "Generating finding - Policy:Kubernetes/AdminAccessToDefaultServiceAccount (severity High)"
  echo "Patching Cluster RoleBinding to to give admin access to default Service Account"
  kubectl patch clusterrolebinding cluster-admin -p '{"subjects":[{"kind":"ServiceAccount","name":"default","namespace":"default"}]}'
}

#Policy:Kubernetes/AnonymousAccessGranted
function anonymous_access_granted() {
  echo "Generating finding - Policy:Kubernetes/AdminAccessToDefaultServiceAccount (severity High)"
  echo "Granting an anonymous user access to Kubernetes Cluster"
  kubectl apply -f - <<EOF
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: anonymous-binding
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: anonymous-role
  subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: system:anonymous
EOF
}

connect_to_eks
exposed_dashboard
exec_in_kube_system_pod
admin_access_to_default_service_account
anonymous_access_granted
