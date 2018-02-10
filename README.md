## Amazon Guardduty Tester

This script is used to generate some basic detections of the GuardDuty service. It uses CloudFormation to create an isolated environment with a bastion host and tester instance that you can ssh into.  From there you can run a prebuilt script that will interact with a windows and linux instance to simulate several types of attacks to reliably generate 5 detections in Amazon GuardDuty. 

## Prerequisites

You will want to enable Amazon GuardDuty in the same account and region that you are going to run the Amazon GuardDuty Tester from. If you are not familiar with how to enable GuardDuty you can follow detailed directions here: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_settingup.html#guardduty_enable-gd

Generate a new keypair if you don't already have a keypair generated in each region that you run the tester in. You will need a keypair before running the CloudFormation template in step 1 so you can provide it as a parameter. Detailed directions for creating a keypair can be found here:
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html

## Step 1

Create a new CloudFormation stack using the guardduty-tester.template.  Detailed directions from loading a template from a local file can be found here: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stack.html

You will want to fill in the black parameters: Stack Name, Availability Zone, and Key Pair.  Stack name is an arbitrary name to identify the new stack, and you should then select one Availability Zone to run the stack.  The Key Pair will be used when launching the EC2 instances so you can use the corresponding private key to SSH into the reference.

The reference will take about 10 minutes to run and complete.

## Step 2

If you click on the checkbox next to your running CloudFormation stack, you should see a set of tabs in the window pane. If you select the output tab you should see the IP addresses assigned to the bastion host and the tester instance.  You will need both of those IPs in order to ssh into the hosts.

From a Mac - you can create the following entry in your ~/.ssh/config file to login through the bastion:

Host bastion
       HostName {Elastic IP Address of Bastion}
       User ec2-user
       IdentityFile ~/.ssh/{your-ssh-key.pem}
   Host tester
       ForwardAgent yes
       HostName {Local IP Address of RedTeam Instance}
       User ec2-user
       IdentityFile ~/.ssh/{your-ssh-key.pem
       ProxyCommand ssh bastion nc %h %p
       ServerAliveInterval 240
       
You would simply call $ ssh tester to login at that point. 

For more details on configuring and connecting through bastion hosts you can check out this article:
https://aws.amazon.com/blogs/security/securely-connect-to-linux-instances-running-in-a-private-amazon-vpc/

## Step 3

Once connected to the tester instance, there is a single script that you can run:
$ ./threat-generator.sh

## License

This library is licensed under the Apache 2.0 License. 
