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
# Benign trigger for test PasswordShadowFileDiscoveryShadow (rule PasswordShadowFileDiscovery)
# Finding type: Discovery:Runtime/SensitiveFileRead
#
# Strategy: read /etc/shadow with cat (a reader in the rule's process list), a watched credential file. Runs on the static test host;
# the change is benign and nothing is restored.
set -eu
TARGET='/etc/shadow'
cat "$TARGET" >/dev/null 2>&1
echo "[cdr] PasswordShadowFileDiscoveryShadow: done"
