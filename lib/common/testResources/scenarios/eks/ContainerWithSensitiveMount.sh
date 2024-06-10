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

IMAGE='GuardDutyTestContainerSensitiveMount'

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mount
spec:
  selector:
    matchLabels:
      app: mount
  replicas: 1
  template:
    metadata:
      labels:
        app: mount
    spec:
      containers:
      - name: mount
        image: "$IMAGE"
        ports:
        - containerPort: 22
        securityContext:
          privileged: false
        volumeMounts:
        - mountPath: /test-pd
          name: test-volume
      volumes:
      - name: test-volume
        hostPath:
          path: /etc
          type: Directory
EOF