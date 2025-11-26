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

import { Tag, Fn } from 'aws-cdk-lib';
import { CfnLaunchTemplate, type Vpc, type SecurityGroup } from 'aws-cdk-lib/aws-ec2';
import { Cluster, EndpointAccess, KubernetesVersion, NodegroupAmiType } from 'aws-cdk-lib/aws-eks';
import { type Role } from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

import { EksSecurityGroup } from '../../access/securityGroup/eks-security-group';

export interface EksProps {
  vpc: Vpc;
  masterRole: Role;
  kubectlRole: Role;
  name: string;
  instanceName: string;
  tag: Tag;
  createdBy: Tag;
  ecsSecurityGroup?: SecurityGroup;
}

/**
 * EKS cluster for EKS audit logs and runtime testing
 */
export class TesterEksCluster extends Construct {
  public readonly eks: Cluster;
  constructor(scope: Construct, id: string, props: EksProps) {
    super(scope, id);

    const eksSecurityGroup = new EksSecurityGroup(this, 'SecurityGroup', {
      vpc: props.vpc,
      ecsSecurityGroup: props.ecsSecurityGroup,
    });

    this.eks = new Cluster(this, id, {
      version: KubernetesVersion.of('1.29'),
      defaultCapacity: 0,
      vpc: props.vpc,
      securityGroup: eksSecurityGroup.sg,
      mastersRole: props.masterRole, // ecs cluster iam role as eks cluster master role for testing
      clusterName: props.name,
      endpointAccess: EndpointAccess.PUBLIC, // required for custom malicious ip caller findings
    });

    // allow Debian instance to make changes for testing
    this.eks.awsAuth.addRoleMapping(props.kubectlRole, {
      groups: ['system:masters'],
    });

    const nodeLaunchTemplate = new CfnLaunchTemplate(this, 'LaunchTemplate', {
      launchTemplateData: {
        instanceType: 't3.medium',
        securityGroupIds: [eksSecurityGroup.sg.securityGroupId],
        tagSpecifications: [
          {
            resourceType: 'instance',
            tags: [
              {
                key: 'Name',
                value: props.instanceName,
              },
              {
                key: props.tag.key,
                value: props.tag.value,
              },
              {
                key: props.createdBy.key,
                value: props.createdBy.value,
              },
            ],
          },
        ],
      },
    });

    const nodegroup = this.eks.addNodegroupCapacity('guardduty-tester-nodegroup', {
      launchTemplateSpec: {
        id: nodeLaunchTemplate.ref,
        version: nodeLaunchTemplate.attrLatestVersionNumber,
      },
      minSize: 1,
      maxSize: 1,
      amiType: NodegroupAmiType.AL2_X86_64,
    });

  }
}
