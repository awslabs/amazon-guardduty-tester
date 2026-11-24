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
# Benign trigger for runtime custom detection rule DnsTunnelingToolExecuted
# Finding type: CommandAndControl:Runtime/SuspiciousCommand
#
# Strategy: the rule keys only on process.name. The harness installs a real
# DNS-tunneling tool (iodine, else dns2tcp); this runs its binary benignly
# (version/help only, no tunnel, no DNS traffic). process.name is then the
# genuine 'iodine'/'dns2tcpc', which is in the watched set.
#
# NOTE (recorded in report): these tools are exotic and may be absent from the
# OS package repos. If neither installs, no real binary runs and the rule
# cannot be matched benignly — this is logged, with no no-op stub fallback.
set -eu

if command -v iodine >/dev/null 2>&1; then
  echo "[cdr] DnsTunnelingToolExecuted: running real 'iodine -v' (version only, no tunnel)"
  iodine -v || true
elif command -v dns2tcpc >/dev/null 2>&1; then
  echo "[cdr] DnsTunnelingToolExecuted: running real 'dns2tcpc' help (no tunnel)"
  dns2tcpc || true
else
  echo "[cdr] DnsTunnelingToolExecuted: no DNS-tunneling tool available; rule cannot match benignly"
fi
echo "[cdr] DnsTunnelingToolExecuted: done"
