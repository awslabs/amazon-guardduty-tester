#!/bin/sh
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
#
# Benign trigger for runtime custom detection rule SuspiciousProtocolTunneling
# Finding type: CommandAndControl:Runtime/SuspiciousCommand
#
# Strategy: deliberately NOT tor (a real tor client trips
# UnauthorizedAccess:EC2/TorClient and Epoxy auto-mitigation). Instead take the
# ssh branch: the harness installs openssh-clients; this runs the REAL `ssh` with
# a dynamic SOCKS forward (`-D 1080`), which is protocol tunneling. process.name
# is the genuine 'ssh' and the cmd_line matches the `-D` tunnel RE2. The target
# is loopback with no sshd, so the connection is refused and no tunnel forms.
# No `tor` binary is referenced or executed anywhere in this script.
set -eu

echo "[cdr] SuspiciousProtocolTunneling: running real 'ssh -D 1080 nobody@127.0.0.1' (SOCKS tunnel, loopback, refused)"
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=2 -D 1080 nobody@127.0.0.1 true || true
echo "[cdr] SuspiciousProtocolTunneling: done"
