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

import sys
import signal
import argparse
import textwrap
from types import FrameType
from typing import Optional
from test_builder import TestBuilder
from settings_manager import SettingsManager


'''
using argparse parse user arguments and display help message where necessary
'''
def parse_args() -> argparse.Namespace:
    # establish parser with post argument description notes to display if "--help" flag passed
    parser = argparse.ArgumentParser(description='Python program to test GuardDuty finding generation', 
                                     formatter_class=argparse.RawDescriptionHelpFormatter,
                                     epilog=textwrap.dedent('''                                                                             
NOTES:
    - Script will default to run all published tests if no parameters are given
        - if no target (EC2, ECS, EKS, IAM, LAMBDA, or S3) specified, then all will be tested
        - if no tactic is specified all (applicable to each resource) will be tested
    - Defining tactics and or targets will tighten the scope of tests
    - Runtime findings only apply to EC2, ECS, and EKS
        - DEFAULT   -> true
        - true      -> will execute runtime finding tests
        - false     -> will omit runtime finding tests
        - only      -> will omit non runtime finding tests and run only runtime tests

EXAMPLES:
        python3 guardduty_tester.py
        python3 guardduty_tester.py --all
        python3 guardduty_tester.py --s3
        python3 guardduty_tester.py --tactics discovery
        python3 guardduty_tester.py --ec2 --eks --tactics backdoor policy execution
        python3 guardduty_tester.py --eks --runtime only
        python3 guardduty_tester.py --ec2 --runtime only --tactics impact
        python3 guardduty_tester.py --finding 'CryptoCurrency:EC2/BitcoinTool.B!DNS'                                        
         '''))
    
    # lists of all resources/tactics available to tester
    resources = [
        'ec2', 
        'ecs', 
        'eks', 
        'iam', 
        'lambda', 
        's3'
    ]
    tactics = [
        'backdoor',
        'crypto',
        'defense-evasion',
        'discovery',
        'execution',
        'impact',
        'pentest',
        'persistence',
        'policy',
        'privilege-escalation',
        'recon',
        'stealth',
        'trojan',
        'unauthorized-access'
    ]
    log_sources = [
        'dns',
        'vpc-flowlogs',
        'lambda',
        's3-logs',
        'cloudtrail',
        'eks-audit-logs',
        'runtime-monitoring'
    ]

    # add all resources as individual flags
    for resource in resources:
        parser.add_argument(f'--{resource}', action='append_const', const=resource, dest='test_resources', help=f'Declare to test {resource} findings')

    parser.add_argument('--all', action='store_true', default=False, help='Run all tests (all targets & all tactics)')
    parser.add_argument('--finding', nargs='*', type=str, default=None, help='Run test for specific finding(s), following the finding flag declare entire finding name(s) with single quotes around each finding')
    parser.add_argument('--runtime', nargs=1, type=str, default=['true'], choices=['true', 'false', 'only'], help='Declare runtime flag followed by either true, false, or only. Default: true')
    parser.add_argument('--tactics', nargs='*', type=str, choices=tactics, default=tactics, help='Declare tactics flag followed by one or more of options above to specify which finding type(s) to generate')
    parser.add_argument('--log-source', nargs='*', type=str, choices=log_sources, default=None, help='Declare log-sources flag followed by one or more of options above to specify which finding type(s) to generate')

    args = parser.parse_args()

    # if --all -> override resources and tactics to all
    if args.all:
        args.test_resources = resources
        args.tactics = tactics
        args.log_source = log_sources
    
    # default to all resources if not passed by user
    if not args.test_resources and not args.finding:
        args.test_resources = resources

    # if explicit finding(s) set, make tactics empty and rely only on declared findings
    if args.finding:
        args.tactics = []
        args.log_source = []

    return args


'''
guardduty tester main method
accepts user given parameters
establishes test settings based on args
dynamically builds guardduty tester scripts
runs and returns account back to original state
'''
if __name__ == '__main__':
    args = parse_args()

    settings = SettingsManager()
    tester = TestBuilder()

    '''
    function to handle graceful exit if any signal that would end the process recieved
    nested inside main method for closure access to settings object
    '''
    def signal_handler(signal: int, frame: Optional[FrameType]) -> None:
        # reset account settings if any changes have been made
        settings.reset_settings()
        sys.exit(0)

    # loop through each signal and assign signal handler
    for s in [ signal.SIGINT, signal.SIGTERM, signal.SIGHUP, signal.SIGTSTP, ]:
        signal.signal(s, signal_handler)
    
    settings.set_test_settings(args)
    
    tester.build_testing_script(settings.test_settings)
    tester.run_test_script()

    settings.reset_settings()
