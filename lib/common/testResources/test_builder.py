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

import json
import boto3
import operator
import itertools
import subprocess
from typing import List, Union, Set
import tester_vars as vars


'''
TestBuilder class dynamically builds the tester script based on the
test settings to generate real findings requested via the user parameters
After the test script is built, it can be ran
'''
class TestBuilder:

    def __init__(self,) -> None:
        with open('definitions.json') as f:
            self.tests = Tests(json.load(f)['definitions'])

    
    '''
    Builds the test script text based on user provided parameters
    Filters the all test definitions down to match requested tests
    Filters on resource, tactic, then finding type. Based on 
    provided permission, some tests may be removed
    Once filtering has been completed the text of the script
    is built from the paths of given test definitions
    '''
    def build_testing_script(self, test_settings: dict) -> None:
        # trim off tests that do not match given parameters
        self.tests.select_where('resource', 'in', test_settings['resources'])
        self.tests.select_where('tactic', 'in', test_settings['tactics'])
        self.tests.select_where('findingType', 'in', test_settings['findings'])
        self.tests.select_where('logSource', 'in', test_settings['log_sources'])

        if test_settings['runtime'] == 'false':
            self.tests.select_where('findingType', 'does not contain', 'Runtime')
        elif test_settings['runtime'] == 'only':
            self.tests.select_where('findingType', 'contains', 'Runtime')

        if not test_settings['pwd_policy_permission']:
            self.tests.select_where('findingType', '!=', 'Stealth:IAMUser/PasswordPolicyChanged')

        if not test_settings['account_pub_acc_permission']:
            self.tests.select_where('findingType', 'does not contain', 'Policy:S3')
        
        self.tests.disambiguate()

    
    '''
    Runs the dynamically built test script as subprocess
    '''
    def run_test_script(self) -> None:
        final_script = self.tests.host_script + self.tests.script_end
        self.tests.write_file('test.sh', final_script)
        self.tests.run_ecs_tasks()
        subprocess.run('bash test.sh && rm test.sh', shell=True)



'''
Tests class provides simple wrapper to query the test definitions to build specified tests script
'''
class Tests:
    def __init__(self, defn: List[dict]) -> None:
        self.definitions = defn

        self.script_header = self.initialize_script()
        self.host_script = self.script_header
        self.kali_script = ''
        with open('script_tail.sh') as f:
            self.script_end = f.read()
        
        self.ops = {
            '==':operator.eq,
            '!=':operator.ne,
            'in':operator.contains,
            'contains':self.contains,
            'does not contain':self.does_not_contain
        }

        self.ecs = boto3.client('ecs', region_name=vars.REGION)
        self.task_defs = []


    '''
    Given an attribute (key in test definition), operator (==,!=, in, 'does not contain'), and value
    Save the test definitions that match the requirements of the query to self.definitions
    In the case that no value is given (ex, no resource, tactic, or finding), do nothing and return
    '''
    def select_where(self, attribute: str, op: str, value: Union[str, List[str]]) -> None:
        if not value:
            return
        
        temp = [d for d in self.definitions if self.ops[op](value, d[attribute])]
        self.definitions = temp

    
    '''
    Callable function that checks if substring does not exist in base string saved in self.ops
    '''
    def does_not_contain(self, substr: str, base_str: str) -> bool:
        return substr not in base_str
    
    '''
    Callable function that checks if substring exists in base string saved in self.ops
    '''
    def contains(self, substr: str, base_str: str) -> bool:
        return substr in base_str
    
    '''
    Separates scripts that are to be run locally vs on remote resource
    For some non runtime -> run on kali
    For ECS/EKS runtime run on cluster containers
    For TI based findings, insert the indicator into the respective local/remote scripts
    For all, insert description and expected findings in host script to be printed to users terminal
    '''
    def disambiguate(self) -> None:
        self.definitions.sort(key=operator.itemgetter('resource'))
        split_by_resource = itertools.groupby(self.definitions, key=operator.itemgetter('resource'))

        # iterate over resources and write separate scripts per execution space (EC2 host, EKS pod, ECS container, and Kali host)
        for resource, definitions in split_by_resource:
            remote_script = ''

            for d in definitions:
                self.host_script += d['description'] + '\n'
                self.host_script += f"EXPECTED_FINDINGS+=({d['expectedFinding']})\n((TEST_NUM++))\n"
                
                temp_script = ''

                # include domain/ip + port required for the test
                if 'indicator' in d:
                    indicator = d['indicator'] if d['indicator'] else '$MALICIOUS_IP'

                    if 'port' in d:
                        indicator += f":{d['port']}"

                    temp_script = f"INDICATOR=\"{indicator}\"\n"
                
                # DNS and UDP DOS tests use port but not indicator
                elif 'port' in d:
                    temp_script = f"PORT={d['port']}\n"
                
                with open(f"scenarios/{d['alias']}") as f:
                    temp_script += f.read() + '\n'
                
                # scripts that are marked as "local" run on ECS host
                if d['local'] == 'true':
                    self.host_script += temp_script

                # write all non runtime remote scripts to kali script
                elif 'Runtime' not in d['findingType']:
                    if not self.kali_script:
                        self.kali_script = self.script_header
                    self.kali_script += temp_script
                    
                # else it is runtime and remote -> ECS task or EKS pod
                else:
                    remote_script += temp_script

            if remote_script:
                self.write_file(f'{resource}.sh', self.script_header + remote_script)
                if 'ecs' in resource:
                    self.upload_file(resource)
                    self.build_ecs_task(resource)
        
        if self.kali_script:
            self.write_file('ec2.sh', self.kali_script)
            self.upload_file('ec2')

    '''
    Simple helper method to upload remote script file to s3 for remote execution
    '''
    def upload_file(self, resource: str) -> None:
        boto3.client('s3', region_name=vars.REGION).upload_file(f'{resource}.sh', vars.S3_BUCKET_NAME, f'remote/{resource}.sh')

    '''
    Builds the task definition for the given ecs launch type and commands to run
    '''
    def build_ecs_task(self, resource: str) -> None:

        is_ec2 = True if 'ec2' in resource else False

        kernel_capabilites = ['SYS_PTRACE']
        if is_ec2:
            kernel_capabilites.append('SYS_ADMIN')

        task_commands = ';'.join([
            'sleep 30',
            'apt update -y',
            'apt install python3 gcc netcat-openbsd g++ sudo zip -y',
            'curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install',
            "echo -n 'X5O!P%@AP[4\\PZX54(P^)7CC)7}\\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\\$H+H*' >/tmp/eicar.com && cp /tmp/eicar.com /tmp/eicar.com.txt && zip -j /tmp/eicar_com.zip /tmp/eicar.com && zip -j /tmp/eicarcom2.zip /tmp/eicar_com.zip",
            f'aws s3 cp s3://{vars.S3_BUCKET_NAME}/remote/{resource}.sh . && bash {resource}.sh', 
            'echo "done!"'
            'sleep 60',
        ])

        self.task_defs.append(self.ecs.register_task_definition(
            family=vars.EC2_TASK_FAM if is_ec2 else vars.FARGATE_TASK_FAM,
            taskRoleArn=vars.TASK_ROLE_ARN,
            executionRoleArn=vars.TASK_EXEC_ROLE_ARN,
            networkMode='awsvpc',
            requiresCompatibilities=['EC2'] if is_ec2 else ['FARGATE'],
            cpu='256' if is_ec2 else '1 vCPU',
            memory='512' if is_ec2 else '2 GB',
            containerDefinitions=[{
                'name':vars.CONTAINER,
                'image':'public.ecr.aws/ecs-sample-image/amazon-ecs-sample:latest',
                'privileged':is_ec2,
                'linuxParameters':{
                    'capabilities': {
                        'add': kernel_capabilites
                    }
                },
                'entryPoint': ['sh', '-c'],
                'command':[task_commands],
                'logConfiguration': {
                    'logDriver': 'awslogs',
                    'options': {
                        'awslogs-create-group': 'true',
                        'awslogs-group': 'GuardDuty-Tester-Ecs-Task-Logs',
                        'awslogs-region': vars.REGION,
                        'awslogs-stream-prefix': 'app'
                    }
                },
            }],
        )['taskDefinition']['taskDefinitionArn'])


    '''
    Runs the tasks that have been registered for the user specified tests
    '''
    def run_ecs_tasks(self) -> None:
        for task in self.task_defs:
            is_ec2 = 'ec2' in task.lower()
            self.ecs.run_task(
                cluster=vars.CLUSTER,
                taskDefinition=task,
                launchType='EC2' if is_ec2 else 'FARGATE',
                count=1,
                networkConfiguration={
                    'awsvpcConfiguration': {
                        'subnets': vars.SUBNETS,
                        'securityGroups': vars.SEC_GROUP,
                        'assignPublicIp': 'DISABLED' if is_ec2 else 'ENABLED'
                    }
                }
            )

    '''
    Helper method to write to a file
    '''
    def write_file(self, path:str, text:str) -> None:
        with open(path, 'w') as f:
            f.write(text)

    '''
    Insert shebang and script variables at the start of the script text
    '''
    def initialize_script(self) -> str:
        return f'#!bin/bash\n\n{self.insert_script_vars()}\n\n' 

    '''
    Saves the variables to the script to be used by tests as needed
    '''
    def insert_script_vars(self) -> str:
        script_vars = [
            f'ACCNT_ID=\'{vars.ACCNT_ID}\'',
            f'LINUX_IP=\'{vars.LINUX_IP}\'',
            f'WINDOWS_IP=\'{vars.WINDOWS_IP}\'',
            f'RED_TEAM_INSTANCE=\'{vars.RED_TEAM_INSTANCE}\'',
            f'RED_TEAM_IP=\'{vars.RED_TEAM_IP}\'',
            f'LINUX_INSTANCE=\'{vars.LINUX_INSTANCE}\'',
            f'WINDOWS_INSTANCE=\'{vars.WINDOWS_INSTANCE}\'',
            f'S3_BUCKET_NAME=\'{vars.S3_BUCKET_NAME}\'',
            f'EMPTY_BUCKET_NAME=\'{vars.EMPTY_BUCKET_NAME}\'',
            f'TEMP_ROLE_ARN=\'{vars.TEMP_ROLE_ARN}\'',
            f'REGION=\'{vars.REGION}\'',
            f'CLOUD_TRAIL_NAME=\'{vars.CLOUD_TRAIL_NAME}\'',
            f'ROLE_NAME=\'{vars.ROLE_NAME}\'',
            f'MALICIOUS_IP=\'{vars.MALICIOUS_IP}\'',
            f'LAMBDA_NAME=\'{vars.LAMBDA_NAME}\'',
            f'EKS_CLUSTER_NAME=\'{vars.EKS_CLUSTER_NAME}\'',
            'TEST_NUM=1',
            'EXPECTED_FINDINGS=()',
        ]

        return '\n'.join(script_vars)
            