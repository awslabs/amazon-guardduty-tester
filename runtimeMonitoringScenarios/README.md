# GuardDuty Runtime Monitoring Test Scenarios

This repository includes three realistic scenarios to test GuardDuty Runtime Monitoring. Use the following instructions to execute the scenarios.

## PHP Webshell

This scenario deploys a PHP web application as an EKS pod and simulates exploitation of a vulnerability leading to webshell deployment. The attack simulation simulates to exploit a vulnerability to inject and deploy a PHP webshell. Then it uses the webshell to execute reconnaissance commands, download malware from CnC server and execute it and persist the malware as a cron job.

### Instructions to execute the scenario:

1. **Connect to the driver instance:**
   ```bash
   aws ssm start-session \
     --region $REGION \
     --document-name AWS-StartInteractiveCommand \
     --parameters command="cd /home/ssm-user/py_tester && bash -l" \
     --target $(aws ec2 describe-instances \
       --region $REGION \
       --filters "Name=tag:Name,Values=Driver-GuardDutyTester" \
       --query "Reservations[].Instances[?State.Name=='running'].InstanceId" \
       --output text)
   ```

2. **Change directory to runtimeScenarios/php-webshell:**
   ```bash
   cd runtimeScenarios/php-webshell
   ```

3. **Deploy the PHP web application:**
   ```bash
   ./deploy_php.sh
   ```

4. **Execute the attack:**
   ```bash
   ./attack.py
   ```

## Java Webshell

This scenario deploys a Java web application as an EKS pod and simulates exploitation of a code injection vulnerability like the well-known Log4Shell vulnerability. The attack simulates injection of remote code that executes as a Java class and establishes a reverse shell connection with a CnC server. Then it uses the reverse shell to execute reconnaissance commands, download malware from CnC server and execute it.

### Instructions to execute the scenario:

1. **Connect to the driver instance:**
   ```bash
   aws ssm start-session \
     --region $REGION \
     --document-name AWS-StartInteractiveCommand \
     --parameters command="cd /home/ssm-user/py_tester && bash -l" \
     --target $(aws ec2 describe-instances \
       --region $REGION \
       --filters "Name=tag:Name,Values=Driver-GuardDutyTester" \
       --query "Reservations[].Instances[?State.Name=='running'].InstanceId" \
       --output text)
   ```

2. **Change directory to runtimeScenarios/java-webshell:**
   ```bash
   cd runtimeScenarios/java-webshell
   ```

3. **Deploy the Java web application:**
   ```bash
   ./deploy_java.sh
   ```

4. **Execute the attack:**
   ```bash
   ./attack.py
   ```

## Hadoop Yarn Compromise

This scenario simulates an unauthenticated Hadoop Yarn endpoint. It then simulates an attacker submitting a job through the unauthenticated Yarn endpoint. The job connects to a command and control server to download and execute malware.

### Instructions to execute the scenario:

1. **Prerequisites:**
   - First make sure the [GuardDuty runtime monitoring](https://docs.aws.amazon.com/guardduty/latest/ug/runtime-monitoring-configuration.html) and [automated agent management for EC2](https://docs.aws.amazon.com/guardduty/latest/ug/manage-agent-ec2-standalone-account.html) is enabled in your account.

2. **Connect to the Ubuntu instance:**
   ```bash
   aws ssm start-session \
     --region $REGION \
     --document-name AWS-StartInteractiveCommand \
     --parameters command="cd /home/ssm-user/py_tester && bash -l" \
     --target $(aws ec2 describe-instances \
       --region $REGION \
       --filters "Name=tag:Name,Values=Ubuntu-GuardDutyTester" \
       --query "Reservations[].Instances[?State.Name=='running'].InstanceId" \
       --output text)
   ```

3. **Change directory:**
   ```bash
   cd runtimeScenarios/hadoop-yarn-job
   ```

4. **Deploy the Hadoop cluster (this with deploy a single-node cluster that is only accessible from the localhost). If you get GUI based questions during the deployment and you are unable to use your keyboard to answer them, just kill the script by pressing ctrl-c and run the deployment script again. You may have to stop and run multiple times):**
   ```bash
   ./deploy_hadoop.sh
   ```
