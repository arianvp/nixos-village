{ pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];
  services.ssm-agent.enable = true;
  # TODO: The upstream nixos module as an .override which causes ssm-agent to always be built from source.
  # This is a bug! And  crashes t3.micro images.
  services.ssm-agent.package = pkgs.ssm-agent;
  services.nginx.enable = true;

  # TODO: Move this to a module
  # Signals to the ASG that the instance is ready to be used and can serve traffic.
  systemd.services.complete-lifecycle-action = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nginx.service" ];
    path = [ pkgs.awscli2 pkgs.curl ];
    script = ''
      function get_target_state {
        curl -sSf http://169.254.169.254/latest/meta-data/autoscaling/target-lifecycle-state
      }

      function complete_lifecycle_action {
        instance_id=$(curl -sSf http://169.254.169.254/latest/meta-data/instance-id)
        group_name=$(curl -sSf http://169.254.169.254/latest/meta-data/tags/instance/aws:autoscaling:groupName)
        region=$(curl -sSf http://169.254.169.254/latest/meta-data/placement/region)
  
        aws autoscaling complete-lifecycle-action \
          --lifecycle-hook-name launching \
          --auto-scaling-group-name $group_name \
          --lifecycle-action-result CONTINUE \
          --instance-id $instance_id \
          --region $region
      }

      function main {
          while true
          do
              target_state=$(get_target_state)
              if [ \"$target_state\" = \"InService\" ]; then
                  complete_lifecycle_action
                  break
              fi
              echo $target_state
              sleep 5
          done
      }

      main
    '';

  };
  system.stateVersion = "23.05";
}
