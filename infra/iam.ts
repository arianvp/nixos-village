import * as aws from "@pulumi/aws-native";

export interface FederatedCondition<iss extends string> {
    StringEquals?: {
        [key in `${iss}:sub`]: string;
    }
    StringLike?: {
        [key in `${iss}:sub`]: string;
    }
}

export interface FederatedStatement<iss extends string> {
}


export interface Statement {
    Principal?: {
        Service?: string;
        AWS?: string[] | string;
        Federated?: "token.actions.githubusercontent.com";
    }
    Resource?: string[] | string;
    Effect: "Allow" | "Deny";
    Action: string[] | string;
    Condition?: {
        StringEquals?: {
            [key: string]: string;
        },
        StringLike?: {
            [key: string]: string;
        },
    };
}

export interface Document {
    Version: "2012-10-17";
    Statement: Statement[] | Statement;
}


export const newRole = (name: string, args: Omit<aws.iam.RoleArgs, "assumeRolePolicyDocument"> & { assumeRolePolicyDocument: Document }): aws.iam.Role =>
    new aws.iam.Role(name, { assumeRolePolicyDocument: JSON.stringify(args.assumeRolePolicyDocument) })


export const newPolicy = (name: string, args: Omit<aws.iam.ManagedPolicyArgs, "policyDocument"> & { policyDocument: Document }): aws.iam.ManagedPolicy =>
    new aws.iam.ManagedPolicy(name, { policyDocument: JSON.stringify(args.policyDocument) })
