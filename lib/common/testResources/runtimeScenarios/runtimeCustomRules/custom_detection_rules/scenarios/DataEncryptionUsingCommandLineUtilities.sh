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
# Benign trigger for runtime custom detection rule DataEncryptionUsingCommandLineUtilities
# Finding type: Execution:Runtime/SuspiciousCommand
#
# Strategy: the rule keys only on process.name. Run the REAL `openssl enc` to
# AES-encrypt a throwaway temp file into a .enc output. process.name is the
# genuine 'openssl' performing a real encryption. Only a disposable temp file
# and its encrypted copy exist, both on the static test host.
set -eu

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/benign-data-encrypt.XXXXXX")"

f="$WORKDIR/data"
printf 'benign encryption sample\n' > "$f"

echo "[cdr] DataEncryptionUsingCommandLineUtilities: running real 'openssl enc -aes-256-cbc' on a throwaway temp file"
openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:benigntest -in "$f" -out "$f.enc"
echo "[cdr] DataEncryptionUsingCommandLineUtilities: done"
