{
  description = "NixOS Village AWS cloud";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  inputs.nixpkgs-amazon-ssm-agent.url = "github:r-ryantm/nixpkgs?ref=auto-update/amazon-ssm-agent";
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

  outputs = inputs@{ self, nixpkgs, pre-commit-hooks, ... }: {
    lib.supportedSystems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
    lib.forAllSystems = nixpkgs.lib.genAttrs self.lib.supportedSystems;

    packages = self.lib.forAllSystems (system: {
      aws-codedeploy-agent = nixpkgs.legacyPackages.${system}.callPackage ./nix/packages/aws-codedeploy-agent.nix { };
    });

    devShells = self.lib.forAllSystems (system: {
      default = with nixpkgs.legacyPackages.${system}; mkShell {
        packages = [
          opentofu
          awscli2
          nodejs
          tflint
          actionlint
          shellcheck
          gh
        ];
        shellHook = self.checks.${system}.pre-commit-check.shellHook;
      };
    });

    hydraJobs = {
      web = self.nixosConfigurations.web.config.system.build.toplevel;
    };

    nixosModules.fluent-bit = ./nix/modules/fluent-bit.nix;
    nixosModules.flakeInputs = {
      _module.args.inputs = inputs;
    };

    nixosConfigurations.web = nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.hostPlatform = "aarch64-linux"; }
        self.nixosModules.flakeInputs
        ./nix/configs/web.nix
      ];
    };

    nixosConfigurations.web-push = nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.hostPlatform = "x86_64-linux"; }
        self.nixosModules.flakeInputs
        ./nix/configs/web.nix
      ];
    };

    checks = self.lib.forAllSystems (system: {
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          actionlint.enable = true;
          tflint.enable = true;
          shellcheck.enable = true;
        };
      };
    });

  };
}
