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
    script = builtins.readFile ./complete-lifecycle-action.sh;

  };
  system.stateVersion = "23.05";
}
