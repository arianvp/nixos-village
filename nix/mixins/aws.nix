{ inputs, lib, config, ... }: {

  # TODO: upstream
  options.services.amazon-ssm-agent.cloudWatchLogGroup = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = "amazon-ssm-agent";
    description = "The name of the CloudWatch log group to send amazon-ssm-agent logs to";
  };

  config = {

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


    environment.etc."amazon/ssm/seelog.xml".text = lib.mkForce ''
      <!--amazon-ssm-agent uses seelog logging -->
      <!--Seelog has github wiki pages, which contain detailed how-tos references: https://github.com/cihub/seelog/wiki -->
      <!--Seelog examples can be found here: https://github.com/cihub/seelog-examples -->
      <seelog type="adaptive" mininterval="2000000" maxinterval="100000000" critmsgcount="500" minlevel="info">
          <exceptions>
              <exception filepattern="test*" minlevel="error"/>
          </exceptions>
          <outputs formatid="fmtinfo">
              <console formatid="fmtinfo"/>
              <rollingfile type="size" filename="/var/log/amazon/ssm/amazon-ssm-agent.log" maxsize="30000000" maxrolls="5"/>
              <filter levels="error,critical" formatid="fmterror">
                  <rollingfile type="size" filename="/var/log/amazon/ssm/errors.log" maxsize="10000000" maxrolls="5"/>
              </filter>
              ${lib.optionalString (config.services.amazon-ssm-agent.cloudWatchLogGroup != null) ''<custom name="cloudwatch_receiver" formatid="fmtdebug" data-log-group="${config.services.amazon-ssm-agent.cloudWatchLogGroup}"/>''}
          </outputs>
          <formats>
              <format id="fmterror" format="%Date %Time %LEVEL [%FuncShort @ %File.%Line] %Msg%n"/>
              <format id="fmtdebug" format="%Date %Time %LEVEL [%FuncShort @ %File.%Line] %Msg%n"/>
              <format id="fmtinfo" format="%Date %Time %LEVEL %Msg%n"/>
          </formats>
      </seelog>
    '';
  };
}
