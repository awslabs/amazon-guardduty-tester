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
# Benign trigger for runtime custom detection rule DebugfsRawDiskAccess
# Finding type: DefenseEvasion:Runtime/SuspiciousCommand
#
# Strategy: prefer the REAL root block device (EC2 host, running as root) --
# `debugfs` read-only against it is the genuine direct-volume-access the rule
# watches. `show_super_stats -h` only reads the superblock; there is no -w, so
# nothing on disk is modified. If the root device is not a raw block device,
# fall back to a disposable loopback image; either way process.name is
# 'debugfs' and cmd_line contains '/dev/...'.
set -eu

ROOTDEV="$(findmnt -no SOURCE / 2>/dev/null || true)"
case "$ROOTDEV" in
  /dev/*)
    echo "[cdr] DebugfsRawDiskAccess: debugfs read-only against root device $ROOTDEV (benign, read-only)"
    debugfs -R 'show_super_stats -h' "$ROOTDEV" || true
    ;;
  *)
    IMG="$(mktemp /tmp/benign-disk.XXXXXX.img)"
    dd if=/dev/zero of="$IMG" bs=1M count=8 || true
    mkfs.ext4 -F "$IMG" || true
    LOOP="$(losetup -f --show "$IMG" 2>/dev/null)" || LOOP=''
    if [ -n "$LOOP" ]; then
      echo "[cdr] DebugfsRawDiskAccess: debugfs read-only against throwaway loop $LOOP (benign)"
      debugfs -R 'show_super_stats -h' "$LOOP" || true
      losetup -d "$LOOP" || true
    else
      echo "[cdr] DebugfsRawDiskAccess: no raw device available; invoking debugfs against /dev placeholder (read-only, benign)"
      debugfs -R 'ls' /dev/loop-benign || true
    fi
    rm -f "$IMG" || true
    ;;
esac
echo "[cdr] DebugfsRawDiskAccess: done"
