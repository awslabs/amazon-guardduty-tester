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
# Benign trigger for runtime custom detection rule SudoPrivilegeEnumeration
# Finding type: PrivilegeEscalation:Runtime/SuspiciousCommand
#
# Strategy: run the harmless, read-only `sudo -l`, which only lists the
# privileges available to the current user and changes nothing on the host.
# The process name is "sudo" and the command line "sudo -l" matches the
# rule's RE2. stdin is redirected from /dev/null so a password prompt (if
# any) fails fast instead of hanging. No privileged action is performed.
set -eu

echo "[cdr] SudoPrivilegeEnumeration: running 'sudo -l' (benign enumeration)"
sudo -l </dev/null || true
echo "[cdr] SudoPrivilegeEnumeration: done"
