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
# Benign trigger for runtime custom detection rule Base64EncodeDecode
# Finding type: DefenseEvasion:Runtime/SuspiciousCommand
#
# Strategy: run the REAL coreutils `base64` against a tiny
# throwaway temp file: encode it, then decode the result. process.name is the
# genuine 'base64', so GuardDuty sees the real executable identity and behavior.
# Only a disposable temp file is touched; nothing leaves the instance.
set -eu

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/benign-base64.XXXXXX")"

f="$WORKDIR/data"
printf 'benign base64 sample\n' > "$f"

echo "[cdr] Base64EncodeDecode: running real base64 encode/decode on a throwaway temp file"
base64 "$f" > "$f.b64" 2>/dev/null
base64 -d "$f.b64" > "$f.out" 2>/dev/null
echo "[cdr] Base64EncodeDecode: done"
