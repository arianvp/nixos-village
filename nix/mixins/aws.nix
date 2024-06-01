{
  services.fluent-bit = {
    settings = {
      pipeline.filters = [ { name = "aws"; match = "*"; } ];
      pipeline.outputs = [{
        name = "cloudwatch_logs";
        match = "*";
        region = "eu-central-1";
        log_group_name = "ec2-logs";
        auto_create_group = true;
        log_stream_name = "default";
        log_stream_template = "\$ec2_instance_id";
      }];
    };
  };
}