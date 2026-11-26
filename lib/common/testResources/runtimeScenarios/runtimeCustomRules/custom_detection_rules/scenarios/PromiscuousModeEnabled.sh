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
# Benign trigger for runtime custom detection rule PromiscuousModeEnabled
# Finding type: Discovery:Runtime/SuspiciousCommand
#
# Strategy: enable promiscuous mode on the LOOPBACK interface (lo) with
# `ip link set`. The cmd_line contains 'promisc on' and the process name is
# 'ip' (matches the rule). Loopback carries no external traffic, so enabling
# promiscuous mode on it sniffs nothing. Runs only on the static
# test host; nothing is restored.
set -eu

echo "[cdr] PromiscuousModeEnabled: ip link set dev lo promisc on (loopback only, benign)"
ip link set dev lo promisc on
echo "[cdr] PromiscuousModeEnabled: done"
