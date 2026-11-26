#!/bin/bash

echo "Getting php-rce-app service endpoint"
export ip=`kubectl get pods php-rce-app -o jsonpath='{.status.podIP}'`
echo $ip

echo
echo "Accessing index.php to trigger remote command execution"
curl http://$ip/
