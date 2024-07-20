{
  description = "NixOS Village AWS cloud";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, pre-commit-hooks, nix-github-actions, ... }: {
    lib.supportedSystems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
    lib.forAllSystems = nixpkgs.lib.genAttrs self.lib.supportedSystems;

    githubActions = nix-github-actions.lib.mkGithubMatrix {
      inherit (self) checks;
      platforms = {
        x86_64-linux = [
            "nscloud-ubuntu-22.04-amd64-4x16-with-cache"
            "nscloud-cache-size-20gb"
            "nscloud-cache-tag-aarch64-linux"
        ];
        aarch64-linux = [
            "nscloud-ubuntu-22.04-arm64-4x16-with-cache"
            "nscloud-cache-size-20gb"
            "nscloud-cache-tag-x86_64-linux"
        ];
      };
    };

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
          pulumi
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
