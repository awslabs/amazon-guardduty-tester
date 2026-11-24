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
# Benign trigger for runtime custom detection rule DataSplittingForExfiltration
# Finding type: Exfiltration:Runtime/SuspiciousCommand
#
# Strategy: run the REAL coreutils `split` on a 4 KiB
# throwaway temp file, slicing it into 1 KiB parts under the workdir
# (`split -b 1024`). process.name is the genuine 'split' and the cmd_line has
# `-b 1024`, matching the byte-size branch. Only disposable temp files are used.
set -eu

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/benign-data-splitting.XXXXXX")"
f="$WORKDIR/data"
head -c 4096 /dev/zero > "$f"

echo "[cdr] DataSplittingForExfiltration: running real 'split -b 1024' on a throwaway temp file"
split -b 1024 "$f" "$WORKDIR/part."
echo "[cdr] DataSplittingForExfiltration: done"
