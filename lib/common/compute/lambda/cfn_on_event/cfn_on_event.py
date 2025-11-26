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
import json
import http.client
import urllib.parse

def send_cfn_response(event, context, response_status, response_data, physical_resource_id=None):
    response_body = {
        'Status': response_status,
        'Reason': f'See details in CloudWatch Log Stream: {context.log_stream_name}',
        'PhysicalResourceId': physical_resource_id or context.log_stream_name,
        'StackId': event['StackId'],
        'RequestId': event['RequestId'],
        'LogicalResourceId': event['LogicalResourceId'],
        'NoEcho': False,
        'Data': response_data
    }
    
    response_url = urllib.parse.urlparse(event['ResponseURL'])
    json_response_body = json.dumps(response_body)
    
    headers = {
        'content-type': 'application/json',
        'content-length': str(len(json_response_body))
    }
    
    connection = None
    try:
        connection = http.client.HTTPSConnection(response_url.netloc)
        connection.request('PUT', response_url.path + '?' + response_url.query,
                        json_response_body,
                        headers)
        response = connection.getresponse()
        print(f"Status code: {response.status}")
    except Exception as e:
        print(f"send_cfn_response failed: {e}")
    finally:
        if connection:
            connection.close()


def on_event(event: dict, context) -> None:
    request_type = event['RequestType']
    response_data = {}
    response_status = 'SUCCESS'
    
    try:
        if request_type == 'Create':
            # on create grab latest debian linux ami for the given region for RedTeam EC2 instance
            region = event['ResourceProperties']['region']
            response_data['Id'] = get_ami_info(region)
            
        elif request_type == 'Update':
            # immediately send success message on update
            response_data['Message'] = 'Resource update successful!'
            
        elif request_type == 'Delete':
            # remove custom threat list and clean out generated s3 bucket so cloudformation can delete it
            s3_bucket_name = event['ResourceProperties']['s3BucketName']
            region = event['ResourceProperties']['region']
            delete_custom_threat_list(s3_bucket_name, region)
            clean_ecr(event['ResourceProperties']['ecrRepoName'], region)
            response_data['Message'] = 'Resource deletion successful!'
            
    except Exception as e:
        response_data['Message'] = str(e)
        response_status = 'FAILED'
    
    send_cfn_response(event, context, response_status, response_data)


def delete_custom_threat_list(s3_bucket_name: str, region: str) -> None:
    guard_duty = boto3.client('guardduty', region_name=region)
    detector_ids = guard_duty.list_detectors()['DetectorIds']
    det_id = ''

    #get detector
    for id in detector_ids:
        detector = guard_duty.get_detector(DetectorId=id)
        if detector['Status'] == 'ENABLED':
            det_id = id
            break

    #get threat intel sets
    threat_sets = guard_duty.list_threat_intel_sets(DetectorId=det_id)['ThreatIntelSetIds']
    for id in threat_sets:
        curr_set = guard_duty.get_threat_intel_set(DetectorId=det_id, ThreatIntelSetId=id)
        #delete the custom threat intel set for tester script
        if curr_set['Name'] == 'TesterCustomThreatList' and s3_bucket_name in curr_set['Location']:
            guard_duty.delete_threat_intel_set(DetectorId=det_id, ThreatIntelSetId=id)
            break


def clean_ecr(repository_name: str, region: str) -> None:
    try:
        boto3.client('ecr', region).delete_repository(repositoryName=repository_name, force=True)
    except Exception as e:
        if 'RepositoryNotFoundException' in str(e.args):
            return
        else:
            raise e


def get_ami_info(region: str) -> str:
    ec2 = boto3.client('ec2', region_name=region)
    filters = [
        {
            'Name': 'architecture',
            'Values': ['x86_64']
        },
        {
            'Name': 'virtualization-type',
            'Values': ['hvm']
        },
        {
            'Name': 'root-device-type',
            'Values': ['ebs']
        },
        {
            'Name': 'ena-support',
            'Values': ['true']
        }
    ]

    images = ec2.describe_images(Filters=filters, Owners=['amazon'])['Images']
    debian_images = [x for x in images if 'debian-12-amd64' in x['Name'] and 'gui' not in x['Name']]

    # Get the max (most recent) image by name. The names contain the AMI version, formatted as ...-YYYYMMDD-Ver.
    # ex. debian-12-amd64-20240717-1811
    newest_image = max(debian_images, key=lambda x: x['Name'])
    return newest_image['ImageId']
