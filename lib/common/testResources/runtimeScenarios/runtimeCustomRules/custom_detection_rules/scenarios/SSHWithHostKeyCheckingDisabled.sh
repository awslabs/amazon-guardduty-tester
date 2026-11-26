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
# Benign trigger for runtime custom detection rule SSHWithHostKeyCheckingDisabled
# Finding type: Discovery:Runtime/SuspiciousCommand
#
# Strategy: the harness installs openssh-clients; this runs the REAL `ssh` with
# `StrictHostKeyChecking=no` to a loopback target (nobody@127.0.0.1). The genuine
# process.name is 'ssh' and the cmd_line matches the disabled-host-key-check +
# @127.0.0.1 RE2. No sshd listens on loopback, so the connection is refused.
set -eu

echo "[cdr] SSHWithHostKeyCheckingDisabled: running real 'ssh -o StrictHostKeyChecking=no nobody@127.0.0.1' (loopback, refused)"
ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=2 nobody@127.0.0.1 true || true
echo "[cdr] SSHWithHostKeyCheckingDisabled: done"
