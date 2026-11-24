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
# Benign trigger for runtime custom detection rule SshFromPublicIPAddress
# Finding type: Persistence:Runtime/SuspiciousCommand
#
# Strategy: the rule fires on a non-root post-login sshd child whose remote peer
# is a public IP on a different /16 from the local IP, with remote port > local
# port. We reproduce that entirely on-box with iptables:
#
#   1. route_localnet=1 lets loopback-destined packets be routed through NAT.
#   2. OUTPUT DNAT redirects a connection aimed at a documentation-range public
#      IP (203.0.113.1, RFC 5737 TEST-NET-3) to the real local sshd on
#      127.0.0.1:22.
#   3. POSTROUTING SNAT rewrites the source so sshd sees the peer as 203.0.113.1
#      -- public, and a different /16 from loopback. The client's ephemeral
#      source port is high, so remote port > local port (22) holds.
#
# The login must succeed to produce a post-login child, so we log in as the
# default user 'ubuntu' (a non-root user, which is what the rule keys on) using
# an ephemeral key we authorize for it. Authorizing that key writes the user's
# authorized_keys, which also trips SSHAuthorizedKeysModification on this
# instance -- unavoidable collateral for a real non-root login. No cleanup: the
# test host is a static instance used only for these tests.
# Prerequisites below must succeed for the login to fire the rule, so the
# script fails fast (set -e) if any of them error. Only the final ssh login --
# the benign trigger -- tolerates a non-zero exit.
set -eu

USER_NAME="ubuntu"
FAKE_PUBLIC_IP="203.0.113.1"

echo "[cdr] SshFromPublicIPAddress: authorizing an ephemeral key for $USER_NAME"
KEY_DIR="$(mktemp -d)"
ssh-keygen -q -t ed25519 -N '' -f "$KEY_DIR/id"
mkdir -p "/home/$USER_NAME/.ssh"
cat "$KEY_DIR/id.pub" >> "/home/$USER_NAME/.ssh/authorized_keys"
chown -R "$USER_NAME:" "/home/$USER_NAME/.ssh"
chmod 700 "/home/$USER_NAME/.ssh"
chmod 600 "/home/$USER_NAME/.ssh/authorized_keys"

echo "[cdr] SshFromPublicIPAddress: enabling route_localnet and NAT so loopback sshd sees a public peer ($FAKE_PUBLIC_IP)"
sysctl -w net.ipv4.conf.all.route_localnet=1
iptables -t nat -A OUTPUT -p tcp -d "$FAKE_PUBLIC_IP" --dport 22 -j DNAT --to-destination 127.0.0.1:22
iptables -t nat -A POSTROUTING -p tcp -d 127.0.0.1 --dport 22 -j SNAT --to-source "$FAKE_PUBLIC_IP"

echo "[cdr] SshFromPublicIPAddress: logging in as $USER_NAME over ssh to $FAKE_PUBLIC_IP (NAT'd to loopback sshd)"
ssh -i "$KEY_DIR/id" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=5 \
  "$USER_NAME@$FAKE_PUBLIC_IP" true || true

echo "[cdr] SshFromPublicIPAddress: done"
