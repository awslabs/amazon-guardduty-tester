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
# Benign trigger for runtime custom detection rule LDPreloadFunctionHijack
# Finding type: DefenseEvasion:Runtime/SensitiveFileModified
#
# Strategy: create an EMPTY /etc/ld.so.preload (O_WRONLY open of the exact
# watched path), which matches the rule. The file is left empty, so no library
# is ever preloaded. Runs as root on the static test host;
# nothing is restored.
set -eu

TARGET='/etc/ld.so.preload'
echo "[cdr] LDPreloadFunctionHijack: creating empty $TARGET (benign, no preload)"
: > "$TARGET"
echo "[cdr] LDPreloadFunctionHijack: done"
