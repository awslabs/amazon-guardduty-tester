## Amazon Guardduty Tester

These scripts can be used as proof-of-concept to generate several Amazon GuardDuty findings. [guardduty-tester.template](https://github.com/awslabs/amazon-guardduty-tester/blob/master/guardduty-tester.template) uses AWS CloudFormation to create an isolated environment with a bastion host, an ECS cluster running on an EC2 instance that you can ssh into, and two target EC2 instances. Then you can run [guardduty_tester.sh](https://github.com/awslabs/amazon-guardduty-tester/blob/master/guardduty_tester.sh) that starts interaction between the tester EC2 instance and the target Windows EC2 instance and the target Linux EC2 instance to simulate five types of common attacks that GuardDuty is built to detect and notify you about with generated findings. Additionally, the template stages sample EICAR [Eicar malware samples](https://www.eicar.org/download-anti-malware-testfile/) malware files, which contain strings that will be detected as malware.  These files are intended to enable GuardDuty malware findings to be generated based on the EC2 findings that are generated from the guardduty_tester.sh script.  

## Prerequisites

You must enable GuardDuty in the same account and region where you want to run the Amazon GuardDuty Tester script. For more information about enabling GuardDuty, see https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_settingup.html#guardduty_enable-gd.

If you are looking to see findings for malware generated you need to enable the Malware Protection feature of GuardDuty.  

You must generate a new or use an existing EC2 key pair in each region where you want to run these scripts. This EC2 keypair is used as a parameter in the guardduty-tester.template script that you use in Step 1 to create a new CloudFormation stack. For more information about generating EC2 key pairs, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html.

## Step 1

Create a new CloudFormation stack using guardduty-tester.template. For detailed directions about creating a stack, see https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stack.html.

Before you run guardduty-tester.template , modify it with values for the following parameters: Stack Name to identify your new stack, Availability Zone where you want to run the stack, and Key Pair that you can use to launch the EC2 instances. Then you can use the corresponding private key to SSH into the EC2 instances.

[guardduty-tester.template](https://github.com/awslabs/amazon-guardduty-tester/blob/master/guardduty-tester.template) takes around 10 minutes to run and complete. It creates your environment and copies guardduty_tester.sh onto your tester EC2 instance.

## Step 2

Click the checkbox next to your running CloudFormation stack created in the step above. In the displayed set of tabs, select the Output tab. Copy the IP address assigned to the bastion host.

Navigate to the EC2 console and locate the EC2 instance running with the name of "RedTeam".  Copy the private IP address of the instance.   

You will need the bastion host and RedTeam EC2 instance IP addresses in order to ssh into the tester EC2 instance.

Create the following entry in your ~/.ssh/config file to login to your instance through the bastion host:</br>

```
Host bastion
    HostName {Elastic IP Address of Bastion}
    User ec2-user
    IdentityFile ~/.ssh/{your-ssh-key.pem}
Host tester
    ForwardAgent yes
    HostName {Local IP Address of RedTeam Instance}
    User ec2-user
    IdentityFile ~/.ssh/{your-ssh-key.pem
    ProxyCommand ssh -W %h:%p bastion
    ServerAliveInterval 240
```

You would simply call $ ssh tester to login at that point. </br>
</br>
For more details on configuring and connecting through bastion hosts you can check out this article:
https://aws.amazon.com/blogs/security/securely-connect-to-linux-instances-running-in-a-private-amazon-vpc/
</br>
## Step 3

Once connected to the tester instance, there is a single script that you can run:
$ ./guardduty_tester.sh to initiate interaction between your tester and target EC2 instances, simulate attacks, and generate GuardDuty Findings.


## Generated Findings
Below is a list of the GuardDuty finding types that are expected to be generated as a result of running the guardduty_tester.sh script.

* Recon:EC2/Portscan
* UnauthorizedAccess:EC2/SSHBruteForce
* CryptoCurrency:EC2/BitcoinTool.B!DNS
* Trojan:EC2/DNSDataExfiltration
* Backdoor:EC2/C&CActivity.B!DNS
* Execution:EC2/MaliciousFile
* Execution:ECS/MaliciousFile


## License

This library is licensed under the Apache 2.0 License. 
