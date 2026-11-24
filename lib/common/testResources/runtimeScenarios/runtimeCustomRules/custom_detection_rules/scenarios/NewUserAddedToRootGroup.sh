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
# Benign trigger for runtime custom detection rule NewUserAddedToRootGroup
# Finding type: PrivilegeEscalation:Runtime/SuspiciousCommand
#
# Strategy: run the REAL `useradd` to make a throwaway user, then the REAL
# `gpasswd -a benign_tmpuser root` to add it to the root group. process.name is the
# genuine 'gpasswd' and the cmd_line `-a benign_tmpuser root` matches the add-to-
# root-group RE2. Runs on the static test host; nothing is
# restored.
set -eu

echo "[cdr] NewUserAddedToRootGroup: creating throwaway user and adding to root group with real gpasswd"
# The host is reused across runs, so remove the account first; otherwise a second run
# (or the other test that creates this account) fails with 'user exists'.
userdel -r benign_tmpuser 2>/dev/null || true
useradd benign_tmpuser
gpasswd -a benign_tmpuser root
echo "[cdr] NewUserAddedToRootGroup: done"
