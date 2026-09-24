//Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License").
//  You may not use this file except in compliance with the License.
//  A copy of the License is located at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  or in the "license" file accompanying this file. This file is distributed
//  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
//  express or implied. See the License for the specific language governing
//  permissions and limitations under the License.

import { Tags } from 'aws-cdk-lib';
import { GenericLinuxImage, Instance, SubnetType, UserData, CfnInstance } from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

import { DebianLinuxRole } from '../../access/iam/debian-role';
import { DebianSecurityGroup } from '../../access/securityGroup/debian-security-group';
import { type CfnActionLambda } from '../lambda/cfn-action-lambda';
import { type Ec2Props } from './ec2-props';

export interface DebianProps extends Ec2Props {
  amiLambda: CfnActionLambda;
  bucketName: string;
  accountId: string;
  eksCluster: string;
  tempRole: string;
}

/**
 * Defines the resources for a Debian Linux instance in GaurdDuty
 * Tester public sunet.  Debian goes in the public subnet so that it
 * has a public IP address as required by some tests
 */
export class DebianLinuxInstance extends Construct {
  public readonly ec2: Instance;
  public readonly instanceRole: DebianLinuxRole;
  public readonly sgId: string;

  constructor(scope: Construct, id: string, props: DebianProps) {
    super(scope, id);

    // IAM role that instance will assume
    this.instanceRole = new DebianLinuxRole(scope, 'Role', {
      bucketName: props.bucketName,
      accountId: props.accountId,
      region: props.region!,
      eks: props.eksCluster,
      tempRoleArn: props.tempRole,
    });

    // debian security group that defines permissible traffic
    const securityGroup = new DebianSecurityGroup(this, 'SecurityGroup', {
      vpc: props.vpc,
      ingressSgId: props.securityGroupIngress!,
    });

    this.sgId = securityGroup.sg.securityGroupId;

    this.ec2 = new Instance(this, id, {
      vpc: props.vpc,
      instanceType: props.instanceType,
      machineImage: new GenericLinuxImage(this.getDebianImage(props)),
      vpcSubnets: props.vpc.selectSubnets({ subnetType: SubnetType.PUBLIC }),
      associatePublicIpAddress: true,
      userData: this.getUserData(),
      role: this.instanceRole.role,
      securityGroup: securityGroup.sg,
      instanceName: props.instanceName,
      userDataCausesReplacement: true,
    });

    Tags.of(this.ec2).add(props.tag.key, props.tag.value);
    Tags.of(this.ec2).add(props.createdBy.key, props.createdBy.value);
  }

  /**
   * With Custom Resource Lambda query Debian Linux Image AMI for the given region
   * @param props
   * @returns map of [region] -> instance-ami
   */
  private getDebianImage(props: DebianProps): Record<string, string> {
    return {
      [props.region!]: props.amiLambda.customResourceLambda.getAtt('Id').toString(),
    };
  }

  /**
   * Defines user data for Debian Linux that installs necessary libraries for testing
   * @returns
   */
  private getUserData(): UserData {
    const homeDir = '/home/ssm-user';
    // Wait for the dpkg lock instead of failing when cloud-init or
    // unattended-upgrades happens to hold it during first boot.
    const aptOpts = '-o DPkg::Lock::Timeout=300';
    const install = `apt-get ${aptOpts} install -y`;

    const userData = UserData.forLinux();
    userData.addCommands(
      '#!/bin/bash',
      // Persist bootstrap output. The SSM agent is the only access path to this
      // host, so if bootstrap breaks there is otherwise no way to diagnose it.
      'exec > >(tee -a /var/log/gd-tester-userdata.log) 2>&1',
      'set -x',
      'export DEBIAN_FRONTEND=noninteractive',
      'export PATH=$PATH:/usr/local/bin:/usr/sbin:/root/.local/bin',

      // ---------------------------------------------------------------------
      // SSM agent first. Debian AMIs do not ship it, and the tester reaches
      // this instance exclusively through ssm send-command. Installing it up
      // front means a later failure in this script degrades the tests instead
      // of making the host unreachable (and undiagnosable).
      // ---------------------------------------------------------------------
      `apt-get ${aptOpts} update -y`,
      // wget and curl are NOT part of a base Debian image; wget is needed for
      // the agent below and curl for the AWS CLI and kubectl downloads later.
      `${install} wget curl ca-certificates`,
      'mkdir -p /tmp/ssm-install',
      'for i in 1 2 3; do wget -q -O /tmp/ssm-install/amazon-ssm-agent.deb https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb && break || sleep 15; done',
      `dpkg -i /tmp/ssm-install/amazon-ssm-agent.deb || apt-get ${aptOpts} install -f -y`,
      'systemctl enable amazon-ssm-agent',
      'systemctl start amazon-ssm-agent',
      'systemctl is-active --quiet amazon-ssm-agent && echo "SSM agent active" || echo "WARNING: SSM agent not active"',

      'mkdir -p /etc/systemd/resolved.conf.d',
      // adduser is interactive on Debian 12: bare `adduser <name>` prompts for a
      // password and for confirmation, which aborts under cloud-init (no stdin)
      // and leaves the account half-configured.
      'adduser --disabled-password --gecos "" ssm-user',
      'echo "ssm-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ssm-agent-users',
      'chmod 440 /etc/sudoers.d/ssm-agent-users',
      'systemctl restart systemd-resolved',
      // Tests run as ssm-user (interactive sessions) or root (send-command), so
      // put PATH there. The previous target, /home/debian, does not exist on
      // this AMI and the redirect failed.
      `echo 'export PATH=/root/.local/bin:/usr/sbin:${homeDir}/.local/bin:$PATH' >> ${homeDir}/.bash_profile`,
      // git and make are required below (torsocks is built from source) but were
      // absent from this list, so those steps silently no-op'd on a clean image.
      `${install} nmap hydra jq python3-pip python3 tor freerdp2-dev libssl-dev postgresql-common libpq-dev autoconf libtool automake gcc make git unzip python3-venv apache2`,
      // Ensure the most recent AWS CLI is present
      'curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"',
      'unzip awscliv2.zip',
      './aws/install',
      // Setup bruteforce test resources
      `mkdir ${homeDir}/passwords`,
      `curl -L https://raw.githubusercontent.com/awslabs/amazon-guardduty-tester/master/artifacts/password_list.txt > ${homeDir}/passwords/password_list.txt`,
      `cd ${homeDir}`,
      'cat << EOF >> users',
      'ec2-user',
      'root',
      'admin',
      'administrator',
      'ftp',
      'www',
      'nobody',
      'EOF',
      // Kubectl for EKS tests
      'curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.27.1/bin/linux/amd64/kubectl',
      'chmod +x ./kubectl',
      'mv ./kubectl /usr/local/bin/kubectl',
      // Torsocks for EKS, IAM, and S3 tests
      `mkdir ${homeDir}/install`,
      `cd ${homeDir}/install`,
      'git clone https://gitlab.torproject.org/tpo/core/torsocks.git',
      'cd torsocks',
      './autogen.sh',
      './configure',
      'make',
      'make install',
      `bash -c 'echo "ControlPort 9051" >> /etc/tor/torsocks.conf'`,
      `bash -c 'echo "CookieAuthentication 0" >> /etc/tor/torsocks.conf'`,
      `bash -c 'echo "ControlPort 9051" >> /etc/tor/torrc'`,
      `bash -c 'echo "CookieAuthentication 0" >> /etc/tor/torrc'`,
      // AWS consoler for IAM and S3 tests
      `cd ${homeDir}`,
      'python3 -m venv gd_tester_pyenv',
      'source gd_tester_pyenv/bin/activate',
      'pip3 install awscurl aws-consoler',
      'systemctl enable tor',
      'systemctl start tor',
      `chown -R ssm-user: ${homeDir}`,
      // Setup HTTPd for .Custom findings
      `sed -i 's/80/8009/g' /etc/apache2/sites-enabled/000-default.conf`,
      `sed -i 's/80/8009/g' /etc/apache2/ports.conf`,
      'systemctl enable apache2',
      'systemctl start apache2',
      // SSM agent is installed at the top of this script, before anything that
      // can fail, so there is deliberately no agent install here.
      `chown -R ssm-user: ${homeDir}`,
      'echo "gd-tester bootstrap complete"',
    );
    return userData;
  }
}
