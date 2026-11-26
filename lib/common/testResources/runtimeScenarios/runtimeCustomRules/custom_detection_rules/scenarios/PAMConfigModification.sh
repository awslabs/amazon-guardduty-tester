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
# Benign trigger for runtime custom detection rule PAMConfigModification
# Finding type: Persistence:Runtime/SensitiveFileModified
#
# Strategy: create a NEW throwaway file /etc/pam.d/benign with a zero-byte
# append. The path matches the rule's '/etc/pam.d/%' LIKE and the append opens
# it O_WRONLY. We do NOT touch any real PAM stack file, so no authentication
# policy changes. Runs as root on the static test host;
# nothing is restored.
set -eu

TARGET='/etc/pam.d/benign'
echo "[cdr] PAMConfigModification: creating throwaway $TARGET (benign, no PAM change)"
printf '' >> "$TARGET"
echo "[cdr] PAMConfigModification: done"
