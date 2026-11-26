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
# Benign trigger for runtime custom detection rule ShellFromUtilities
# Finding type: Execution:Runtime/SuspiciousCommand
#
# Strategy: run the REAL `awk` (often gawk) with the GTFOBins-style program
# `BEGIN{system("/bin/sh -c true")}`. process.name is the genuine 'awk'/'gawk'
# and the cmd_line matches the awk-spawns-shell RE2. awk really execs
# `/bin/sh -c true`, whose only action is the harmless builtin 'true'.
set -eu

echo "[cdr] ShellFromUtilities: running real awk with BEGIN{system(\"/bin/sh -c true\")}"
awk 'BEGIN{system("/bin/sh -c true")}'
echo "[cdr] ShellFromUtilities: done"
