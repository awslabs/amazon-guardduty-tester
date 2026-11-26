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
# Benign trigger for runtime custom detection rule FindCommandReconCloudCredentials
# Finding type: Discovery:Runtime/SuspiciousCommand
#
# Strategy: run the REAL `find` over a throwaway workdir
# searching for `.netrc`. process.name is the genuine 'find' and the cmd_line
# contains `.netrc`, matching the rule's RE2. The search is read-only and
# confined to a disposable temp dir.
set -eu

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/benign-find-cloud-cred.XXXXXX")"

echo "[cdr] FindCommandReconCloudCredentials: running real 'find' for .netrc under a throwaway dir"
find "$WORKDIR" -name .netrc
echo "[cdr] FindCommandReconCloudCredentials: done"
