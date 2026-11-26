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
# Benign trigger for runtime custom detection rule RawSocketCreated
# Finding type: Execution:Runtime/SuspiciousTool
#
# Strategy: create one AF_PACKET / SOCK_RAW socket in Python with a realistic
# protocol htons(ETH_P_ALL) (3) and hold it ~1.5s before closing, running as
# root (SSM runs as root). Giving the socket a real protocol and a short
# lifetime makes the socket() EVENT reliably observed, where proto 0 with an
# instant close could be missed. We never bind it, never put an interface in
# promiscuous mode, and never send or receive a packet, so no traffic is
# captured. If AF_PACKET is unavailable we fall back to `tcpdump -c 1` on
# loopback, which opens the same AF_PACKET/SOCK_RAW socket under the hood.
set -eu

echo "[cdr] RawSocketCreated: creating one AF_PACKET SOCK_RAW socket (ETH_P_ALL), holding ~1.5s (no bind, no packets, benign)"
if python3 -c "import socket, time; s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3)); time.sleep(1.5); s.close()"; then
    echo "[cdr] RawSocketCreated: python3 AF_PACKET SOCK_RAW socket created and closed"
else
    echo "[cdr] RawSocketCreated: AF_PACKET via python3 unavailable, falling back to tcpdump -c 1 on loopback"
    tcpdump -i lo -c 1 || true
fi
echo "[cdr] RawSocketCreated: done"
