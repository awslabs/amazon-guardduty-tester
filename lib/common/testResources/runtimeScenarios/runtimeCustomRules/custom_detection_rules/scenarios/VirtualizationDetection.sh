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
# Benign trigger for runtime custom detection rule VirtualizationDetection
# Finding type: Discovery:Runtime/SuspiciousCommand
#
# Strategy: the rule keys on process name/path. systemd is present, so this
# runs the REAL `systemd-detect-virt` (a benign hypervisor probe).
# process.name is the genuine 'systemd-detect-virt', which is in the watched
# set. It only reports the detected virtualization; it changes nothing.
set -eu

echo "[cdr] VirtualizationDetection: running real 'systemd-detect-virt' (benign probe)"
systemd-detect-virt || true
echo "[cdr] VirtualizationDetection: done"
