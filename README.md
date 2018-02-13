## Amazon Guardduty Tester

These scripts can be used as proof-of-concept to generate several Amazon GuardDuty findings. [guardduty-tester.template](https://github.com/awslabs/amazon-guardduty-tester/blob/master/guardduty-tester.template) uses AWS CloudFormation to create an isolated environment with a bastion host, a tester EC2 instance that you can ssh into, and two target EC2 instances. Then you can run [guardduty_tester.sh](https://github.com/awslabs/amazon-guardduty-tester/blob/master/guardduty_tester.sh) that starts interaction between the tester EC2 instance and the target Windows EC2 instance and the target Linux EC2 instance to simulate five types of common attacks that GuardDuty is built to detect and notify you about with generated findings. 

## Prerequisites

You must enable GuardDuty in the same account and region where you want to run the Amazon GuardDuty Tester script. For more information about enabling GuardDuty, see https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_settingup.html#guardduty_enable-gd.

You must generate a new or use an existing EC2 key pair in each region where you want to run these scripts. This EC2 keypair is used as a parameter in the guardduty-tester.template script that you use in Step 1 to create a new CloudFormation stack. For more information about generating EC2 key pairs, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html.

## Step 1

Create a new CloudFormation stack using guardduty-tester.template. For detailed directions about creating a stack, see https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stack.html.

Before you run guardduty-tester.template , modify it with values for the following parameters: Stack Name to identify your new stack, Availability Zone where you want to run the stack, and Key Pair that you can use to launch the EC2 instances. Then you can use the corresponding private key to SSH into the EC2 instances.

[guardduty-tester.template](https://github.com/awslabs/amazon-guardduty-tester/blob/master/guardduty-tester.template) takes around 10 minutes to run and complete. It creates your environment and copies guardduty_tester.sh onto your tester EC2 instance.

## Step 2

Click the checkbox next to your running CloudFormation stack created in the step above. In the displayed set of tabs, select the Output tab. Note the IP addresses assigned to the bastion host and the tester EC2 instance. You need both of these IP addresses in order to ssh into the tester EC2 instance.

Create the following entry in your ~/.ssh/config file to login to your instance through the bastion host:
</br>
Host bastion</br>
&nbsp;&nbsp;&nbsp;&nbsp;HostName {Elastic IP Address of Bastion}</br>
&nbsp;&nbsp;&nbsp;&nbsp;User ec2-user</br>
&nbsp;&nbsp;&nbsp;&nbsp;IdentityFile ~/.ssh/{your-ssh-key.pem}</br>
Host tester</br>
&nbsp;&nbsp;&nbsp;&nbsp;ForwardAgent yes</br>
&nbsp;&nbsp;&nbsp;&nbsp;HostName {Local IP Address of RedTeam Instance}</br>
&nbsp;&nbsp;&nbsp;&nbsp;User ec2-user</br>
&nbsp;&nbsp;&nbsp;&nbsp;IdentityFile ~/.ssh/{your-ssh-key.pem</br>
&nbsp;&nbsp;&nbsp;&nbsp;ProxyCommand ssh bastion nc %h %p</br>
&nbsp;&nbsp;&nbsp;&nbsp;ServerAliveInterval 240</br>
</br>
You would simply call $ ssh tester to login at that point. </br>
</br>
For more details on configuring and connecting through bastion hosts you can check out this article:
https://aws.amazon.com/blogs/security/securely-connect-to-linux-instances-running-in-a-private-amazon-vpc/
</br>
## Step 3

Once connected to the tester instance, there is a single script that you can run:
$ ./guardduty_tester.sh to initiate interaction between your tester and target EC2 instances, simulate attacks, and generate GuardDuty Findings.

## License

This library is licensed under the Apache 2.0 License. 
