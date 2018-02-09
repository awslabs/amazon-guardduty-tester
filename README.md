## Amazon Guardduty Tester

This script is used to generate some basic detections of the GuardDuty service. It uses CloudFormation to create an isolated environment with a bastion host and tester instance that you can ssh into.  From there you can run a prebuilt script that will interact with a windows and linux instance to simulate several types of attacks to reliably generate 5 detections in Amazon GuardDuty. 

## Prerequisites

You will want to enable Amazon GuardDuty in the same account and region that you are going to run the Amazon GuardDuty Tester from. If you are not familiar with how to enable GuardDuty you can follow detailed directions here: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_settingup.html#guardduty_enable-gd

## Step 1

Generate a new keypair if you don't already have a keypair generated. Detailed directions for creating a keypair can be found here:
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html



## License

This library is licensed under the Apache 2.0 License. 
