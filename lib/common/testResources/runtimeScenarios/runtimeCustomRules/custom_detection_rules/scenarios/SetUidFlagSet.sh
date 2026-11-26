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
# Benign trigger for runtime custom detection rule SetUidFlagSet
# Finding type: PrivilegeEscalation:Runtime/SuspiciousCommand
#
# Strategy: set the setuid bit (S_ISUID) on a throwaway file we own under /tmp
# with the real `chmod u+s`. A non-root user may set the setuid bit on a file
# it owns; the chmod event records the S_ISUID mode and matches the rule. The
# file is empty and non-executable in substance, grants no privilege, and
# exists only on the static test host.
set -eu

f="$(mktemp /tmp/benign-setuid-flag.XXXXXX)"

echo "[cdr] SetUidFlagSet: chmod 4755 (explicit S_ISUID mode bit) on throwaway file $f (benign)"
# Use the octal mode so the chmod event's modes array carries S_ISUID explicitly
# (symbolic u+s does not reliably surface S_ISUID in the runtime event).
chmod 4755 "$f"
echo "[cdr] SetUidFlagSet: done"
