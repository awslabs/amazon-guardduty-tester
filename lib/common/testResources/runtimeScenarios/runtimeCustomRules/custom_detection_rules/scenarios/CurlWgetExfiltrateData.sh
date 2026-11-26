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
# Benign trigger for runtime custom detection rule CurlWgetExfiltrateData
# Finding type: Exfiltration:Runtime/SuspiciousCommand
#
# Strategy: run the REAL `curl` performing an UPLOAD (`-T <tmpfile>`) to a
# loopback URL (http://127.0.0.1:9/benign). This is an exfiltration-shaped
# operation, not a plain GET. process.name is the genuine 'curl' and the
# cmd_line contains '://'. Port 9 on loopback has no listener, so the upload is
# refused and nothing leaves the instance. The file is a disposable temp file.
set -eu

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/benign-curl-exfil.XXXXXX")"

f="$WORKDIR/data"
printf 'benign exfil sample\n' > "$f"

echo "[cdr] CurlWgetExfiltrateData: running real 'curl -T <tmpfile> http://127.0.0.1:9/benign' (loopback upload, refused)"
curl --max-time 3 -T "$f" http://127.0.0.1:9/benign || true
echo "[cdr] CurlWgetExfiltrateData: done"
