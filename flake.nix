{
  description = "NixOS Village AWS cloud";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

  outputs = { self, nixpkgs, nixos-generators, pre-commit-hooks }: {
    lib.forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    devShells = self.lib.forAllSystems (system: {
      default = with nixpkgs.legacyPackages.${system}; mkShell {
        packages = [
          opentofu
          awscli2
          (pulumi.withPackages (p: [ p.pulumi-language-nodejs ]))
          nodejs
        ] ++ self.checks.${system}.pre-commit-check.enabledPackages;
      };
    });
    nixosConfigurations.web = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixos-generators.nixosModules.amazon
        ./config/web.nix
      ];
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
