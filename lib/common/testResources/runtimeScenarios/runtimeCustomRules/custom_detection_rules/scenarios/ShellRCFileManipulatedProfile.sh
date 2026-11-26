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
# Benign trigger for test ShellRCFileManipulatedProfile (rule ShellRCFileManipulated)
# Finding type: Persistence:Runtime/SensitiveFileModified
#
# Strategy: append a benign comment to ~/.profile (matches the rule's '%/.profile' LIKE). Runs on the static test host;
# the change is benign and nothing is restored.
set -eu
TARGET='/root/.profile'
printf '%s\n' '# benign marker' >> "$TARGET"
echo "[cdr] ShellRCFileManipulatedProfile: done"
