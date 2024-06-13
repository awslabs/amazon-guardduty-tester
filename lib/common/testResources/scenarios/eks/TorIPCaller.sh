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

aws eks --region $REGION update-kubeconfig --name $EKS_CLUSTER_NAME
sudo kubectl apply -f - <<EOF 
apiVersion: v1 
kind: Secret 
metadata: 
  name: default-token 
  annotations: 
    kubernetes.io/service-account.name: default 
type: kubernetes.io/service-account-token 
EOF

APISERVER=$(sudo kubectl config view --minify | grep server | cut -f 2- -d ":" | tr -d " ")
TOKEN=$(sudo kubectl describe secret default-token | grep -E '^token' | cut -f2 -d':' | tr -d " ")

echo -e 'AUTHENTICATE ""\r\nsignal NEWNYM\r\nQUIT' | nc 127.0.0.1 9051
torify curl $APISERVER/api --header "Authorization: Bearer $TOKEN" --insecure