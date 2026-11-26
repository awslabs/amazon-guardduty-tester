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
# Benign trigger for runtime custom detection rule AuditdKeylogger
# Finding type: Persistence:Runtime/SuspiciousCommand
#
# Strategy: best-effort ensure the audit subsystem is present and active
# (the harness installs the audit package; here we enable/start auditd
# so the loaded binary is observed), then run the REAL
# `auditctl -a always,exit -F arch=b64 -S execve`. process.name is the genuine
# 'auditctl' and the cmd_line matches the always,exit + execve RE2
# (case-insensitive, so `-S execve` matches `-s execve`). The call may EPERM
# without CAP_AUDIT_CONTROL, but the real binary ran and its cmd_line matches
# regardless. Runs on the static test host; the audit rule
# is not removed.
set -eu

echo "[cdr] AuditdKeylogger: ensuring audit subsystem active, then running real 'auditctl -a always,exit -S execve' (may EPERM; binary runs)"
systemctl enable --now auditd || true
auditctl -a always,exit -F arch=b64 -S execve || true
echo "[cdr] AuditdKeylogger: done"
