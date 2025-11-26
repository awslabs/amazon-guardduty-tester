#!/bin/bash

# Switch to ubuntu user and execute all commands as ubuntu
sudo -u ubuntu bash << 'EOF'

# Function to check command execution status
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Function to backup configuration files
backup_config() {
    local file=$1
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        check_error "Failed to backup $file"
    fi
}

SCENARIO_HOME=/home/ssm-user/py_tester/runtimeScenarios/hadoop-yarn-job

HADOOP_HOME=/usr/local/hadoop-3.3.6

echo "Deleting $HADOOP_HOME, if already eists..."
if [ -d "$HADOOP_HOME" ]; then
        sudo rm -rf $HADOOP_HOME
fi

# Update and upgrade system
echo "Updating system packages..."
sudo apt-get update -y
check_error "apt update failed"
sudo apt-get upgrade -y
check_error "apt upgrade failed"

# Install OpenJDK
echo "Installing OpenJDK 8..."
sudo apt install -y openjdk-8-jdk
check_error "OpenJDK installation failed"

# Install Hadoop
echo "Downloading and installing Hadoop..."
if [ -f "/home/ubuntu/Downloads/hadoop-3.3.6.tar.gz" ]; then
        echo "/home/ubuntu/Downloads/hadoop-3.3.6.tar.gz exists. Skipping download."
else
        wget https://archive.apache.org/dist/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz -P /home/ubuntu/Downloads
        check_error "Hadoop download failed"
fi

sudo tar zxvf ~/Downloads/hadoop-* -C /usr/local/
check_error "Hadoop extraction failed"

# Get Java home path
JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
echo "JAVA_HOME is $JAVA_HOME"
check_error "Failed to determine JAVA_HOME"

# Update .bashrc
echo "Updating .bashrc..."
cat << EOF_BASHRC >> ~/.bashrc
#JAVA_HOME
export JAVA_HOME=$JAVA_HOME
export PATH=\$PATH:\$JAVA_HOME/bin
#HADOOP_HOME
export HADOOP_HOME=/usr/local/hadoop-3.3.6
export HADOOP_INSTALL=\$HADOOP_HOME
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native
export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
EOF_BASHRC
check_error "Failed to update .bashrc"

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre
export PATH=$PATH:$JAVA_HOME/bin
#HADOOP_HOME
export HADOOP_HOME=/usr/local/hadoop-3.3.6
export HADOOP_INSTALL=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin
#JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre
export PATH=$PATH:$JAVA_HOME/bin
#HADOOP_HOME
export HADOOP_HOME=/usr/local/hadoop-3.3.6
export HADOOP_INSTALL=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin
#JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre
export PATH=$PATH:$JAVA_HOME/bin
#HADOOP_HOME
export HADOOP_HOME=/usr/local/hadoop-3.3.6
export HADOOP_INSTALL=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin

# Update hadoop-env.sh
echo "Updating hadoop-env.sh..."
echo "export JAVA_HOME=$JAVA_HOME" >> $HADOOP_CONF_DIR/hadoop-env.sh
echo "export HADOOP_CONF_DIR=/usr/local/hadoop-3.3.6/etc/hadoop" >> $HADOOP_CONF_DIR/hadoop-env.sh
check_error "Failed to update hadoop-env.sh"

# Get EC2 instance DNS name
#DNS_NAME=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/public-hostname)
DNS_NAME="localhost"
echo "DNS Name is $DNS_NAME"
check_error "Failed to get EC2 instance DNS name"

# Update configuration files
echo "Updating Hadoop configuration files..."

# core-site.xml
backup_config "$HADOOP_CONF_DIR/core-site.xml"
cat << EOF_CORE_SITE > $HADOOP_CONF_DIR/core-site.xml
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://$DNS_NAME:9868</value>
  </property>
</configuration>
EOF_CORE_SITE
check_error "Failed to update core-site.xml"

# yarn-site.xml
backup_config "$HADOOP_CONF_DIR/yarn-site.xml"
cat << EOF_YARN_SITE > $HADOOP_CONF_DIR/yarn-site.xml
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>$DNS_NAME</value>
  </property>
</configuration>
EOF_YARN_SITE
check_error "Failed to update yarn-site.xml"

# mapred-site.xml
cp $HADOOP_CONF_DIR/mapred-site.xml.template $HADOOP_CONF_DIR/mapred-site.xml 2>/dev/null || touch $HADOOP_CONF_DIR/mapred-site.xml
cat << EOF_MAPRED_SITE > $HADOOP_CONF_DIR/mapred-site.xml
<configuration>
  <property>
    <name>mapreduce.jobtracker.address</name>
    <value>$DNS_NAME:54311</value>
  </property>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
</configuration>
EOF_MAPRED_SITE
check_error "Failed to update mapred-site.xml"

# hdfs-site.xml
backup_config "$HADOOP_CONF_DIR/hdfs-site.xml"
cat << EOF_HDFS_SITE > $HADOOP_CONF_DIR/hdfs-site.xml
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:///usr/local/hadoop-3.3.6/data/hdfs/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///usr/local/hadoop-3.3.6/data/hdfs/datanode</value>
  </property>
</configuration>
EOF_HDFS_SITE
check_error "Failed to update hdfs-site.xml"

# Setup SSH keys
echo "Setting up SSH keys..."
rm -f ~/.ssh/id_ed25519
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
check_error "Failed to generate SSH keys"
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
check_error "Failed to update authorized_keys"

# Create HDFS directories
echo "Creating HDFS directories..."
sudo mkdir -p $HADOOP_HOME/data/hdfs/namenode
sudo mkdir -p $HADOOP_HOME/data/hdfs/datanode
check_error "Failed to create HDFS directories"

sudo chown -R ubuntu $HADOOP_HOME
check_error "Failed to change ownership of Hadoop directory"

echo "Shutting down Hadoop services in case they are already running..."

$HADOOP_HOME/sbin/stop-dfs.sh
check_error "Failed to stop DFS"

$HADOOP_HOME/sbin/stop-yarn.sh
check_error "Failed to stop YARN"

$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh stop historyserver
check_error "Failed to stop history server"

# Start Hadoop services
echo "Starting Hadoop services..."
hdfs namenode -format
check_error "Failed to format namenode"

$HADOOP_HOME/sbin/start-dfs.sh
check_error "Failed to start DFS"

$HADOOP_HOME/sbin/start-yarn.sh
check_error "Failed to start YARN"

$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver
check_error "Failed to start history server"

echo "Hadoop setup completed successfully!"

echo "Running the python server to act as a CnC..."
nohup python3 $SCENARIO_HOME/files/python_server.py > /tmp/python_server.log 2>&1 &

echo "Setting up IPTables to redirect CnC traffic to localhost..."
sudo apt install -y iptables
sudo iptables -t nat -A OUTPUT -d 203.0.113.1 -p tcp --dport 33333 -j DNAT --to-destination 127.0.0.1:8081
sudo iptables -t nat -A OUTPUT -d 203.0.113.1 -p tcp --dport 4444 -j DNAT --to-destination 127.0.0.1:4444
EOF
