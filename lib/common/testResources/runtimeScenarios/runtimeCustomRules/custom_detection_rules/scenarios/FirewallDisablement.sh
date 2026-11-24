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
# Benign trigger for runtime custom detection rule FirewallDisablement
# Finding type: DefenseEvasion:Runtime/SuspiciousCommand
#
# Strategy: ufw is typically absent, so take the systemctl branch. systemd is
# present, so this runs the REAL `systemctl stop firewalld`. process.name
# is the genuine 'systemctl' and the cmd_line `stop firewalld` matches the
# systemctl-stop-firewall RE2. firewalld is not running, so nothing is disabled.
set -eu

echo "[cdr] FirewallDisablement: running real 'systemctl stop firewalld' (firewalld absent -> harmless)"
systemctl stop firewalld || true
echo "[cdr] FirewallDisablement: done"
