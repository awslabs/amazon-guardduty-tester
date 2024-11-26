#!/bin/bash

export homeDir=/home/ssm-user

pip3 install cmake
cd ${homeDir}
cat << EOF >> users
ec2-user
root
admin
administrator
ftp
www
nobody
EOF
wget -q -O ${homeDir}/libssh.tar.xz https://www.libssh.org/files/0.9/libssh-0.9.4.tar.xz
tar -xvf ${homeDir}/libssh.tar.xz
cd ${homeDir}/libssh-0.9.4
mkdir build
cd build
cmake3 -DUNIT_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release ..
make && make install
cd ${homeDir}
git clone https://github.com/vanhauser-thc/thc-hydra
cd thc-hydra
./configure
make && make install
cd ${homeDir}
git clone https://github.com/galkan/crowbar ${homeDir}/crowbar
cd ${homeDir}
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.27.1/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
curl --silent --location https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin/
chown -R ssm-user: ${homeDir}
chmod +x ${homeDir}/crowbar/crowbar.py
${install} https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
wget https://secure.eicar.org/eicar.com
wget https://secure.eicar.org/eicar.com.txt
wget https://secure.eicar.org/eicar_com.zip
wget https://secure.eicar.org/eicarcom2.zip