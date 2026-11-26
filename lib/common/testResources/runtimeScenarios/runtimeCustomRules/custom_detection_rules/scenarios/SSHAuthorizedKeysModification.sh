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
# Benign trigger for runtime custom detection rule SSHAuthorizedKeysModification
# Finding type: Persistence:Runtime/SensitiveFileModified
#
# Strategy: append a harmless comment line to the invoking user's
# ~/.ssh/authorized_keys. The append opens the file with O_WRONLY (overlaps
# the rule's flag set) and the path ends in ".ssh/authorized_keys" (matches
# the rule's LIKE). This is user-scoped, needs no root, and adds only an
# inert comment line.
set -eu

HOME="${HOME:-/root}"
KEYS="$HOME/.ssh/authorized_keys"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

echo "[cdr] SSHAuthorizedKeysModification: appending benign marker to $KEYS"
printf '# benign runtime test marker %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$KEYS"
chmod 600 "$KEYS"
echo "[cdr] SSHAuthorizedKeysModification: done"
