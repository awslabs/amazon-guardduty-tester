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
# Benign trigger for runtime custom detection rule SystemdTransientServiceCreated
# Finding type: Persistence:Runtime/SuspiciousCommand
#
# Strategy: the rule keys on process name/path. Run the REAL
# `systemd-run /bin/true`. process.name is the genuine 'systemd-run'. On the
# EC2 instance systemd is running, so this creates a short-lived transient unit
# that runs /bin/true (a no-op) and is reaped automatically once it exits;
# nothing persists.
set -eu

echo "[cdr] SystemdTransientServiceCreated: running real 'systemd-run /bin/true' (transient unit runs /bin/true, benign)"
systemd-run /bin/true
echo "[cdr] SystemdTransientServiceCreated: done"
