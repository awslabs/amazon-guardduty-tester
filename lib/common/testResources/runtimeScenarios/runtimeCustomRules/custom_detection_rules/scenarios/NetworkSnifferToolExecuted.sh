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
# Benign trigger for runtime custom detection rule NetworkSnifferToolExecuted
# Finding type: Execution:Runtime/SuspiciousTool
#
# Strategy: the rule keys only on process.name. The harness installs tcpdump;
# this runs the REAL `tcpdump -c 1 -i any`. process.name is the genuine
# 'tcpdump'. Without CAP_NET_RAW the capture fails immediately, but the real
# binary executed and the name matches, so no extra privileges are needed.
# No packets are captured.
set -eu

echo "[cdr] NetworkSnifferToolExecuted: running real 'tcpdump -c 1 -i any' (may fail without CAP_NET_RAW; binary runs)"
tcpdump -c 1 -i any || true
echo "[cdr] NetworkSnifferToolExecuted: done"
