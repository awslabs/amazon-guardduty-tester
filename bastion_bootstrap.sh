# Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

#!/bin/bash -e
# Bastion Bootstrapping
# authors: tonynv@amazon.com, sancard@amazon.com, ianhill@amazon.com
# NOTE: This requires GNU getopt. On Mac OS X and FreeBSD you must install GNU getopt and mod the checkos function so that it's supported


# Configuration
PROGRAM='Linux Bastion'

##################################### Functions Definitions
function checkos () {
    platform='unknown'
    unamestr=`uname`
    if [[ "$unamestr" == 'Linux' ]]; then
        platform='linux'
    else
        echo "[WARNING] This script is not supported on MacOS or freebsd"
        exit 1
    fi
    echo "${FUNCNAME[0]} Ended"
}

function usage () {
    echo "$0 <usage>"
    echo " "
    echo "options:"
    echo -e "--help \t Show options for this script"
    echo -e "--banner \t Enable or Disable Bastion Message"
    echo -e "--enable \t SSH Banner"
    echo -e "--tcp-forwarding \t Enable or Disable TCP Forwarding"
    echo -e "--x11-forwarding \t Enable or Disable X11 Forwarding"
}

function chkstatus () {
    if [ $? -eq 0 ]
    then
        echo "Script [PASS]"
    else
        echo "Script [FAILED]" >&2
        exit 1
    fi
}

function osrelease () {
    OS=`cat /etc/os-release | grep '^NAME=' |  tr -d \" | sed 's/\n//g' | sed 's/NAME=//g'`
    if [ "$OS" == "Ubuntu" ]; then
        echo "Ubuntu"
    elif [ "$OS" == "Amazon Linux" ]; then
        echo "AMZN"
    elif [ "$OS" == "CentOS Linux" ]; then
        echo "CentOS"
    else
        echo "Operating System Not Found"
    fi
    echo "${FUNCNAME[0]} Ended" >> /var/log/cfn-init.log
}

function harden_ssh_security () {
    # Allow ec2-user only to access this folder and its content
    #chmod -R 770 /var/log/bastion
    #setfacl -Rdm other:0 /var/log/bastion

    # Make OpenSSH execute a custom script on logins
    echo -e "\nForceCommand /usr/bin/bastion/shell" >> /etc/ssh/sshd_config
    # LOGGING CONFIGURATION
    mkdir -p /var/log/bastion
    mkdir -p /usr/bin/bastion


    touch /tmp/messages
    chmod 770 /tmp/messages
    log_file_location="${bastion_mnt}/${bastion_log}"
    log_shadow_file_location="${bastion_mnt}/.${bastion_log}"


cat <<'EOF' >> /usr/bin/bastion/shell
bastion_mnt="/var/log/bastion"
bastion_log="bastion.log"
# Check that the SSH client did not supply a command. Only SSH to instance should be allowed.
export Allow_SSH="ssh"
if [[ -z $SSH_ORIGINAL_COMMAND ]] || [[ $SSH_ORIGINAL_COMMAND =~ ^$Allow_SSH ]]; then
#Allow ssh to instance and log connection

log_file=`echo "$log_shadow_file_location"`
DATE_TIME_WHOAMI="`whoami`:`date "+%Y-%m-%d %H:%M:%S"`"
LOG_ORIGINAL_COMMAND=`echo "$DATE_TIME_WHOAMI:$SSH_ORIGINAL_COMMAND"`
echo "$LOG_ORIGINAL_COMMAND" >> "${bastion_mnt}/${bastion_log}"
log_dir="/var/log/bastion/"
script -qf /tmp/messages --command=/bin/bash
else
# The "script" program could be circumvented with some commands 
# (e.g. bash, nc). Therefore, I intentionally prevent users
# from supplying commands.

echo "This bastion supports interactive sessions only. Do not supply a command"
exit 1
fi
EOF

    # Make the custom script executable
    chmod a+x /usr/bin/bastion/shell

    release=$(osrelease)
    if [ "$release" == "CentOS" ]; then
        semanage fcontext -a -t ssh_exec_t /usr/bin/bastion/shell
    fi

    echo "${FUNCNAME[0]} Ended"
}

function amazon_os () {
    echo "${FUNCNAME[0]} Started"
    chown root:ec2-user /usr/bin/script
    service sshd restart
    echo -e "\nDefaults env_keep += \"SSH_CLIENT\"" >>/etc/sudoers
cat <<'EOF' >> /etc/bashrc
#Added by linux bastion bootstrap
declare -rx IP=$(echo $SSH_CLIENT | awk '{print $1}')
EOF

    echo " declare -rx BASTION_LOG=${BASTION_MNT}/${BASTION_LOG}" >> /etc/bashrc

cat <<'EOF' >> /etc/bashrc
declare -rx PROMPT_COMMAND='history -a >(logger -t "ON: $(date)   [FROM]:${IP}   [USER]:${USER}   [PWD]:${PWD}" -s 2>>${BASTION_LOG})'
EOF
    chown root:ec2-user  ${BASTION_MNT}
    chown root:ec2-user  ${BASTION_LOGFILE}
    chown root:ec2-user  ${BASTION_LOGFILE_SHADOW}
    chmod 662 ${BASTION_LOGFILE}
    chmod 662 ${BASTION_LOGFILE_SHADOW}
    chattr +a ${BASTION_LOGFILE}
    chattr +a ${BASTION_LOGFILE_SHADOW}
    touch /tmp/messages
    chown root:ec2-user /tmp/messages
    #Install CloudWatch Log service on AMZN
    yum update -y
    yum install -y awslogs
    export CWG=`curl http://169.254.169.254/latest/user-data/ | grep CLOUDWATCHGROUP | sed 's/CLOUDWATCHGROUP=//g'`
    echo "file = $BASTION_LOGFILE_SHADOW" >> /tmp/groupname.txt
    echo "log_group_name = $CWG" >> /tmp/groupname.txt

cat <<'EOF' >> ~/cloudwatchlog.conf

[/var/log/bastion]
datetime_format = %b %d %H:%M:%S
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
EOF

    LINE=$(cat -n /etc/awslogs/awslogs.conf | grep '\[\/var\/log\/messages\]' | awk {'print $1'})
    END_LINE=$(echo $(($LINE-1)))
    head -$END_LINE /etc/awslogs/awslogs.conf > /tmp/awslogs.conf
    cat /tmp/awslogs.conf > /etc/awslogs/awslogs.conf
    cat ~/cloudwatchlog.conf >> /etc/awslogs/awslogs.conf
    cat /tmp/groupname.txt >> /etc/awslogs/awslogs.conf
    export TMPREGION=`cat /etc/awslogs/awscli.conf | grep region`
    export Region=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev`
    sed -i.back "s/$TMPREGION/region = $Region/g" /etc/awslogs/awscli.conf

    #Restart awslogs service
    VERSION=`cat /etc/os-release | grep '^VERSION=' |  tr -d \" | sed 's/\n//g' | sed 's/VERSION=//g'`
    if [ "$VERSION" == "2" ]; then
      systemctl restart awslogsd
    else
      service awslogs restart
      chkconfig awslogs on
    fi

    #Run security updates
cat <<'EOF' >> ~/mycron
0 0 * * * yum -y update --security
EOF
    crontab ~/mycron
    rm ~/mycron
    echo "${FUNCNAME[0]} Ended"
}

function ubuntu_os () {
    chown syslog:adm /var/log/bastion
    chown root:ubuntu /usr/bin/script
cat <<'EOF' >> /etc/bash.bashrc
#Added by linux bastion bootstrap
declare -rx IP=$(who am i --ips|awk '{print $5}')
EOF

    echo " declare -rx BASTION_LOG=${BASTION_MNT}/${BASTION_LOG}" >> /etc/bash.bashrc

cat <<'EOF' >> /etc/bash.bashrc
declare -rx PROMPT_COMMAND='history -a >(logger -t "ON: $(date)   [FROM]:${IP}   [USER]:${USER}   [PWD]:${PWD}" -s 2>>${BASTION_LOG})'
EOF
    chown root:ubuntu ${BASTION_MNT}
    chown root:ubuntu  ${BASTION_LOGFILE}
    chown root:ubuntu  ${BASTION_LOGFILE_SHADOW}
    chmod 662 ${BASTION_LOGFILE}
    chmod 662 ${BASTION_LOGFILE_SHADOW}
    chattr +a ${BASTION_LOGFILE}
    chattr +a ${BASTION_LOGFILE_SHADOW}
    touch /tmp/messages
    chown root:ubuntu /tmp/messages
    #Install CloudWatch logs on Ubuntu
    export CWG=`curl http://169.254.169.254/latest/user-data/ | grep CLOUDWATCHGROUP | sed 's/CLOUDWATCHGROUP=//g'`
    echo "file = $BASTION_LOGFILE_SHADOW" >> /tmp/groupname.txt
    echo "log_group_name = $CWG" >> /tmp/groupname.txt

cat <<'EOF' >> ~/cloudwatchlog.conf
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/bastion]
log_stream_name = {instance_id}
datetime_format = %b %d %H:%M:%S
EOF
    export Region=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev`
    cat /tmp/groupname.txt >> ~/cloudwatchlog.conf

    curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y python
    chmod +x ./awslogs-agent-setup.py
    ./awslogs-agent-setup.py -n -r $Region -c ~/cloudwatchlog.conf

    #Install Unit file for Ubuntu 16.04
    ubuntu=`cat /etc/os-release | grep VERSION_ID | tr -d \VERSION_ID=\"`
    if [ "$ubuntu" == "16.04" ]; then
cat <<'EOF' >> /etc/systemd/system/awslogs.service
[Unit]
Description=The CloudWatch Logs agent
After=rc-local.service

[Service]
Type=simple
Restart=always
KillMode=process
TimeoutSec=infinity
PIDFile=/var/awslogs/state/awslogs.pid
ExecStart=/var/awslogs/bin/awslogs-agent-launcher.sh --start --background --pidfile $PIDFILE --user awslogs --chuid awslogs &

[Install]
WantedBy=multi-user.target
EOF
    fi

    #Restart awslogs service
    service awslogs restart
    export DEBIAN_FRONTEND=noninteractive
    apt-get install sysv-rc-conf -y
    sysv-rc-conf awslogs on

    #Restart SSH
    service ssh stop
    service ssh start

    #Run security updates
    apt-get install unattended-upgrades
cat <<'EOF' >> ~/mycron
0 0 * * * unattended-upgrades -d
EOF
    crontab ~/mycron
    rm ~/mycron
    echo "${FUNCNAME[0]} Ended"
}

function cent_os () {
    echo -e "\nDefaults env_keep += \"SSH_CLIENT\"" >>/etc/sudoers
cat <<'EOF' >> /etc/bashrc
#Added by linux bastion bootstrap
declare -rx IP=$(echo $SSH_CLIENT | awk '{print $1}')
EOF

    echo "declare -rx BASTION_LOG=${BASTION_MNT}/${BASTION_LOG}" >> /etc/bashrc

cat <<'EOF' >> /etc/bashrc
declare -rx PROMPT_COMMAND='history -a >(logger -t "ON: $(date)   [FROM]:${IP}   [USER]:${USER}   [PWD]:${PWD}" -s 2>>${BASTION_LOG})'
EOF
    chown root:centos ${BASTION_MNT}
    chown root:centos /usr/bin/script
    chown root:centos  /var/log/bastion/bastion.log
    chmod 770 /var/log/bastion/bastion.log
    touch /tmp/messages
    chown root:centos /tmp/messages
    restorecon -v /etc/ssh/sshd_config
    /bin/systemctl restart sshd.service



    # Install CloudWatch Log service on Centos Linux
    export CWG=`curl http://169.254.169.254/latest/user-data/ | grep CLOUDWATCHGROUP | sed 's/CLOUDWATCHGROUP=//g'`
    centos=`cat /etc/os-release | grep VERSION_ID | tr -d \VERSION_ID=\"`
    if [ "$centos" == "7" ]; then
        echo "file = $BASTION_LOGFILE_SHADOW" >> /tmp/groupname.txt
        echo "log_group_name = $CWG" >> /tmp/groupname.txt

cat <<'EOF' >> ~/cloudwatchlog.conf
[general]
state_file = /var/awslogs/state/agent-state
use_gzip_http_content_encoding = true
logging_config_file = /var/awslogs/etc/awslogs.conf

[/var/log/bastion]
datetime_format = %Y-%m-%d %H:%M:%S
file = /var/log/messages
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
EOF
    export Region=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev`
    cat /tmp/groupname.txt >> ~/cloudwatchlog.conf

    curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
    chmod +x ./awslogs-agent-setup.py
    ./awslogs-agent-setup.py -n -r $Region -c ~/cloudwatchlog.conf
cat <<'EOF' >> /etc/systemd/system/awslogs.service
[Unit]
Description=The CloudWatch Logs agent
After=rc-local.service

[Service]
Type=simple
Restart=always
KillMode=process
TimeoutSec=infinity
PIDFile=/var/awslogs/state/awslogs.pid
ExecStart=/var/awslogs/bin/awslogs-agent-launcher.sh --start --background --pidfile $PIDFILE --user awslogs --chuid awslogs &

[Install]
WantedBy=multi-user.target
EOF
        service awslogs restart
        chkconfig awslogs on
    else
        chown root:centos /var/log/bastion
        yum update -y
        yum install -y awslogs
        export Region=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev`
        export TMPREGION=`cat /etc/awslogs/awscli.conf | grep region`
        sed -i.back "s/$TMPREGION/region = $Region/g" /etc/awslogs/awscli.conf
        export CWG=`curl http://169.254.169.254/latest/user-data/ | grep CLOUDWATCHGROUP | sed 's/CLOUDWATCHGROUP=//g'`
        echo "file = $BASTION_LOGFILE_SHADOW" >> /tmp/groupname.txt
        echo "log_group_name = $CWG" >> /tmp/groupname.txt

cat <<'EOF' >> ~/cloudwatchlog.conf

[/var/log/bastion]
datetime_format = %b %d %H:%M:%S
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
EOF
        export TMPGROUP=`cat /etc/awslogs/awslogs.conf | grep ^log_group_name`
        export TMPGROUP=`echo $TMPGROUP | sed 's/\//\\\\\//g'`
        sed -i.back "s/$TMPGROUP/log_group_name = $CWG/g" /etc/awslogs/awslogs.conf
        cat ~/cloudwatchlog.conf >> /etc/awslogs/awslogs.conf
        cat /tmp/groupname.txt >> /etc/awslogs/awslogs.conf
        yum install ec2-metadata -y
        export TMPREGION=`cat /etc/awslogs/awscli.conf | grep region`
        export Region=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev`
        sed -i.back "s/$TMPREGION/region = $Region/g" /etc/awslogs/awscli.conf
        sleep 3
        service awslogs stop
        sleep 3
        service awslogs start
        chkconfig awslogs on
    fi

    #Run security updates
cat <<'EOF' >> ~/mycron
0 0 * * * yum -y update --security
EOF
    crontab ~/mycron
    rm ~/mycron
    echo "${FUNCNAME[0]} Ended"
}

function request_eip() {
    release=$(osrelease)
    export Region=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev`

    #Check if EIP already assigned.
    ALLOC=1
    ZERO=0
    INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
    ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
    if [ "$ASSIGNED" -gt "$ZERO" ]; then
        echo "Already assigned an EIP."
    else
        aws ec2 describe-addresses --region $Region --output text > /query.txt
        #Ensure we are only using EIPs from our Stack
        line=`curl http://169.254.169.254/latest/user-data/ | grep EIP_LIST`
        IFS=$':' DIRS=(${line//$','/:})       # Replace tabs with colons.

        for (( i=0 ; i<${#DIRS[@]} ; i++ )); do
            EIP=`echo ${DIRS[i]} | sed 's/\"//g' | sed 's/EIP_LIST=//g'`
            if [ $EIP != "Null" ]; then
                #echo "$i: $EIP"
                grep "$EIP" /query.txt >> /query2.txt;
            fi
        done
        mv /query2.txt /query.txt


        AVAILABLE_EIPs=`cat /query.txt | wc -l`

        if [ "$AVAILABLE_EIPs" -gt "$ZERO" ]; then
            FIELD_COUNT="5"
            INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
            echo "Running associate_eip_now"
            while read name;
            do
                #EIP_ENTRY=$(echo $name | grep eip | wc -l)
                EIP_ENTRY=$(echo $name | grep eni | wc -l)
                echo "EIP: $EIP_ENTRY"
                if [ "$EIP_ENTRY" -eq 1 ]; then
                    echo "Already associated with an instance"
                    echo ""
                else
                    export EIP=`echo "$name" | sed 's/[\s]+/,/g' | awk {'print $4'}`
                    EIPALLOC=`echo $name | awk {'print $2'}`
                    echo "NAME: $name"
                    echo "EIP: $EIP"
                    echo "EIPALLOC: $EIPALLOC"
                    aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $EIPALLOC --region $Region
                fi
            done < /query.txt
        else
            echo "[ERROR] No Elastic IPs available in this region"
            exit 1
        fi

        INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
        ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
        if [ "$ASSIGNED" -eq 1 ]; then
            echo "EIP successfully assigned."
        else
            #Retry
            while [ "$ASSIGNED" -eq "$ZERO" ]
            do
                sleep 3
                request_eip
                INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
                ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
            done
        fi
    fi

    echo "${FUNCNAME[0]} Ended"
}

function call_request_eip() {
    Region=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev`
    ZERO=0
    INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
    ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
    if [ "$ASSIGNED" -gt "$ZERO" ]; then
        echo "Already assigned an EIP."
    else
        WAIT=$(shuf -i 1-30 -n 1)
        sleep "$WAIT"
        request_eip
    fi
    echo "${FUNCNAME[0]} Ended"
}

function prevent_process_snooping() {
    # Prevent bastion host users from viewing processes owned by other users.

    mount -o remount,rw,hidepid=2 /proc
    awk '!/proc/' /etc/fstab > temp && mv temp /etc/fstab
    echo "proc /proc proc defaults,hidepid=2 0 0" >> /etc/fstab
    echo "${FUNCNAME[0]} Ended"
}

##################################### End Function Definitions

# Call checkos to ensure platform is Linux
checkos

## set an initial value
SSH_BANNER="LINUX BASTION"

# Read the options from cli input
TEMP=`getopt -o h:  --long help,banner:,enable:,tcp-forwarding:,x11-forwarding: -n $0 -- "$@"`
eval set -- "$TEMP"


if [ $# == 1 ] ; then echo "No input provided! type ($0 --help) to see usage help" >&2 ; exit 1 ; fi

# extract options and their arguments into variables.
while true; do
    case "$1" in
        -h | --help)
            usage
            exit 1
            ;;
        --banner)
            BANNER_PATH="$2";
            shift 2
            ;;
        --enable)
            ENABLE="$2";
            shift 2
            ;;
        --tcp-forwarding)
            TCP_FORWARDING="$2";
            shift 2
            ;;
        --x11-forwarding)
            X11_FORWARDING="$2";
            shift 2
            ;;
        --)
            break
            ;;
        *)
            break
            ;;
    esac
done

# BANNER CONFIGURATION
BANNER_FILE="/etc/ssh_banner"
if [[ $ENABLE == "true" ]];then
    if [ -z ${BANNER_PATH} ];then
        echo "BANNER_PATH is null skipping ..."
    else
        echo "BANNER_PATH = ${BANNER_PATH}"
        echo "Creating Banner in ${BANNER_FILE}"
        echo "curl  -s ${BANNER_PATH} > ${BANNER_FILE}"
        curl  -s ${BANNER_PATH} > ${BANNER_FILE}
        if [ $BANNER_FILE ] ;then
            echo "[INFO] Installing banner ... "
            echo -e "\n Banner ${BANNER_FILE}" >>/etc/ssh/sshd_config
        else
            echo "[INFO] banner file is not accessible skipping ..."
            exit 1;
        fi
    fi
else
    echo "Banner message is not enabled!"
fi

# LOGGING CONFIGURATION
declare -rx BASTION_MNT="/var/log/bastion"
declare -rx BASTION_LOG="bastion.log"
echo "Setting up bastion session log in ${BASTION_MNT}/${BASTION_LOG}"
mkdir -p ${BASTION_MNT}
declare -rx BASTION_LOGFILE="${BASTION_MNT}/${BASTION_LOG}"
declare -rx BASTION_LOGFILE_SHADOW="${BASTION_MNT}/.${BASTION_LOG}"
touch ${BASTION_LOGFILE}
ln ${BASTION_LOGFILE} ${BASTION_LOGFILE_SHADOW}


#Enable/Disable TCP forwarding
TCP_FORWARDING=`echo "$TCP_FORWARDING" | sed 's/\\n//g'`

#Enable/Disable X11 forwarding
X11_FORWARDING=`echo "$X11_FORWARDING" | sed 's/\\n//g'`

echo "Value of TCP_FORWARDING - $TCP_FORWARDING"

echo "Value of X11_FORWARDING - $X11_FORWARDING"

if [[ $TCP_FORWARDING == "false" ]];then
    awk '!/AllowTcpForwarding/' /etc/ssh/sshd_config > temp && mv temp /etc/ssh/sshd_config
    echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config
    harden_ssh_security
fi

if [[ $X11_FORWARDING == "false" ]];then
    awk '!/X11Forwarding/' /etc/ssh/sshd_config > temp && mv temp /etc/ssh/sshd_config
    echo "X11Forwarding no" >> /etc/ssh/sshd_config
fi

release=$(osrelease)
# Ubuntu Linux
if [ "$release" == "Ubuntu" ]; then
    #Call function for Ubuntu
    ubuntu_os
# AMZN Linux
elif [ "$release" == "AMZN" ]; then
    #Call function for AMZN
    amazon_os
# CentOS Linux
elif [ "$release" == "CentOS" ]; then
    #Call function for CentOS
    cent_os
else
    echo "[ERROR] Unsupported Linux Bastion OS"
    exit 1
fi

prevent_process_snooping

call_request_eip

echo "Bootstrap complete."
