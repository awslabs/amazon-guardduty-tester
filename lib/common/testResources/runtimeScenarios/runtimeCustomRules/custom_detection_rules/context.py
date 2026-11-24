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

'''
Shared helpers for the runtime custom detection rule scenario path: the
best-effort package-install snippet builder and run-id generation. No AWS calls
are made here, so the module is unit-inspectable without a deployed stack; the
caller supplies any runtime-resolved values.
'''

import secrets
from datetime import datetime, timezone
from typing import Optional

# Per-OS install verb used by build_package_install. The Amazon Linux hosts use
# dnf; the Ubuntu host uses apt-get.
PACKAGE_MANAGERS = {'amazonlinux': 'dnf install -y', 'ubuntu': 'apt-get install -y'}


def build_package_install(packages, target_os) -> str:
    '''
    Build the best-effort package-install snippet that the harness prepends to a
    trigger, replacing the self-install lines that used to live in each scenario
    script. The scripts are OS-neutral; the harness decides which package
    manager to use from the rule's catalog `packages` and the target OS, so the
    same trigger can run on al2023 (dnf) or ubuntu (apt-get). `packages` is a
    flat list when the name is identical across OSes, or an object keyed by OS
    name (amazonlinux/ubuntu) when the package name differs between distros.

    Returns '' when packages is falsy (nothing to install). Otherwise it returns
    a retry loop (up to 3 attempts) that is both resilient and loud:

      - Resilient: a transient failure is retried. On al2023 the dnf repo can be
        briefly unreachable; on a freshly-booted ubuntu host the package index
        may be empty and cloud-init / unattended-upgrades may hold the dpkg lock, so a single install often fails and leaves the tool
        missing -- which then looks exactly like the rule simply not firing.
      - Loud: each failed attempt and a final give-up both print a '[cdr]' marker
        to stderr, which lands in the instance log. An install that never
        succeeds is therefore visible as a WARNING in the log rather than
        silently masquerading as a non-detection. Command stdout is dropped (it
        is noisy) but stderr is kept so the real failure reason survives.

    The snippet always ends successfully (`true`): a missing package must never
    abort the trigger. The install runs before the trigger's own `set -e`, so a
    non-zero install cannot stop the scenario either way.
    '''
    # packages may be a flat list (same name on every OS) or a dict keyed by
    # the target OS, e.g. {"amazonlinux": ["sqlite"], "ubuntu": ["sqlite3"]},
    # when the package name differs between distros.
    if isinstance(packages, dict):
        packages = packages.get(target_os) or []
    if not packages:
        return ''
    pkgs = ' '.join(packages)
    if target_os == 'ubuntu':
        # Wait out the dpkg lock (DPkg::Lock::Timeout); update the empty index
        # then install. `>/dev/null` drops stdout but keeps stderr.
        attempt = (
            'apt-get -o DPkg::Lock::Timeout=180 update -y >/dev/null 2>&1; '
            f'apt-get -o DPkg::Lock::Timeout=180 install -y {pkgs} >/dev/null'
        )
    else:
        manager = PACKAGE_MANAGERS.get(target_os, PACKAGE_MANAGERS['amazonlinux'])
        attempt = f'{manager} {pkgs} >/dev/null'
    return (
        '_cdr_ok=0; '
        'for _cdr_try in 1 2 3; do '
        f'if {attempt}; then _cdr_ok=1; break; fi; '
        f'echo "[cdr] package install attempt $_cdr_try/3 failed for: {pkgs}" >&2; '
        'sleep 10; '
        'done; '
        '[ "$_cdr_ok" = 1 ] || '
        f'echo "[cdr] WARNING: package install did not succeed after 3 attempts: {pkgs}" >&2; '
        'true'
    )


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def make_run_id(now: Optional[datetime] = None) -> str:
    '''
    Generate a run id: UTC timestamp plus a short random suffix, lowercase and
    dash-separated, e.g. "20261102t181530z-a1b2c3". Safe for use as a tag value
    and as a correlation key.
    '''
    now = now or _utcnow()
    stamp = now.strftime('%Y%m%dt%H%M%Sz')
    suffix = secrets.token_hex(3)
    return f'{stamp}-{suffix}'
