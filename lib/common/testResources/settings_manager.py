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
import json
import time
import boto3
import argparse
from typing import List, Callable
import tester_vars as vars

'''
SettingsManager class statefully tracks updates made to user account
during testing process and reverts any changes made to account post testing
Changes will only be made with explicit user permission and only 
if the settings must be updated in order to successfully generate 
finding(s) requested via command line arguments

Settings that can change during testing:
    - GuardDuty (must be enabled)
        - features https://docs.aws.amazon.com/guardduty/latest/ug/guardduty-features-activation-model.html
        - custom threat list
    - Password Policy
        - for Stealth:IAMUser/PasswordPolicyChange only
    - Account level Block Public Access to S3 Buckets
        - for S3 Policy findings only
'''
class SettingsManager:

    def __init__(self) -> None:
        self.test_settings = {}
        self.accnt_state = {}
        self.gd_client = boto3.client('guardduty', region_name=vars.REGION)
        self.iam_client = boto3.client('iam', region_name=vars.REGION)
        self.s3_client = boto3.client('s3', region_name=vars.REGION)
        self.s3control = boto3.client('s3control', region_name=vars.REGION)
        self.eks = boto3.client('eks', region_name=vars.REGION)
        self.input_response_map = {'yes':True, 'y':True, '':True, 'no':False, 'n':False}
    

    '''
    Save account settings state pre-tests
    '''
    def save_curr_state(self) -> None:
        print()
        print('***********************************************************************')
        print('*                                 NOTE                                *')
        print('*      All changes made to your account within the tester script      *')
        print('*            will be restored before the script exits.                *')
        print('*        No changes will be made without direct user permission       *')
        print('***********************************************************************')
    
        self.save_guardduty_state()
        self.save_pwd_policy()
        self.save_account_public_block_policy()


    '''
    Establish necessary test settings for requested finding generation
    '''
    def set_test_settings(self, args:argparse.Namespace) -> None:
        # user explicit given parameters
        self.test_settings['findings'] = args.finding
        self.test_settings['resources'] = args.test_resources
        self.test_settings['runtime'] = args.runtime[0]
        self.test_settings['tactics'] = args.tactics
        self.test_settings['log_sources'] = args.log_source

        # maintain original state to be restored if any changes are made
        self.save_curr_state()

        # set up needed settings
        self.set_up_guardduty()
        self.set_up_pwd_policy()
        self.set_up_accnt_pub_block()
                

    '''
    Reset account settings to what they were pre-test if any changes have been made for testing
    '''
    def reset_settings(self) -> None:
        print()
        print('***********************************************************************')
        print('* restoring account settings:                                         *')

        self.restore_pwd_policy()
        self.start_settings_step_function()

        print('* complete!                                                           *')
        print('***********************************************************************')
        print()
        print('-----------------------------------------------------------------------')
        print()


    '''
    Checks if password policy is needed to be changed for testing
    If it is, then explicit user permission is requested
    If it is not, then no permission is saved for check during
    settings reset stage post testing
    '''
    def save_pwd_policy(self) -> None:
        # if implicitly or explicitly Stealth:IAMUser/PasswordPolicyChanged finding type
        
        if self.test_settings['log_sources']:
            log_source_condition = True if 'cloudtrail' in self.test_settings['log_sources'] else False
        else:
            log_source_condition = True

        if ((self.test_settings['resources'] and 
            'iam' in self.test_settings['resources'] and 
            'stealth' in self.test_settings['tactics'] and
            log_source_condition) or 
            (self.test_settings['findings'] and 
            'Stealth:IAMUser/PasswordPolicyChanged' in self.test_settings['findings'])):
            
            self.test_settings['pwd_policy_permission'] = self.get_user_permission('Account Password Policy')
            if self.test_settings['pwd_policy_permission']:
                try:
                    self.accnt_state['pwd_policy'] = self.iam_client.get_account_password_policy()['PasswordPolicy']
                except: 
                    # error gets thrown if no policy has been set (i.e. aws default)
                    self.accnt_state['pwd_policy'] = None
        else:
            self.test_settings['pwd_policy_permission'] = False
        

    '''
    Checks if account public blocks policy is needed to be changed for testing
    If it is, then explicit user permission is requested and settings are saved
    If it is not, then no permission is saved for check during
    settings reset stage post testing
    '''
    def save_account_public_block_policy(self) -> None:
        # if implicitly or explicitly S3 policy finding type that needs account public block disabled
        # s3_policy = ['Policy:S3/BucketBlockPublicAccessDisabled', 'Policy:S3/BucketPublicAccessGranted', 'Policy:S3/BucketPublicAccessGranted', 'Policy:S3/BucketPublicAccessGranted' ]
        if self.test_settings['log_sources']:
            log_source_condition = True if 'cloudtrail' in self.test_settings['log_sources'] else False
        else:
            log_source_condition = True

        if ((self.test_settings['resources'] and 
            's3' in self.test_settings['resources'] and 
            'policy' in self.test_settings['tactics'] and
            log_source_condition) or 
            (self.test_settings['findings'] and 
             any('Policy:S3' in x for x in self.test_settings['findings']))):
            
            self.test_settings['account_pub_acc_permission'] = self.get_user_permission('Account wide Public Access Block for S3 Buckets - NOTE: This may impact other buckets within the account!')
            if self.test_settings['account_pub_acc_permission']:
                self.accnt_state['accnt_pub_block'] = self.s3control.get_public_access_block(AccountId=vars.ACCNT_ID)['PublicAccessBlockConfiguration']
        else:
            self.test_settings['account_pub_acc_permission'] = False


    '''
    GuardDuty must be enabled in the test region to run scripts
    If it is not the program will exit
    Otherwise permission to update the detector will be requested
    And the response will be saved 
    '''
    def save_guardduty_state(self) -> None:
        # check if GD is enabled and capture state
        detectors_ids = self.gd_client.list_detectors()['DetectorIds']

        for id in detectors_ids:
            curr = self.gd_client.get_detector(DetectorId=id)
            if curr['Status'] == 'ENABLED':
                self.accnt_state['detector_id'] = id
                self.accnt_state['detector_info'] = curr
                self.accnt_state['detector_info'].pop('ResponseMetadata')
                break

        if 'detector_id' not in self.accnt_state:
            print()
            print('***********************************************************************')
            print('* ---------------------------   ERROR    ---------------------------  *')
            print(f'*           GuardDuty is not enabled in region {vars.REGION}!            *')
            print('                 Please enable GuardDuty to run tests!                 ')
            print('* --------------------------   Warning    --------------------------  *')
            print('*           Enabling GuardDuty will begin your free trial             *')
            print('***********************************************************************')
            print()
            print('-----------------------------------------------------------------------')
            print()
            sys.exit(0)

        # request permission to update, changes may be necessary for any resource depending on current detector settings
        print()
        print('***********************************************************************')
        print('* Note on GuardDuty settings                                          *')
        print('* Depending on reqeusted tests various settings may need to modified  *')
        print('* All of which will be restored to current state post testing         *')
        print('* One exception being a custom malicious threat list, the deletion of *')
        print('* which (if exists) will be handled by a Lambda function when the     *')
        print('* tester Cloudformation stack is deleted.                             *')

        self.test_settings['guardduty_permission'] = self.get_user_permission('GuardDuty Settings')

        print('***********************************************************************')
        print()


    '''
    Helper method that requests for permission to make changes to a given setting
    '''
    def get_user_permission(self, resource: str) -> bool:
        # for spacing
        print()
        response = input(f'Allow tester to make changes to {resource}? [y/n]: ').lower()
        while True:
            if response in self.input_response_map:
                return self.input_response_map[response]
            else:
                response = input('Please respond with \'y\' or \'n\': ').lower()


    '''
    Sets up GuardDuty settings to match the requirements for the requested tests
    '''
    def set_up_guardduty(self) -> None:
        # check for eks agent config
        self.check_eks_agent()
        if not self.test_settings['guardduty_permission']:
            return

        # EBS malware findings will only be passive tests as no free tier available for manual scans
        # S3_DATA_EVENTS'|'EKS_AUDIT_LOGS'|'EKS_RUNTIME_MONITORING'|'LAMBDA_NETWORK_LOGS'|'RUNTIME_MONITORING'
        features = [
            {   # MaliciousIPCaller.Custom findings
                'resource': ['unauthorized-access', 'recon', 'discovery', 'impact', 'defense-evasion', 'persistence'],
                'setting': 'tactics',
                'substr': 'Custom',
                'log_source': ['runtime-monitoring', 'lambda', 'vpc-flowlogs'],
                'func': self.upload_custom_ti,
                'feature': ''
            },
            {   # any S3
                'resource': ['s3'],
                'setting': 'resources',
                'substr': 'S3',
                'log_source': ['s3-logs'],
                'func': self.guardduty_feature,
                'feature': 'S3_DATA_EVENTS',
            },
            {   # eks audit log findings
                'resource': ['eks'],
                'setting': 'resources',
                'substr': 'Kubernetes',
                'log_source': ['eks-audit-logs'],
                'func': self.guardduty_feature,
                'feature': 'EKS_AUDIT_LOGS',
            },
            {   # lambda findings
                'resource': ['lambda'],
                'setting': 'resources',
                'substr': 'Lambda',
                'log_source': ['lambda'],
                'func': self.guardduty_feature,
                'feature': 'LAMBDA_NETWORK_LOGS',
            },
            {   # runtime monitoring
                'resource': ['ec2', 'ecs-ec2', 'ecs-fargate', 'eks'],
                'setting': 'resources',
                'substr': 'Runtime',
                'log_source':['runtime-monitoring'],
                'func': self.guardduty_feature,
                'feature': 'RUNTIME_MONITORING',
            }
        ]

        # make updates to each feature as necessary 
        for f in features:
            self.set_up_guardduty_feature(f['resource'], f['setting'], f['substr'], f['log_source'], f['func'], f['feature'])


    '''
    Sets up strong baseline to detect weakened password policy
    '''
    def set_up_pwd_policy(self) -> None:
        if self.test_settings['pwd_policy_permission']:
            self.iam_client.update_account_password_policy(
                MinimumPasswordLength=15,
                RequireSymbols=True,
                RequireNumbers=True,
                RequireUppercaseCharacters=True,
                RequireLowercaseCharacters=True
        )


    '''
    Turn on Account Public Block so when disabled in tests finding will be generated
    '''
    def set_up_accnt_pub_block(self) -> None:
        if self.test_settings['account_pub_acc_permission']:
            self.s3control.put_public_access_block(
                AccountId=vars.ACCNT_ID,
                PublicAccessBlockConfiguration={
                    'BlockPublicAcls': True,
                    'IgnorePublicAcls': True,
                    'BlockPublicPolicy': True,
                    'RestrictPublicBuckets': True
                }   
        )



    '''
    If any of the passed options are in the user requested resources, tactics, or log_source 
    OR
    If the given substring is in user explicitly requested findings
    Then call the passed function to set up the feature
    '''
    def set_up_guardduty_feature(self, options: List, setting: str, finding_substr: str, 
                                 log_source: List, func: Callable[[dict], None], feature: str) -> None:
        if ((self.test_settings[setting] and
            any([x in options for x in self.test_settings[setting]])) or
            (self.test_settings['log_sources'] and
            any([x in log_source for x in self.test_settings['log_sources']])) or
            (self.test_settings['findings'] and
            any([finding_substr in finding for finding in self.test_settings['findings']]))):
            func(feature) # guardduty_feature or upload_custom_ti
    

    '''
    Set up the given guardduty feature
    If runtime requested and applicable to feature,
    check for necessary updates and apply as needed
    '''
    def guardduty_feature(self, feature: str) -> None:
        features = self.accnt_state['detector_info']['Features']
        if next(f for f in features if f['Name'] == feature)['Status'] != 'ENABLED':
            self.guardduty_enable(feature)

    
    '''
    Uploads custom threat list to s3 and activates list in guardduty
    '''
    def upload_custom_ti(self, args: str) -> None:
        # upload threat list to s3
        threat_list = 'tester_script_custom_threat.txt'
        ti_loc = f's3://{vars.S3_BUCKET_NAME}/{threat_list}'
        self.s3_client.upload_file(threat_list, vars.S3_BUCKET_NAME, threat_list)

        # create and activate threat intel set on guardduty
        try:
             self.gd_client.create_threat_intel_set(
                DetectorId=self.accnt_state['detector_id'],
                Name='TesterCustomThreatList',
                Format='TXT',
                Location=ti_loc,
                Activate=True
            )
        except:
            print()
            print('***********************************************************************')
            print('* Failed to create GuardDuty Threat Intel Set!                        *')
            print('* Only an administrator account can perform this operation            *')
            print('* This will also fail if a custom threat list with the name of        *')
            print('* "TesterCustomThreatList" already exists                             *')
            print('* Note: The maliciousIP.Custom findings will not be generated unless  *')
            print('* a custom threat list is uploaded                                    *')
            print('***********************************************************************')
            print()

    
    '''
    Warns that the given feature is not enabled, 
    Then prompts user for permission to enable with the caveat
    that all changes will be reversed after testing completes
    '''
    def guardduty_enable(self, feature:str, additional_config:str = '') -> None:
        config = { 'Name': feature, 'Status': 'ENABLED' }

        if additional_config:
            config['AdditionalConfiguration'] = [{'Name': additional_config, 'Status': 'ENABLED'}]

        print()
        print('***********************************************************************')
        print(f'WARNING - {feature} protection is currently disabled')
        print(f'{feature} related findings will not be generated with this configuration')
        print('*                                                                     *')
        print('* NOTE - changes made here will be reverted at the end of the tests   *')
        
        if self.get_user_permission(feature + ' protection'):
             self.gd_client.update_detector(
                DetectorId=self.accnt_state['detector_id'],
                Enable=True,
                Features=[config]
            )

        print('***********************************************************************')    


    '''
    Restores any changes made to GuardDuty detector in the test region
    If no changes have been made the function will return without
    requesting updates
    '''
    def get_restore_guardduty_state(self) -> List:
        if 'guardduty_permission' not in self.test_settings or not self.test_settings['guardduty_permission']:
            return []
        
        original_state = self.accnt_state['detector_info']
        current_state = self.gd_client.get_detector(DetectorId=self.accnt_state['detector_id'])
        current_state.pop('ResponseMetadata')

        return self.get_guardduty_changed_features(original_state, current_state)
    

    '''
    Gets the string representation of S3 Account Block Public Access settings if any change has been made
    '''
    def get_restore_accnt_pub_block(self) -> str:
        if 'accnt_pub_block' not in self.accnt_state or 'account_pub_acc_permission' not in self.test_settings:
            return ''
        return self.accnt_state['accnt_pub_block'] if self.test_settings['account_pub_acc_permission'] else ''


    '''
    Restores password policy
    If no password policy was established prior to testing
    then the aws default will be restored 
    '''
    def restore_pwd_policy(self) -> None:
        if 'pwd_policy_permission' not in self.test_settings or not self.test_settings['pwd_policy_permission']:
            return

        print('restoring password policy...')
        # revert any changes back to original state if policy exists
        if self.accnt_state['pwd_policy']:
            policy = self.accnt_state['pwd_policy']
            self.iam_client.update_account_password_policy(
                MinimumPasswordLength=policy['MinimumPasswordLength'],
                RequireSymbols=policy['RequireSymbols'],
                RequireNumbers=policy['RequireNumbers'],
                RequireUppercaseCharacters=policy['RequireUppercaseCharacters'],
                RequireLowercaseCharacters=policy['RequireLowercaseCharacters']
            )
        # if no policy existed prior to tests delete policy (sets aws default)
        else:
            self.iam_client.delete_account_password_policy()
    

    '''
    Starts the step function to restore GuardDuty and ABPA settings if any changes have been made
    The step function sleeps for 15 minutes and then restores the account back to pre-test state
    '''
    def start_settings_step_function(self) -> None:
        guardduty_settings = self.get_restore_guardduty_state()
        accnt_pub_block = self.get_restore_accnt_pub_block()

        if not guardduty_settings and not accnt_pub_block:
            return
        
        print('Starting Step Function to restore any changes made to GuardDuty')
        print('Account Block Public Access settings after allowing time for')
        print('findings to first be generated!')

        boto3.client('stepfunctions', region_name=vars.REGION).start_execution(
            stateMachineArn=vars.STEP_FUNCTION,
            input=json.dumps({
                'account_id': vars.ACCNT_ID,
                'region': vars.REGION,
                'detector_id': self.accnt_state['detector_id'],
                'guardduty_settings': guardduty_settings,
                'accnt_pub_block': accnt_pub_block
            })
        )
        
     
    '''
    Checks if GuardDuty features have changed state during testing
    returns empty list if no changes are detected and list of changes otherwise
    '''
    def get_guardduty_changed_features(self, original_state: dict, current_state: dict) -> List:
        original_features = original_state['Features']
        current_features = current_state['Features']
        changed = []

        # for each of the original features, compare against current feature of same name
        for orig_feat in original_features:
            curr_feat = next(x for x in current_features if x['Name'] == orig_feat['Name'])
            
            # if status or additional configuration status is not equal
            if orig_feat['Status'] != curr_feat['Status'] or self.additional_config_mismatch(orig_feat, curr_feat):
                # remove updated at field and save feature
                temp = orig_feat
                temp.pop('UpdatedAt')
                if 'AdditionalConfiguration' in temp:
                    for add_conf in temp['AdditionalConfiguration']:
                        add_conf.pop('UpdatedAt')
                changed.append(temp)
 
        return changed
    

    '''
    Helper method to check additional configuration status of GuardDuty settings
    of current and original features.  Returns True if mismatch between settings is found
    otherwise returns False indicating settings either don't have additional configuration
    or that the settings are identical
    '''
    def additional_config_mismatch(self, orig_feat: dict, curr_feat: dict) -> bool:
        if 'AdditionalConfiguration' in orig_feat:
            for add_conf in orig_feat['AdditionalConfiguration']:
                curr_add_conf = next(x for x in curr_feat['AdditionalConfiguration'] if x['Name'] == add_conf['Name'])
                if add_conf['Status'] != curr_add_conf['Status']:
                    return True
        else:
            return False


    '''
    Ensures that EKS GuardDuty agent is installed and running on the EKS cluster
    Agent is installed on ECS/EC2 cluster via user data per documentation:
    https://docs.aws.amazon.com/guardduty/latest/ug/managing-gdu-agent-ec2-manually.html
    and EKS agent is installed via addons as per documentation:
    https://docs.aws.amazon.com/guardduty/latest/ug/managing-gdu-agent-eks-manually.html
    If account has automated agent configuration for eks enabled, no action required
    If it does not, or if agent is in failed state, error will be thrown and addon will be
    created/replaced
    '''
    def check_eks_agent(self) -> None:
        guard_duty_agent = 'aws-guardduty-agent'
        try:
            status = self.eks.describe_addon(
                clusterName=vars.EKS_CLUSTER_NAME,
                addonName=guard_duty_agent
            )['addon']['status']

            if status == 'ACTIVE':
                return
            
            elif status in ['CREATING', 'UPDATING']:
                print('GuardDuty EKS Agent still in Creating/Updating state...')
                time.sleep(15)
                self.check_eks_agent()

            elif status in ['CREATE_FAILED', 'DELETING', 'DELETE_FAILED', 'DEGRADED', 'UPDATE_FAILED']:
                raise Exception('Unable to properly provision EKS GuardDuty Agent!')
            
        except self.eks.exceptions.ResourceNotFoundException:
            # no add on found -> create one
            self.eks.create_addon(
                clusterName=vars.EKS_CLUSTER_NAME,
                addonName=guard_duty_agent,
                resolveConflicts='OVERWRITE',
            )

            print('Deploying GuardDuty EKS Agent...')

            time.sleep(15)
            self.check_eks_agent()

        except Exception as e:
            print(e.args)
            print('NOTE: EKS Runtime Monitoring Findings will not be generated')
            response = input('Continue? [y/n]: ').lower()
            while True:
                if response in self.input_response_map:
                    if not self.input_response_map[response]: 
                        # ('n' | 'no') -> exit tester
                        # this is first setting to be checked -> nothing to restore if exiting
                        print('Exiting...')
                        sys.exit(0)
                    else:
                        return
                else:
                    response = input('Please respond with \'y\' or \'n\': ').lower()
