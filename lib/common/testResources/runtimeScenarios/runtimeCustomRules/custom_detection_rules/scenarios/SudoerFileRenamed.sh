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
# Benign trigger for runtime custom detection rule SudoerFileRenamed
# Finding type: PrivilegeEscalation:Runtime/SensitiveFileModified
#
# Strategy: rename an empty throwaway file into /etc/sudoers.d/benign-renamed
# (the rename target matches the rule's '/etc/sudoers.d/%' LIKE). The moved
# file is empty, so it grants nothing. Runs as root on the static
# test host; nothing is restored.
set -eu

# Stage the source under /etc (same filesystem as the target) so `mv` issues a
# real rename(2) syscall. A cross-filesystem mv (e.g. /tmp -> /etc when /tmp is
# tmpfs) silently degrades to copy+unlink and emits no rename event.
SRC='/etc/.benign-sudoers-src'
TARGET='/etc/sudoers.d/benign-renamed'
echo "[cdr] SudoerFileRenamed: rename(2) $SRC -> $TARGET (same-fs) (benign, grants nothing)"
: > "$SRC"
mv "$SRC" "$TARGET"
echo "[cdr] SudoerFileRenamed: done"
