import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws-native";
import * as awsold from "@pulumi/aws";

import { newRole, newPolicy } from "./iam"


// PAPERCUT: EC2 API only dual-stack in eu-west-1

const region = aws.getRegionOutput();
const owner = aws.getAccountIdOutput();

const ipam = new aws.ec2.Ipam("ipam", {
    operatingRegions: [{ regionName: region.region }],
    tier: "advanced",
})

const ipamPoolIpv4 = new aws.ec2.IpamPool("ipamPoolIpv4", {
    ipamScopeId: ipam.privateDefaultScopeId,
    addressFamily: "ipv4",
    locale: region.region,
})

const ipamPoolCidrIpv4 = new aws.ec2.IpamPoolCidr("ipamPoolCidrIpv4", {
    ipamPoolId: ipamPoolIpv4.id,
    cidr: "10.0.0.0/8",
})

const vpc = new aws.ec2.Vpc("vpc", {
    ipv4IpamPoolId: ipamPoolIpv4.id,
    ipv4NetmaskLength: 16,
    enableDnsHostnames: true,
    enableDnsSupport: true,
}, {
    dependsOn: [ipamPoolCidrIpv4],
    // PAPERCUT https://github.com/pulumi/pulumi-aws-native/issues/1435
    replaceOnChanges: ["*"],
})

const ipamPoolIpv6 = new aws.ec2.IpamPool("ipamPoolIpv6", {
    ipamScopeId: ipam.publicDefaultScopeId,
    addressFamily: "ipv6",
    locale: region.region,
    awsService: "ec2",
    publicIpSource: "amazon",
})

const ipamPoolCidrIpv6 = new aws.ec2.IpamPoolCidr("ipamPoolCidrIpv6", {
    ipamPoolId: ipamPoolIpv6.id,
    netmaskLength: 52,
})

const vpcIpv6CidrBlock = new aws.ec2.VpcCidrBlock("vpcCidrBlock", {
    vpcId: vpc.id,
    ipv6IpamPoolId: ipamPoolIpv6.id,
    ipv6NetmaskLength: 56,

}, { dependsOn: [ipamPoolCidrIpv6] })

const ipamSubnetPoolIpv6 = new aws.ec2.IpamPool("ipamSubnetPoolIpv6", {
    ipamScopeId: ipam.publicDefaultScopeId,
    addressFamily: "ipv6",
    locale: region.region,
    awsService: "ec2",
    publicIpSource: "amazon",
    sourceIpamPoolId: ipamPoolIpv6.id,
    sourceResource: {
        resourceOwner: owner.accountId,
        resourceRegion: region.region,
        resourceId: vpc.id,
        resourceType: "vpc",
    }
})

const ipamSubnetPoolIpv4 = new aws.ec2.IpamPool("ipamSubnetPoolIpv4", {
    ipamScopeId: ipam.privateDefaultScopeId,
    addressFamily: "ipv4",
    locale: region.region,
    sourceIpamPoolId: ipamPoolIpv4.id,
    sourceResource: {
        resourceOwner: owner.accountId,
        resourceRegion: region.region,
        resourceId: vpc.id,
        resourceType: "vpc",
    }
})

const ipamSubnetPoolCidrIpv4 = new aws.ec2.IpamPoolCidr("ipamSubnetPoolCidrIpv4", {
    ipamPoolId: ipamSubnetPoolIpv4.id,
    cidr: vpc.cidrBlock.apply(cidr => cidr!),
})


const ipamSubnetPoolCidrIpv6 = new aws.ec2.IpamPoolCidr("ipamSubnetPoolCidrIpv6", {
    ipamPoolId: ipamSubnetPoolIpv6.id,
    cidr: vpcIpv6CidrBlock.ipv6CidrBlock.apply(cidr => cidr!),
})


// PAPERCUT: Can not tag through cloudformation
// https://github.com/aws-cloudformation/cloudformation-coverage-roadmap/issues/773
const egressOnlyInternetGateway = new aws.ec2.EgressOnlyInternetGateway("egressOnlyInternetGateway", {
    vpcId: vpc.id,
    // tags: [{ key: "Name", value: "egressOnlyInternetGateway" }],
})


const tag = new awsold.ec2.Tag("tagEgressOnlyInternetGateway", {
    resourceId: egressOnlyInternetGateway.id,
    key: "Name",
    value: "egressOnlyInternetGateway",
})

const privateRouteTable = new aws.ec2.RouteTable("privateRouteTable", {
    vpcId: vpc.id,
    tags: [{ key: "Name", value: "private" }],
})

new aws.ec2.Route("egressOnlyInternetGatewayRoute", {
    routeTableId: privateRouteTable.id,
    destinationIpv6CidrBlock: "::/0",
    egressOnlyInternetGatewayId: egressOnlyInternetGateway.id,
})

const internetGateway = new aws.ec2.InternetGateway("internetGateway", {
    tags: [{ key: "Name", value: "internetGateway" }],
})

const vpcGatewayAttachment = new aws.ec2.VpcGatewayAttachment("vpcGatewayAttachment", {
    vpcId: vpc.id,
    internetGatewayId: internetGateway.id,
})

const publicRouteTable = new aws.ec2.RouteTable("publicRouteTable", {
    vpcId: vpc.id,
    tags: [{ key: "Name", value: "public" }],
})

new aws.ec2.Route("publicRouteIpv4", {
    routeTableId: publicRouteTable.id,
    destinationCidrBlock: "0.0.0.0/0",
    gatewayId: internetGateway.id,
}, { dependsOn: [vpcGatewayAttachment] })

new aws.ec2.Route("publicRouteIpv6", {
    routeTableId: publicRouteTable.id,
    destinationIpv6CidrBlock: "::/0",
    gatewayId: internetGateway.id,
}, { dependsOn: [vpcGatewayAttachment] })

const createNatGateway = (subnetId: pulumi.Input<string>) => {

    const eip = new aws.ec2.Eip("natGatewayEip", {})

    const natGateway = new aws.ec2.NatGateway("natGateway", {
        subnetId: subnetId,
        allocationId: eip.allocationId,
        tags: [{ key: "Name", value: "natGateway" }],
    })

    new aws.ec2.Route("privateNatGatewayRoute", {
        routeTableId: privateRouteTable.id,
        destinationIpv6CidrBlock: "64:ff9b::/96",
        natGatewayId: natGateway.id,
    })

    new aws.ec2.Route("publicNatGatewayRoute", {
        routeTableId: publicRouteTable.id,
        destinationIpv6CidrBlock: "64:ff9b::/96",
        natGatewayId: natGateway.id,
    })
}



async function main() {

    const azs = await aws.getAzs({}, {});

    const ipv6PrivateSubnets = azs.azs.map((az) => {
        const subnet = new aws.ec2.Subnet(`${az}-ipv6-private`, {
            vpcId: vpc.id,
            availabilityZone: az,
            ipv6IpamPoolId: ipamSubnetPoolIpv6.id,
            ipv6NetmaskLength: 60,
            ipv6Native: true,
            enableDns64: true,
            privateDnsNameOptionsOnLaunch: {
                hostnameType: "resource-name",
                enableResourceNameDnsAaaaRecord: true,
            },
            tags: [
                { key: "Name", value: `${az}-ipv6-private` },
                { key: "AvailabilityZone", value: az },
            ]
        }, {
            dependsOn: [ipamSubnetPoolCidrIpv6],
            // PAPERCUT https://github.com/pulumi/pulumi-aws-native/issues/1435
            replaceOnChanges: ["*"],
        })
        const SubnetRouteTableAssociation = new aws.ec2.SubnetRouteTableAssociation(`${az}-ipv6-private`, {
            subnetId: subnet.id,
            routeTableId: privateRouteTable.id,
        })
        return { subnet, SubnetRouteTableAssociation }
    })

    const ipv6PublicSubnets = azs.azs.map((az) => {
        const subnet = new aws.ec2.Subnet(`${az}-ipv6-public`, {
            vpcId: vpc.id,
            availabilityZone: az,
            ipv6IpamPoolId: ipamSubnetPoolIpv6.id,
            ipv6NetmaskLength: 64,
            ipv6Native: true,
            enableDns64: true,
            privateDnsNameOptionsOnLaunch: {
                hostnameType: "resource-name",
                enableResourceNameDnsAaaaRecord: true,
            },
            tags: [
                { key: "Name", value: `${az}-ipv6-public` },
                { key: "AvailabilityZone", value: az },
            ]
        }, {
            dependsOn: [ipamSubnetPoolCidrIpv6],
            // PAPERCUT
            replaceOnChanges: ["*"],
        })
        const SubnetRouteTableAssociation = new aws.ec2.SubnetRouteTableAssociation(`${az}-ipv6-public`, {
            subnetId: subnet.id,
            routeTableId: publicRouteTable.id,
        })
        return { subnet, SubnetRouteTableAssociation }
    })

    const dualStackPublicSubnets = azs.azs.map((az) => {
        const subnet = new aws.ec2.Subnet(`${az}-dual-stack-public`, {
            vpcId: vpc.id,
            availabilityZone: az,
            ipv6IpamPoolId: ipamSubnetPoolIpv6.id,
            ipv6NetmaskLength: 64,
            ipv4IpamPoolId: ipamSubnetPoolIpv4.id,
            ipv4NetmaskLength: 20,
            privateDnsNameOptionsOnLaunch: {
                hostnameType: "resource-name",
                enableResourceNameDnsAaaaRecord: true,
                enableResourceNameDnsARecord: true,
            },
            tags: [
                { key: "Name", value: `${az}-dual-stack-public` },
                { key: "AvailabilityZone", value: az },
            ]
        }, {
            dependsOn: [ipamSubnetPoolCidrIpv6, ipamSubnetPoolCidrIpv4],
            // PAPERCUT https://github.com/pulumi/pulumi-aws-native/issues/1435
            replaceOnChanges: ["*"],
        })
        const SubnetRouteTableAssociation = new aws.ec2.SubnetRouteTableAssociation(`${az}-dual-stack-public`, {
            subnetId: subnet.id,
            routeTableId: publicRouteTable.id,
        })
        return { subnet, SubnetRouteTableAssociation }
    })

    const allowIngress = new aws.ec2.SecurityGroup("allowIngress", {
        vpcId: vpc.id,
        groupDescription: "Allow ssh and ping",
        securityGroupIngress: [
            { ipProtocol: "icmp", fromPort: 8, toPort: 0, cidrIpv6: "::/0", },
            { ipProtocol: "tcp", fromPort: 22, toPort: 22, cidrIpv6: "::/0", },

            { ipProtocol: "icmp", fromPort: 8, toPort: 0, cidrIp: "0.0.0.0/0", },
            { ipProtocol: "tcp", fromPort: 22, toPort: 22, cidrIp: "0.0.0.0/0", }

        ],
    })

    // PAPERCUT: Without a NAT Gateway, instances can not reach Amazon SSM 
    // createNatGateway(dualStackPublicSubnets[0].subnet.id)


    const targetGroup = new aws.elasticloadbalancingv2.TargetGroup("targetGroup", {
        targetType: "instance",
        ipAddressType: "ipv6",
        protocol: "HTTP",
        port: 80,
        vpcId: vpc.id,
    })

    const loadBalancerSecurityGroup = new aws.ec2.SecurityGroup("loadBalancerSecurityGroup", {
        vpcId: vpc.id,
        groupDescription: "Allow http",
        securityGroupIngress: [
            { ipProtocol: "tcp", fromPort: 80, toPort: 80, cidrIpv6: "::/0", },
            { ipProtocol: "tcp", fromPort: 80, toPort: 80, cidrIp: "0.0.0.0/0", },
            { ipProtocol: "tcp", fromPort: 443, toPort: 443, cidrIpv6: "::/0", },
            { ipProtocol: "tcp", fromPort: 443, toPort: 443, cidrIp: "0.0.0.0/0" },
        ],
    })

    /*const loadBalancer = new aws.elasticloadbalancingv2.LoadBalancer("loadBalancer", {
        ipAddressType: "dualstack",
        scheme: "internet-facing",
        securityGroups: [allowIngress.id],
        subnets: dualStackPublicSubnets.map(subnet => subnet.subnet.id),
    })

    new aws.elasticloadbalancingv2.Listener("httpListener", {
        loadBalancerArn: loadBalancer.loadBalancerArn,
        defaultActions: [{
            type: "forward",
            targetGroupArn: targetGroup.targetGroupArn,
        }],
        protocol: "HTTP",
        port: 80,
    })*/

    const role = new aws.iam.Role("web", {
        roleName: "web",
        assumeRolePolicyDocument: JSON.stringify({
            Version: "2012-10-17",
            Statement: [{
                Effect: "Allow",
                Principal: {
                    Service: "ec2.amazonaws.com",
                },
                Action: "sts:AssumeRole",
            }],
        }),
        managedPolicyArns: ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"],
    })

    const instanceProfile = new aws.iam.InstanceProfile("web", {
        instanceProfileName: "web",
        roles: role.roleName.apply(roleName => [roleName!]),
    })

    const ami = aws.ssm.getParameterOutput({
        name: "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64",
    })

    const imageId = ami.value?.apply(value => value!)
    // const imageId = "ami-00eeb8d7929eba78f"

    const launchTemplate = new aws.ec2.LaunchTemplate("web", {
        launchTemplateName: "web",
        launchTemplateData: {
            keyName: "arian@framework",
            imageId,
            // PAPERCUT: 
            // instance refresh: ValidationError: The launch template for the
            // desired configuration isn't valid. A launch template that uses an
            // SSM parameter instead of an AMI ID for ImageId is not supported
            // when a desired configuration is specified. To use this launch
            // template, you must add it to the Auto Scaling group before
            // starting an instance refresh.
            // imageId: "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64",
            // PAPERCUT: Ubuntu doesn't boot with IPv6 only subnet
            // imageId: "ami-074bcbbba36789937",
            // PAPERCUT: NixOS doesn't come up with an IP!
            // imageId: "ami-00eeb8d7929eba78f",
            instanceType: "t4g.micro",

            iamInstanceProfile: { arn: instanceProfile.arn },

            // PAPERCUT: Had to enable this to get access to IMDS in IPv6 only subnet
            metadataOptions: {
            },

            networkInterfaces: [{
                deviceIndex: 0,
                // PAPERCUT: must set this or target group will not work
                primaryIpv6: true,
                ipv6AddressCount: 1,
                // PAPERCUT: Default ipv6 prefix size is not overridable and is hardcoded to /80 whilst /64
                // would be more idiomatic for an instance
                // ipv6PrefixCount: 1,
                // ipv6PrefixCount: 1,
                // TODO: I am on public wifi that is IPv4 only and otherwise I can't SSH in huh
                groups: [allowIngress.id],
            }],
        },
    })


    // PAPERCUT: EC2 Instance Connect is not supported for IPv6
    // PAPERCUT: AWS SSM Session Manager is not supported for IPv6
    // So how do we connect to the instance? lol.

    const asg = new awsold.autoscaling.Group("asg", {
        launchTemplate: {
            id: launchTemplate.id,
            version: launchTemplate.latestVersionNumber,
        },
        minSize: 0,
        maxSize: 3,
        desiredCapacity: 0,
        vpcZoneIdentifiers: ipv6PublicSubnets.map(subnet => subnet.subnet.id),

        instanceMaintenancePolicy: {
            minHealthyPercentage: 100,
            maxHealthyPercentage: 200,
        },

        healthCheckType: "EC2",
        healthCheckGracePeriod: 30,
        defaultInstanceWarmup: 30,

        // trafficSources: [{ type: "elbv2", identifier: loadBalancer.loadBalancerArn }],

        instanceRefresh: {
            strategy: "Rolling",
            preferences: {
                // All configuration options derived from the desired
                // configuration are not available for update while the instance
                // refresh is active.
                autoRollback: true,
            },
        },
    })


    // PAPERCUT: VPC endpoint is not supported for IPv6 only subnets
    /*const vpcEndpoint = new aws.ec2.VpcEndpoint("ssm", {
        serviceName: "com.amazonaws.eu-central-1.ssm",
        vpcId: vpc.id,
        vpcEndpointType: "Interface",
        securityGroupIds: [allowIngress.id],
        subnetIds: ipv6PrivateSubnets.map(subnet => subnet.subnet.id),
    })*/

}


const bucket = new aws.s3.Bucket("vmimport", {
});

const policy = new aws.iam.ManagedPolicy("vmimport", {
    policyDocument: bucket.arn.apply(arn => JSON.stringify({
        Version: "2012-10-17",
        Statement: [{
            Effect: "Allow",
            Action: [
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:PutObject",
            ],
            Resource: [
                arn,
                `${arn}/*`,
            ],
        },
        {
            Effect: "Allow",
            Action: [
                "ec2:ModifySnapshotAttribute",
                "ec2:CopySnapshot",
                "ec2:RegisterImage",
                "ec2:Describe*",
            ],
            Resource: ["*"],
        }
        ],
    })),
})

const role = newRole("vmimport", {
    roleName: "vmimport",
    assumeRolePolicyDocument: {
        Version: "2012-10-17",
        Statement: {
            Effect: "Allow",
            Principal: {
                Service: "vmie.amazonaws.com",
            },
            Action: "sts:AssumeRole",
            Condition: {
                StringEquals: {
                    "sts:ExternalId": "vmimport",
                },
            },
        },
    },
    managedPolicyArns: [policy.policyArn],
});

const uploadRole = newRole("vmimport-upload", {
    roleName: "vmimport-upload",
    assumeRolePolicyDocument: {
        Version: "2012-10-17",
        Statement: {
            Effect: "Allow",
            Principal: {
                Federated: "token.actions.githubusercontent.com"
            },
            Action: "sts:AssumeRole",
            Condition: {
                StringEquals: {
                    "token.actions.githubusercontent.com:sub": "repo:arianvp/nixos-village:environment:images"
                },
            },
        }
    },
    managedPolicyArns: [policy.policyArn],
});





main()
