{
  description = "NixOS Village AWS cloud";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

  outputs = { self, nixpkgs, nixos-generators, pre-commit-hooks }: {
    lib.supportedSystems = ["aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
    lib.forAllSystems = nixpkgs.lib.genAttrs self.lib.supportedSystems;
    devShells = self.lib.forAllSystems (system: {
      default = with nixpkgs.legacyPackages.${system}; mkShell {
        packages = [
          opentofu
          awscli2
          (pulumi.withPackages (p: [ p.pulumi-language-nodejs ]))
          nodejs
          tflint
          actionlint
        ];
        shellHook = self.checks.${system}.pre-commit-check.shellHook;
      };
    });

    nixosModules.fluent-bit = ./nix/modules/fluent-bit.nix;

    nixosConfigurations.web = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./nix/configs/web.nix ];
    };

    hydraJobs.amazonImage = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      format = "amazon";
    };

    hydraJobs.amazonImages =
      nixpkgs.lib.mapAttrs
        (_: v: v.config.system.build.amazonImage)
        self.nixosConfigurations;

    checks = self.lib.forAllSystems (system: {
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          actionlint.enable = true;
          tflint.enable = true;
        };
      };
    });

  };
}
