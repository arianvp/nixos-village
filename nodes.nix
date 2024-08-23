{ lib, config, nodes, pkgs, ... }:
{
    nodes = {
        prometheus = {
            deployment.ssm = {
                parameters = {
                    substituters = [ "s3://mybucket" ];
                    trusted-public-keys = [ "mykey" ];
                };
                targets = [ { Name = "tag:Name"; Values = ["prometheus"]; } ]
                maxConcurrency = "50%";
                maxErrors = "50%";
            };
            services.prometheus.enable = true;
        };
    };
}