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
# Benign trigger for runtime custom detection rule S3DataExfiltrationWithRclone
# Finding type: Exfiltration:Runtime/SuspiciousCommand
#
# Strategy: the harness installs rclone; this runs the REAL `rclone copy` of a
# throwaway temp file to an UNCONFIGURED remote (`throwaway:bucket`).
# process.name is the genuine 'rclone' and the cmd_line matches the
# rclone-copy-to-remote RE2. With no remote configured, rclone errors
# immediately and transfers nothing.
#
# NOTE (recorded in report): rclone may be absent from the OS package repos. If
# it cannot be installed, no real binary runs and the rule cannot match
# benignly — this is logged, with no no-op stub fallback.
set -eu

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/benign-rclone-exfil.XXXXXX")"

if command -v rclone >/dev/null 2>&1; then
  f="$WORKDIR/data"
  printf 'benign\n' > "$f"
  echo "[cdr] S3DataExfiltrationWithRclone: running real 'rclone copy <tmpfile> throwaway:bucket' (unconfigured remote -> error)"
  rclone copy "$f" throwaway:bucket || true
else
  echo "[cdr] S3DataExfiltrationWithRclone: rclone unavailable; rule cannot match benignly"
fi
echo "[cdr] S3DataExfiltrationWithRclone: done"
