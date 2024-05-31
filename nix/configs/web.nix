{ pkgs, modulesPath, ... }:
{
  imports = [
    ../modules/fluent-bit.nix
    ../mixins/aws.nix
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];

  services.nginx = {
    enable = true;
  };

  services.fluent-bit = {
    enable = true;
    settings.pipeline = {
      inputs = [{ name = "systemd"; }];
    };
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  system.stateVersion = "24.05";

}
