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
# Benign trigger for test SudoerFileReadSudoers (rule SudoerFileRead)
# Finding type: PrivilegeEscalation:Runtime/SuspiciousCommand
#
# Strategy: read /etc/sudoers with cat, a watched path in the rule's IN set. Runs on the static test host;
# the change is benign and nothing is restored.
set -eu
TARGET='/etc/sudoers'
cat "$TARGET" >/dev/null 2>&1
echo "[cdr] SudoerFileReadSudoers: done"
