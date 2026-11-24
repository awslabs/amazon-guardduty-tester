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
# Benign trigger for runtime custom detection rule KillCommandUsage
# Finding type: DefenseEvasion:Runtime/SuspiciousCommand
#
# Strategy: the harness installs procps-ng; this runs the REAL `pkill -x auditd`
# (auditd is in the rule's watched monitoring-process list). process.name is
# the genuine 'pkill' and the cmd_line matches the pkill-monitoring-process
# RE2. auditd is not running, so no process is signalled.
set -eu

echo "[cdr] KillCommandUsage: running real 'pkill -x auditd' (auditd not running -> no-op)"
pkill -x auditd || true
echo "[cdr] KillCommandUsage: done"
