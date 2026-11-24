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
# Benign trigger for runtime custom detection rule CurlWgetScriptDownload
# Finding type: Execution:Runtime/SuspiciousCommand
#
# Strategy: take the first branch — run the REAL `curl` piped into a shell
# (`curl -s http://127.0.0.1/benign.sh | sh`). The pipe makes process.stdout a
# 'pipe' and the URL ends in `.sh`, matching the download-and-execute RE2.
# process.name is the genuine 'curl'. Loopback port 80 has no server, so curl
# returns an empty body and `sh` reads nothing to execute.
set -eu

echo "[cdr] CurlWgetScriptDownload: running real 'curl -s http://127.0.0.1/benign.sh | sh' (loopback, empty body)"
curl -s --max-time 3 http://127.0.0.1/benign.sh | sh || true
echo "[cdr] CurlWgetScriptDownload: done"
