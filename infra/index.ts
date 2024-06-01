
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws-native";
import * as awsold from "@pulumi/aws";
import { cidrOutput } from "@pulumi/aws-native/cidr";
import { Input } from "@pulumi/pulumi";



// PAPERCUT: EC2 API only dual-stack in eu-west-1

const region = aws.getRegionOutput();
const owner = aws.getAccountIdOutput();

const ipam = new aws.ec2.Ipam("ipam", {
    operatingRegions: [{ regionName: region.region }],
    tier: "advanced"
})


const vpc = new aws.ec2.Vpc("vpc", {
    cidrBlock: "172.31.0.0/16",
    enableDnsHostnames: true,
    enableDnsSupport: true,
    tags: [{ key: "Name", value: "vpc" }],
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

/* ipam costs money so puting this here for referencE*/
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


const ipamSubnetPoolCidrIpv6 = new aws.ec2.IpamPoolCidr("ipamSubnetPoolCidrIpv6", {
    ipamPoolId: ipamSubnetPoolIpv6.id,
    cidr: vpcIpv6CidrBlock.ipv6CidrBlock.apply(cidr => cidr!),
})


// PAPERCUT: Can not tag through cloudformation
// https://github.com/aws-cloudformation/cloudformation-coverage-roadmap/issues/773
const egressOnlyInternetGateway = new aws.ec2.EgressOnlyInternetGateway("egressOnlyInternetGateway", {
    vpcId: vpc.id,
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

    const eip = new aws.ec2.Eip("natGatewayEip", {
        tags: [{ key: "Name", value: "natGatewayEip" }],
    })

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

const azs = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]

const privateSubnets = azs.forEach((az, i) => {
    const subnet = new aws.ec2.Subnet(`ipv6-private-${az}`, {
        vpcId: vpc.id,
        assignIpv6AddressOnCreation: true,
        ipv6IpamPoolId: ipamSubnetPoolIpv6.id,
        ipv6NetmaskLength: 60,
        ipv6Native: true,
        enableDns64: true,
        privateDnsNameOptionsOnLaunch: {
            hostnameType: "resource-name",
            enableResourceNameDnsAaaaRecord: true,
        },
        tags: [{ key: "Name", value: `ipv6-private-${az}` }]
    }, {
        dependsOn: [ipamSubnetPoolCidrIpv6]
    })
    return new aws.ec2.SubnetRouteTableAssociation(`ipv6-private-${az}`, { subnetId: subnet.id, routeTableId: privateRouteTable.id })
})

const publicSubnets = azs.forEach((az, i) => {
    const subnet = new aws.ec2.Subnet(`ipv6-public-${az}`, {
        vpcId: vpc.id,
        assignIpv6AddressOnCreation: true,
        ipv6IpamPoolId: ipamSubnetPoolIpv6.id,
        ipv6NetmaskLength: 60,
        ipv6Native: true,
        enableDns64: true,
        privateDnsNameOptionsOnLaunch: {
            hostnameType: "resource-name",
            enableResourceNameDnsAaaaRecord: true,
        },
        tags: [{ key: "Name", value: `ipv6-public-${az}` }]
    }, {
        dependsOn: [ipamSubnetPoolCidrIpv6]
    })
    return new aws.ec2.SubnetRouteTableAssociation(`ipv6-public-${az}`, { subnetId: subnet.id, routeTableId: publicRouteTable.id })
})

const subnets = [
    "172.31.0.0/20",
    "172.31.16.0/20",
    "172.31.32.0/20"
];

const dualStackSubnets = azs.map((az, i) => {
    const subnet = new aws.ec2.Subnet(`dual-stack-public-${az}`, {
        vpcId: vpc.id,
        ipv6IpamPoolId: ipamSubnetPoolIpv6.id,
        ipv6NetmaskLength: 60,
        cidrBlock: subnets[i],
        assignIpv6AddressOnCreation: true,
        mapPublicIpOnLaunch: true,
        privateDnsNameOptionsOnLaunch: {
            hostnameType: "resource-name",
            enableResourceNameDnsAaaaRecord: true,
            enableResourceNameDnsARecord: true,
        },
        tags: [{ key: "Name", value: `dual-stack-public-${az}` },]
    })

    return new aws.ec2.SubnetRouteTableAssociation(`dual-stack-public-${az}`, {
        subnetId: subnet.id,
        routeTableId: publicRouteTable.id,
    })
})


// PAPERCUT: Without a NAT Gateway, instances can not reach Amazon SSM 
// TODO: NAT Gateway Costs Money
// createNatGateway(dualStackPublicSubnets[0].subnet.id)


const targetGroup = new aws.elasticloadbalancingv2.TargetGroup("targetGroup", {
    targetType: "instance",
    ipAddressType: "ipv6",
    protocol: "HTTP",
    port: 80,
    vpcId: vpc.id,
})

// const instance = web(privateSubnets[0].subnetId)


interface EC2RoleOptions {
    name: string,
    managedPolicyArns: pulumi.Input<pulumi.Input<string>[]>
}
const ec2Role = (opts: EC2RoleOptions) => {
    const role = new aws.iam.Role(opts.name, {
        roleName: opts.name,
        assumeRolePolicyDocument: JSON.stringify({
            Version: "2012-10-17",
            Statement: [{
                Effect: "Allow",
                Principal: { Service: "ec2.amazonaws.com" },
                Action: "sts:AssumeRole",
            }],
        }),
        managedPolicyArns: opts.managedPolicyArns
    })

    const instanceProfile = new aws.iam.InstanceProfile(opts.name, {
        instanceProfileName: opts.name,
        roles: role.roleName.apply(roleName => [roleName!]),
    })

    return { role, instanceProfile }
}

const nixosAmi = awsold.ec2.getAmiOutput({
    filters: [
        { name: "name", values: ["nixos/24.05beta*"] },
        { name: "architecture", values: ["arm64"] }
    ],
    mostRecent: true,
})

const web = (subnetId: Input<string>) => {
    const securityGroup = new aws.ec2.SecurityGroup("web", {
        vpcId: vpc.id,
        groupDescription: "web",
    })

    const { instanceProfile } = ec2Role({
        name: "web",
        managedPolicyArns: [
            "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
            "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        ]
    })

    const launchTemplate = new aws.ec2.LaunchTemplate("web", {
        launchTemplateName: "web",
        launchTemplateData: {
            imageId: nixosAmi.imageId,
            instanceType: "t4g.micro",
            iamInstanceProfile: { arn: instanceProfile.arn },
            networkInterfaces: [{
                deviceIndex: 0,
                subnetId,
                ipv6AddressCount: 1,
                primaryIpv6: true,
                groups: [securityGroup.id],
            }]
        },
    })

    const instance = new aws.ec2.Instance("web", {
        launchTemplate: {
            launchTemplateName: launchTemplate.launchTemplateName.apply(name => name!),
            version: launchTemplate.latestVersionNumber,
        },
    })

    return instance
}

web(dualStackSubnets[0].subnetId)