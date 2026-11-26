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
# Benign trigger for runtime custom detection rule BpftoolProgramLoaded
# Finding type: DefenseEvasion:Runtime/SuspiciousCommand
#
# Strategy: run `bpftool prog load` (process.name 'bpftool', cmd_line contains
# 'prog load', matching the rule). The program is not a real rootkit: we point
# it at an empty object file so the load is a no-op. Detection is on the exec +
# cmd_line, so it fires whether or not the load succeeds. Runs only on the
# static test host; nothing is restored.
set -eu

mount -t bpf bpf /sys/fs/bpf || true
PIN='/sys/fs/bpf/benign-prog'
OBJ="$(mktemp /tmp/benign-bpf.XXXXXX.o)"
: > "$OBJ"

echo "[cdr] BpftoolProgramLoaded: invoking bpftool prog load (no-op object, benign)"
bpftool prog load "$OBJ" "$PIN" || true
echo "[cdr] BpftoolProgramLoaded: done"
