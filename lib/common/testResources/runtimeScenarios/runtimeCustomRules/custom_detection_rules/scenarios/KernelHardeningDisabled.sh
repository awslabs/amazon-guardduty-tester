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
# Benign trigger for runtime custom detection rule KernelHardeningDisabled
# Finding type: DefenseEvasion:Runtime/SuspiciousCommand
#
# Strategy: perform a genuine hardening-DISABLING `sysctl -w` -- set
# kernel.randomize_va_space to 0 (ASLR off), the behavior the rule actually
# watches. A value-preserving write (same value) does NOT trigger the live
# rule, so the weakening write is required. process.name is the genuine
# 'sysctl' and the cmd_line contains 'kernel.'. SAFETY: this runs only on the
# static test host (SSM runs as root); the setting does not survive a reboot. If
# the write is not permitted it simply EPERMs while the sysctl exec still matches
# the rule. Nothing is restored.
set -eu

echo "[cdr] KernelHardeningDisabled: sysctl -w kernel.randomize_va_space=0 (disable ASLR; not restored)"
sysctl -w kernel.randomize_va_space=0 || true
echo "[cdr] KernelHardeningDisabled: done"
