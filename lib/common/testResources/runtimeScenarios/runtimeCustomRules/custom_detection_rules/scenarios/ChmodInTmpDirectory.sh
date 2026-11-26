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
# Benign trigger for runtime custom detection rule ChmodInTmpDirectory
# Finding type: Execution:Runtime/SuspiciousCommand
#
# Strategy: take the EVENT branch. Use the real `chmod` (process.name 'chmod')
# to mark a throwaway file under /tmp executable. The chmod event's filepath is
# under '/tmp/%', matching the rule. The file is an empty temp file on the
# static test host; nothing else is touched.
set -eu

f="$(mktemp /tmp/benign-chmod-tmp.XXXXXX)"

echo "[cdr] ChmodInTmpDirectory: chmod +x on throwaway file $f (benign)"
chmod +x "$f"
echo "[cdr] ChmodInTmpDirectory: done"
