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
# Benign trigger for runtime custom detection rule InteractiveLocalAccountCreation
# Finding type: Persistence:Runtime/SuspiciousCommand
#
# Strategy: the rule keys only on process.name. Run the REAL `useradd` to
# create a throwaway local user. process.name is the genuine 'useradd'. The
# account exists only on the static test host; nothing is
# restored.
set -eu

echo "[cdr] InteractiveLocalAccountCreation: creating throwaway user with real 'useradd'"
# The host is reused across runs, so remove the account first; otherwise a second run
# (or the other test that creates this account) fails with 'user exists'.
userdel -r benign_tmpuser 2>/dev/null || true
useradd benign_tmpuser
echo "[cdr] InteractiveLocalAccountCreation: done"
