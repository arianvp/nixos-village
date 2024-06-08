{inputs, config, ...}: {
  services.amazon-ssm-agent.package = inputs.nixpkgs-amazon-ssm-agent.legacyPackages.${config.nixpkgs.hostPlatform.system}.amazon-ssm-agent.override {
    overrideEtc = false;
  };
  services.fluent-bit = {
    settings = {
      pipeline.filters = [{
        name = "aws";
        match = "*";
        # Workaround for https://github.com/fluent/fluent-bit/issues/6918
        retry_interval_s = "60"; 
      }];
      pipeline.outputs = [{
        name = "cloudwatch_logs";
        match = "*";
        region = "eu-central-1";
        log_group_name = "ec2-logs";
        auto_create_group = true;
        log_stream_name = "default";
        log_stream_template = "$ec2_instance_id";
      }];
    };
  };
}
