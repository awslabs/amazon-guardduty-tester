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
# Benign trigger for runtime custom detection rule SuspiciousExecutionPath
# Finding type: DefenseEvasion:Runtime/SuspiciousCommand
#
# Strategy: the rule keys on the execution path. Stage a copy of the REAL
# system shell into /dev/shm (fallback /run/shm) and execute it from there
# doing trivial-but-genuine work (`id`, a 1s sleep). process.path is then
# '/dev/shm/%', and the running process is a real binary, not a no-op stub.
# The copy lives only on the static test host.
set -eu

SHM_DIR="/dev/shm"
[ -d "$SHM_DIR" ] && [ -w "$SHM_DIR" ] || SHM_DIR="/run/shm"
[ -d "$SHM_DIR" ] && [ -w "$SHM_DIR" ] || { echo "[cdr] SuspiciousExecutionPath: no writable shm dir; skipping" ; exit 0 ; }

target="$SHM_DIR/benign-suspicious-exec.$$"
src="$(command -v sh)"
cp "$src" "$target"
chmod +x "$target"

echo "[cdr] SuspiciousExecutionPath: executing real shell copied into $SHM_DIR"
"$target" -c 'id >/dev/null 2>&1; sleep 1'
echo "[cdr] SuspiciousExecutionPath: done"
