#!/usr/bin/env python3
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
gd_investigator.py - standalone CLI for GuardDuty AI-Powered Investigations.

Independent of the CDK app and the tester driver: runs from a laptop/CI with
your own AWS credentials against any account, using boto3 directly.

Subcommands:
  enable    Enable/verify the AI_ANALYST feature on the detector
  finding   Investigate a single finding by 32-char id
  account   Account-level analysis
  org       Organization-level analysis
  list      List past investigations
  get       Fetch and render a single investigation
  prompts   Browse the trigger-prompt library
'''

import sys
import argparse
import textwrap

from botocore.exceptions import ClientError

from core import constants, guide, investigator, report
from core.enablement import (
    InvestigationError,
    assert_supported_region,
    ensure_ai_analyst_enabled,
    resolve_detector_id,
)
from modes import account_org, finding


# --- subcommand handlers: each takes (args, gd_client, detector_id) ---

def _common(args) -> dict:
    return dict(wait=not args.no_wait, poll_timeout=args.poll_timeout, as_json=args.as_json)


def _cmd_enable(args, gd_client, detector_id):
    # Returns only when enabled, otherwise raises — so reaching here means enabled.
    ensure_ai_analyst_enabled(gd_client, detector_id, args.yes)
    print(f'AI_ANALYST enabled on detector {detector_id}.')


def _cmd_finding(args, gd_client, detector_id):
    finding.run(gd_client, detector_id, args.finding_id, args.yes, **_common(args))


def _cmd_account(args, gd_client, detector_id):
    account_org.run_account(gd_client, detector_id, args.account_id, args.yes, **_common(args))


def _cmd_org(args, gd_client, detector_id):
    account_org.run_org(gd_client, detector_id, args.yes, **_common(args))


def _cmd_list(args, gd_client, detector_id):
    summaries = investigator.list_investigations(
        gd_client, detector_id, args.sort, args.order, args.max_results)
    print(report.render_summary_table(summaries))


def _cmd_get(args, gd_client, detector_id):
    investigation = investigator.get(gd_client, detector_id, args.investigation_id)
    print(report.render(investigation, as_json=args.as_json))


# --- offline handlers: no AWS, take only args ---

def _cmd_prompts(args):
    print(guide.render_prompts(search=args.search, prompt_id=args.id))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description='Run GuardDuty AI-Powered Investigations (Preview).',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent('''
            EXAMPLES:
                gd_investigator.py enable
                gd_investigator.py finding 1ab2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
                gd_investigator.py account 123456789012
                gd_investigator.py list --sort START_TIME --order DESC
                gd_investigator.py get a1b2c3d4-5678-90ab-cdef-ef1234567890

            LEARN MORE (no AWS calls):
                gd_investigator.py prompts          # browse the trigger-prompt library

            Preview is limited to 10 regions and 10 investigations/account/day
            (100 total); failed investigations do not count.
            '''),
    )

    # Global options shared by all subcommands.
    parser.add_argument('--region', default=None, help='AWS region (default: session region)')
    parser.add_argument('--detector-id', default=None, help='GuardDuty detector id (auto-resolved if omitted)')
    parser.add_argument('--yes', action='store_true', help='Assume "yes" for all prompts')
    parser.add_argument('--no-wait', action='store_true', help='Create and return without polling for results')
    parser.add_argument('--poll-timeout', type=int, default=constants.DEFAULT_POLL_TIMEOUT_SECONDS,
                        help='Seconds to wait for an investigation to complete')
    parser.add_argument('--json', action='store_true', dest='as_json', help='Output raw JSON')

    # Commands default to needing AWS; offline ones set offline=True below.
    parser.set_defaults(offline=False)

    sub = parser.add_subparsers(dest='command', required=True)

    sub.add_parser('enable', help='Enable/verify the AI_ANALYST feature').set_defaults(func=_cmd_enable)

    p_finding = sub.add_parser('finding', help='Investigate a single finding id')
    p_finding.add_argument('finding_id', help='32-character hexadecimal finding id')
    p_finding.set_defaults(func=_cmd_finding)

    p_account = sub.add_parser('account', help='Account-level analysis')
    p_account.add_argument('account_id', help='12-digit AWS account id')
    p_account.set_defaults(func=_cmd_account)

    sub.add_parser('org', help='Organization-level analysis').set_defaults(func=_cmd_org)

    p_list = sub.add_parser('list', help='List past investigations')
    p_list.add_argument('--sort', default=None, choices=sorted(constants.SORT_ATTRIBUTES),
                       help='Sort attribute')
    p_list.add_argument('--order', default='DESC', choices=sorted(constants.SORT_ORDERS),
                       help='Sort order (default: DESC)')
    p_list.add_argument('--max', type=int, default=None, dest='max_results',
                       help='Max results to return')
    p_list.set_defaults(func=_cmd_list)

    p_get = sub.add_parser('get', help='Fetch a single investigation')
    p_get.add_argument('investigation_id', help='Investigation id (uuid)')
    p_get.set_defaults(func=_cmd_get)

    p_prompts = sub.add_parser('prompts', help='Browse the trigger-prompt library')
    p_prompts.add_argument('--search', default=None, help='Free-text search')
    p_prompts.add_argument('--id', default=None, help='Show one prompt by id')
    p_prompts.set_defaults(func=_cmd_prompts, offline=True)

    return parser


def _is_unknown_operation(err: Exception) -> bool:
    '''True when an error indicates the Investigation APIs are missing from the SDK.'''
    if isinstance(err, AttributeError):
        # e.g. 'GuardDuty' object has no attribute 'create_investigation'
        return 'investigation' in str(err).lower()
    if isinstance(err, ClientError):
        code = err.response.get('Error', {}).get('Code', '')
        return code in ('UnknownOperationException', 'UnknownOperation')
    return False


def main() -> int:
    args = build_parser().parse_args()

    try:
        # The offline prompts command needs no AWS session or detector.
        if args.offline:
            args.func(args)
            return 0

        import boto3  # deferred: offline commands skip boto3's load entirely.
        session = boto3.session.Session(region_name=args.region)
        region = session.region_name
        if not region:
            print('ERROR: no region configured. Pass --region or set a default region.',
                  file=sys.stderr)
            return 2

        assert_supported_region(region)
        gd_client = session.client('guardduty')
        detector_id = resolve_detector_id(gd_client, args.detector_id)
        args.func(args, gd_client, detector_id)
    except InvestigationError as err:
        print(f'ERROR: {err}', file=sys.stderr)
        return 1
    except (AttributeError, ClientError) as err:
        # The Investigation APIs are preview; an older boto3/botocore won't have
        # them (AttributeError on the client) or the service rejects them as an
        # UnknownOperation. Recommend upgrading rather than dumping a raw trace.
        if _is_unknown_operation(err):
            print(
                'ERROR: the GuardDuty Investigation APIs are unavailable in your '
                'installed AWS SDK. They are in preview and require a newer '
                'boto3/botocore. Upgrade with: pip install -U boto3 botocore',
                file=sys.stderr,
            )
            return 1
        raise
    except KeyboardInterrupt:
        print('\nInterrupted.', file=sys.stderr)
        return 130

    return 0


if __name__ == '__main__':
    sys.exit(main())
