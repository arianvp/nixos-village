{
  services.fluent-bit = {
    settings = {
      pipeline.filters = [ { name = "aws"; match = "*"; } ];
      pipeline.outputs = [{
        name = "cloudwatch_logs";
        match = "*";
        log_group_name = "ec2-logs";
        auto_create_group = true;
        log_stream_name = "default";
        log_steam_template = "$${ec2_instance_id}";
      }];
    };
  };
}