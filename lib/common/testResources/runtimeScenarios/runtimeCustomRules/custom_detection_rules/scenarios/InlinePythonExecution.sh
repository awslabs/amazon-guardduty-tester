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
# Benign trigger for runtime custom detection rule InlinePythonExecution
# Finding type: Execution:Runtime/SuspiciousCommand
#
# Strategy: the harness installs python3; this runs the REAL python3 with
# an inline `-c` snippet that imports os and calls os.system on the benign
# command 'true'. process.name is the genuine 'python3' (LIKE 'python%') and the
# cmd_line matches the "import os ... os.system" RE2. The interpreter really
# runs, but the only child command is the harmless 'true'.
set -eu

echo "[cdr] InlinePythonExecution: running real python3 inline snippet (os.system('true'))"
python3 -c "import os; os.system('true')"
echo "[cdr] InlinePythonExecution: done"
