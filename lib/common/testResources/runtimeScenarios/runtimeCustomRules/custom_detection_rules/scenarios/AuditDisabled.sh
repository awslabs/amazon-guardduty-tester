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
# Benign trigger for runtime custom detection rule AuditDisabled
# Finding type: DefenseEvasion:Runtime/SuspiciousCommand
#
# Strategy: systemd is present, so this runs the REAL
# `systemctl stop auditd`. process.name is the genuine 'systemctl' and the
# cmd_line `stop auditd` matches the systemctl-stop-auditd RE2. auditd is not
# running on the instance, so nothing is actually stopped.
set -eu

echo "[cdr] AuditDisabled: running real 'systemctl stop auditd' (auditd absent -> harmless)"
systemctl stop auditd || true
echo "[cdr] AuditDisabled: done"
