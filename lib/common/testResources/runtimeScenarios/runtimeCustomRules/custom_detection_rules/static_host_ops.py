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
StaticHostOps performs the EC2/SSM AWS calls the ScenarioRunner injects. It does
not create or terminate anything: the test hosts are static instances created by
the CDK stack. It finds them by tag/name, waits for each to be reachable through
SSM and for the GuardDuty Runtime Monitoring agent to be active, and runs shell
commands on them through SSM AWS-RunShellScript.

Keeping boto3 here preserves the runner's AWS-free plan mode.
'''

import time
from typing import Dict, List

import boto3
from botocore.exceptions import ClientError

import tester_vars as vars
from . import cdr_config as cfg
from .runner import Host

# SSM command states that mean the command is still in flight.
_IN_FLIGHT = ('Pending', 'InProgress', 'Delayed')


class StaticHostOps:
    def __init__(self) -> None:
        self.ec2 = boto3.client('ec2', region_name=vars.REGION)
        self.ssm = boto3.client('ssm', region_name=vars.REGION)

    def _running_instances(self, filters: List[dict]) -> List[dict]:
        '''Return the running instances matching the filters, as (id, Name) dicts.'''
        resp = self.ec2.describe_instances(
            Filters=filters + [{'Name': 'instance-state-name', 'Values': ['running']}])
        found = []
        for reservation in resp.get('Reservations', []):
            for instance in reservation.get('Instances', []):
                tags = {t['Key']: t['Value'] for t in instance.get('Tags', [])}
                found.append({'id': instance['InstanceId'], 'name': tags.get('Name', instance['InstanceId'])})
        return sorted(found, key=lambda i: i['name'])

    def find_hosts(self) -> Dict[str, List[Host]]:
        '''
        Find the running static hosts, keyed by OS name. The Amazon Linux hosts are
        found by tag and sorted by name, which fixes their order (and so the test
        distribution). The Ubuntu host is found by its Name tag. An OS with no
        running host maps to an empty list.
        '''
        al = self._running_instances(
            [{'Name': f'tag:{cfg.CDR_HOST_TAG_KEY}', 'Values': [cfg.CDR_HOST_TAG_VALUE_AL2023]}])
        ubuntu = self._running_instances(
            [{'Name': 'tag:Name', 'Values': [cfg.UBUNTU_HOST_NAME]}])
        return {
            'amazonlinux': [Host('amazonlinux', i['name'], i['id']) for i in al],
            'ubuntu': [Host('ubuntu', i['name'], i['id']) for i in ubuntu],
        }

    def wait_ssm_online(self, instance_id: str, timeout: int = 900) -> bool:
        '''Poll until the instance's SSM agent reports Online. Returns False on timeout.'''
        deadline = time.time() + timeout
        status = 'not registered with SSM'
        while True:
            resp = self.ssm.describe_instance_information(
                Filters=[{'Key': 'InstanceIds', 'Values': [instance_id]}])
            for info in resp.get('InstanceInformationList', []):
                status = info.get('PingStatus', status)
                if status == 'Online':
                    return True
            if time.time() >= deadline:
                # ConnectionLost means it registered and then dropped off (for example
                # the host ran out of memory); 'not registered' means it never came up.
                print(f'[cdr] {instance_id}: SSM status at timeout: {status}')
                return False
            time.sleep(5)

    def wait_agent_active(self, instance_id: str, timeout: int = 600) -> bool:
        '''
        Poll the instance (via SSM) until the GuardDuty Runtime Monitoring agent's
        systemd service reports 'active', then wait a short init delay so the
        agent's backend session is established before the first trigger. Running a
        trigger before the sensor is active is the documented false-negative cause.
        Returns False on timeout (the caller reports it and carries on).
        '''
        deadline = time.time() + timeout
        while True:
            try:
                command_id = self.run_shell(instance_id, 'systemctl is-active amazon-guardduty-agent')
                self.wait(command_id, instance_id, timeout=60)
                resp = self.ssm.get_command_invocation(CommandId=command_id, InstanceId=instance_id)
                if resp.get('StandardOutputContent', '').strip() == 'active':
                    if cfg.CDR_AGENT_INIT_DELAY > 0:
                        time.sleep(cfg.CDR_AGENT_INIT_DELAY)
                    return True
            except ClientError:
                pass
            if time.time() >= deadline:
                return False
            time.sleep(10)

    def run_shell(self, instance_id: str, command_text: str) -> str:
        '''Send one shell command to the instance via SSM AWS-RunShellScript; return the command id.'''
        resp = self.ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName='AWS-RunShellScript',
            Parameters={'commands': [command_text]},
        )
        return resp['Command']['CommandId']

    def wait(self, command_id: str, instance_id: str, timeout: int = 300) -> str:
        '''
        Poll the command invocation until it leaves the in-flight states, tolerating
        the brief InvocationDoesNotExist window right after send_command. Returns the
        final SSM status ('Success', 'Failed', 'TimedOut', ...), or 'TimedOut' if it
        is still running when the timeout elapses.
        '''
        deadline = time.time() + timeout
        while True:
            try:
                resp = self.ssm.get_command_invocation(CommandId=command_id, InstanceId=instance_id)
                if resp.get('Status') not in _IN_FLIGHT:
                    return resp['Status']
            except ClientError as e:
                if e.response.get('Error', {}).get('Code', '') != 'InvocationDoesNotExist':
                    raise
            if time.time() >= deadline:
                return 'TimedOut'
            time.sleep(3)
