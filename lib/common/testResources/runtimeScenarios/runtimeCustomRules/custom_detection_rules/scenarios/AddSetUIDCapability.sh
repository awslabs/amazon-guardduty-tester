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
# Benign trigger for runtime custom detection rule AddSetUIDCapability
# Finding type: PrivilegeEscalation:Runtime/SuspiciousCommand
#
# Strategy: the harness installs libcap; this runs the REAL `getcap -r /usr` (a
# read-only recursive capability scan). process.name is the genuine 'getcap'
# and the cmd_line `getcap -r` matches the getcap branch RE2. getcap only reads
# file capabilities; it sets nothing.
set -eu

echo "[cdr] AddSetUIDCapability: running real 'getcap -r /usr' (read-only capability scan)"
getcap -r /usr || true
echo "[cdr] AddSetUIDCapability: done"
