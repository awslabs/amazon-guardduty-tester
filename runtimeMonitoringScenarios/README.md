# GuardDuty Runtime Monitoring Test Scenarios

This repository includes five realistic scenarios to test GuardDuty Runtime Monitoring. Use the following instructions to execute the scenarios.

## PHP Remote Command Execution

This scenario deploys a PHP web application as an EKS pod and simulates exploitation of a vulnerability leading to remote command execution. Unlike the PHP Webshell scenario, no webshell file is persisted. Instead, accessing the vulnerable `index.php` endpoint directly executes shell commands that run reconnaissance commands, download script malware and binary malware from a CnC server, and execute them.

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

2. **Change directory to runtimeScenarios/php-rce:**
   ```bash
   cd runtimeScenarios/php-rce
   ```

3. **Deploy the PHP web application:**
   ```bash
   ./deploy_php_rce.sh
   ```

4. **Execute the attack:**
   ```bash
   ./attack.py
   ```

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

## Runtime Custom Threat Detection Rules

GuardDuty Runtime Custom Threat Detection (CTD) rules are a set of prebuilt rules that you can optionally enable in your account. These rules target specific Mitre techniques. By enabling a custom threat rule you can get predictable alerts when the technique covered by the rule is used in the account. This scenario simulates actions to trigger and test Runtime CTD rules.

### Instructions to execute the scenario:

#### Prerequisites

- The GuardDuty tester stack is deployed and you are connected to the **driver**
  instance using SSM (see the repository root `README.md`).
- Make sure that you have enabled all Runtime CTD rules or rules you intend to
  test in GuardDuty console.
- [Runtime Monitoring](https://docs.aws.amazon.com/guardduty/latest/ug/runtime-monitoring-configuration.html)
  and automated agent management for EC2 are enabled in the account.

#### Usage

Change directory to the runtimeCustomRules folder under runtimeScenarios folder:

```bash
cd /home/ssm-user/py_tester/runtimeScenarios/runtimeCustomRules

# Run every test in the catalog
python3 ./run_test.py --all

# Run all tests of one rule (a ruleId expands to every test of that rule)
python3 ./run_test.py --custom-rule FirewallConfigModified

# Run one specific test (a testId runs just that test)
python3 ./run_test.py --custom-rule FirewallConfigModifiedUfwDefault

# Run several, mixing rule ids and test ids
python3 ./run_test.py --custom-rule FirewallConfigModified KillCommandUsage

# Force the whole run onto one OS (optional; see runtimeScenarios/runtimeCustomRules/README.md)
python3 ./run_test.py --custom-rule FirewallConfigModified --os ubuntu2204
```

`--custom-rule` and `--all` are mutually exclusive; exactly one is required. The
exit code is 0 only if at least one test ran and none failed.

#### Cleanup: terminate the CDR instances after the tests

The Amazon Linux instances that run the tests (`CDR-AL2023-GuardDutyTester-1`, `-2`, ...)
keep running, and keep costing money, until you stop them. When the tests are complete
and you have reviewed the GuardDuty findings, terminate them.

Run these from your own terminal with credentials for the account where the stack is
deployed. The driver instance is not allowed to terminate instances. `$REGION` is the
region you deployed to.

1. List the CDR instances and check that they are the ones you expect. They are found
   by the `CdrTestHost=al2023` tag, so if the account has more than one tester
   deployment in this region, this lists the instances of all of them.

   ```bash
   aws ec2 describe-instances --region $REGION \
     --filters "Name=tag:CdrTestHost,Values=al2023" \
               "Name=instance-state-name,Values=pending,running,stopping,stopped" \
     --query "Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key=='Name']|[0].Value]" \
     --output table
   ```

2. Terminate them:

   ```bash
   aws ec2 terminate-instances --region $REGION \
     --instance-ids $(aws ec2 describe-instances --region $REGION \
       --filters "Name=tag:CdrTestHost,Values=al2023" \
                 "Name=instance-state-name,Values=pending,running,stopping,stopped" \
       --query "Reservations[].Instances[].InstanceId" --output text)
   ```

3. Check that they are shutting down:

   ```bash
   aws ec2 describe-instances --region $REGION \
     --filters "Name=tag:CdrTestHost,Values=al2023" \
     --query "Reservations[].Instances[].[InstanceId,State.Name]" --output table
   ```

Notes:
- Termination cannot be undone. The tests install packages and change files on these
  hosts, so a new instance starts from a clean image.
- The instances were created by the CDK stack. After you terminate them, CloudFormation
  does not recreate them on the next `cdk deploy` unless their definition changes, and
  the stack shows them as missing. `cdk destroy` should still work. To get new hosts,
  destroy and redeploy the stack, or change the hosts' boot script so that CloudFormation
  replaces them.
- If you plan to run the tests again soon, stop the instances instead of terminating
  them. A stopped instance does not cost compute time, and it keeps its disk:

  ```bash
  # stop (use the same instance-id lookup as in step 2)
  aws ec2 stop-instances --region $REGION --instance-ids <instance-ids>

  # start again before the next run, then wait a few minutes for SSM to come online
  aws ec2 start-instances --region $REGION --instance-ids <instance-ids>
  ```
- The Ubuntu instance (`Ubuntu-GuardDutyTester`) also runs two of the tests, but the
  Hadoop scenario uses it too. It is not terminated by these commands.
- GuardDuty findings are kept after the instances are gone. Wait until the findings you
  expect have appeared before you terminate, because you cannot inspect the host
  afterwards.
