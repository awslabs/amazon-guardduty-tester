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

import boto3
from aws_lambda_powertools.utilities.typing import LambdaContext

# event => {'account_id':'', 'region': '', 'guardduty_settings':[{}], 'detector_id':'', 'accnt_pub_block':''}

SUCCESS = 'Success'
FAILURE = 'Failure'

def lambda_handler(event: dict, context: LambdaContext) -> dict:
    response = {}
    
    restore_guardduty(event, response)
    restore_accnt_pub_block_settings(event, response)
    
    if not response:
        response['NoUpdates'] = SUCCESS

    return response


def restore_guardduty(event: dict, response: dict) -> None:
    guardduty_settings = event['guardduty_settings']
    if not guardduty_settings:
        return
    
    client = boto3.client('guardduty', region_name=event['region'])
    detector_id = event['detector_id']

    try:
        client.update_detector(
            DetectorId=detector_id,
            Enable=True,
            Features=guardduty_settings
        )
        response['GuardDutyRestore'] = SUCCESS
    except Exception as e:
        response['GuardDutyRestore'] = FAILURE
        response['GuardDutyError'] = e.args


def restore_accnt_pub_block_settings(event: dict, response: dict) -> None:
    accnt_pub_block_settings = event['accnt_pub_block']
    if not accnt_pub_block_settings:
        return
    
    s3control = boto3.client('s3control', region_name=event['region'])
    
    try:
        if "PublicAccessBlockDefault" in accnt_pub_block_settings:
            s3control.delete_public_access_block(
                AccountId=event['account_id']
            )
        else:
            s3control.put_public_access_block(
                AccountId=event['account_id'],
                PublicAccessBlockConfiguration=accnt_pub_block_settings
            )
        response['BlockPublicAccessRestore'] = SUCCESS
    except Exception as e:
        response['BlockPublicAccessRestore'] = FAILURE
        response['BlockPulicAccessError'] = e.args
