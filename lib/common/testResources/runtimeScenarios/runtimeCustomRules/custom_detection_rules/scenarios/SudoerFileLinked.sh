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
# Benign trigger for runtime custom detection rule SudoerFileLinked
# Finding type: PrivilegeEscalation:Runtime/SensitiveFileModified
#
# Strategy: create a symlink whose link_path is /etc/sudoers.d/benign-link
# (matches the rule's '/etc/sudoers.d/%' LIKE) pointing at /dev/null. The
# symlink target is /dev/null, so it grants nothing even if read by sudo. Runs
# as root on the static test host (SSM runs as root);
# nothing is restored.
set -eu

LINK='/etc/sudoers.d/benign-link'
echo "[cdr] SudoerFileLinked: creating symlink $LINK -> /dev/null (benign, grants nothing)"
# The host is reused across runs, so drop any link left by an earlier run.
rm -f "$LINK"
ln -s /dev/null "$LINK"
echo "[cdr] SudoerFileLinked: done"
