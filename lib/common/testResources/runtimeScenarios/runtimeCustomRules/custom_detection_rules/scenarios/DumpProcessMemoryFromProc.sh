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
# Benign trigger for runtime custom detection rule DumpProcessMemoryFromProc
# Finding type: CredentialAccess:Runtime/SensitiveFileRead
#
# Strategy: open ANOTHER process's /proc/<pid>/mem read-only -- the behavior the
# rule actually watches (dumping a different process's memory, not benign
# self-introspection). We spawn our own short-lived throwaway `sleep` child,
# open its '/proc/<pid>/mem' O_RDONLY, read at most one byte and discard it,
# then reap the child. The open event (filepath '/proc/<pid>/mem' matches
# '/proc/%/mem') is recorded; nothing sensitive is retained or exfiltrated and
# the only process touched is our own disposable child.
set -eu

echo "[cdr] DumpProcessMemoryFromProc: opening another process's /proc/<pid>/mem read-only (benign)"
sleep 30 &
TARGET_PID=$!
dd if="/proc/${TARGET_PID}/mem" of=/dev/null bs=1 count=1 >/dev/null 2>&1 || \
  head -c 1 "/proc/${TARGET_PID}/mem" >/dev/null 2>&1 || true
kill "${TARGET_PID}" || true
echo "[cdr] DumpProcessMemoryFromProc: done"
