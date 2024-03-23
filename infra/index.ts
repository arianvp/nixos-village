import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws-native";
import * as awsold from "@pulumi/aws";
import { cidr } from "@pulumi/aws-native/cidr";

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

const privateRouteTable = new aws.ec2.RouteTable("privateRouteTable", {
    vpcId: vpc.id,
})

const egressOnlyInternetGatewayRoute = new aws.ec2.Route("egressOnlyInternetGatewayRoute", {
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
})

const internetGatewayRoute = new aws.ec2.Route("publicRoute", {
    routeTableId: publicRouteTable.id,
    destinationCidrBlock: "0.0.0.0/0",
    gatewayId: internetGateway.id,
}, { dependsOn: [vpcGatewayAttachment] })

async function main() {

    const azs = await aws.getAzs({}, {});

    const ipv6PrivateSubnets = azs.azs.map((az) => {
        const subnet = new aws.ec2.Subnet(`${az}-ipv6-private`, {
            vpcId: vpc.id,
            availabilityZone: az,
            ipv6IpamPoolId: ipamSubnetPoolIpv6.id,
            ipv6NetmaskLength: 60,
            ipv6Native: true,
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
            ipv6NetmaskLength: 60,
            ipv6Native: true,
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
            ipv6NetmaskLength: 60,
            ipv4IpamPoolId: ipamSubnetPoolIpv4.id,
            ipv4NetmaskLength: 20,
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
            { ipProtocol: "icmp", fromPort: 8, toPort: 0, cidrIpv6: "0::/0", },
            { ipProtocol: "tcp", fromPort: 22, toPort: 22, cidrIpv6: "0::/0", },

            { ipProtocol: "icmp", fromPort: 8, toPort: 0, cidrIp: "0.0.0.0/0", },
            { ipProtocol: "tcp", fromPort: 22, toPort: 22, cidrIp: "0.0.0.0/0", }

        ],
    })

    const launchTemplate = new aws.ec2.LaunchTemplate("launchTemplate", {
        launchTemplateName: "launchTemplate",
        launchTemplateData: {
            keyName: "arian@framework",
            imageId: "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-minimal-kernel-default-arm64",
            // PAPERCUT: Ubuntu doesn't boot with IPv6 only subnet
            // imageId: "ami-074bcbbba36789937",
            // PAPERCUT: NixOS doesn't come up with an IP!
            // imageId: "ami-00eeb8d7929eba78f",
            instanceType: "t4g.micro",

            // PAPERCUT: Had to enable this to get access to IMDS in IPv6 only subnet
            metadataOptions: {
                httpProtocolIpv6: "enabled",
            },

            networkInterfaces: [{
                deviceIndex: 0,
                primaryIpv6: true,
                ipv6AddressCount: 1,
                // PAPERCUT: Default ipv6 prefix size is not overridable and is hardcoded to /80 whilst /64
                // would be more idiomatic for an instance
                // ipv6PrefixCount: 1,
                ipv6PrefixCount: 1,
                // TODO: I am on public wifi that is IPv4 only and otherwise I can't SSH in huh
                associatePublicIpAddress: true,
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
        vpcZoneIdentifiers: dualStackPublicSubnets.map(subnet => subnet.subnet.id),

        instanceMaintenancePolicy: {
            minHealthyPercentage: 100,
            maxHealthyPercentage: 200,
        },

        healthCheckType: "EC2",
        healthCheckGracePeriod: 300,
        defaultInstanceWarmup: 300,

        instanceRefresh: { strategy: "Rolling" }

    })

}

main()

