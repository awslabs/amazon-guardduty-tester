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
# Benign trigger for runtime custom detection rule NobodyUserManipulation
# Finding type: Persistence:Runtime/SuspiciousCommand
#
# Strategy: run the REAL `usermod -s /bin/bash nobody` to set the login shell of
# the existing 'nobody' account. process.name is the genuine 'usermod' and the
# cmd_line (`-s /bin/bash ... nobody`) matches the shell-change RE2. Runs on the
# static test host; nothing is restored.
set -eu

echo "[cdr] NobodyUserManipulation: real 'usermod -s /bin/bash nobody'"
usermod -s /bin/bash nobody
echo "[cdr] NobodyUserManipulation: done"
