{
  description = "NixOS Village AWS cloud";
  inputs.nixos-generators.url = "github:nix-community/nixos-generators";
  outputs = { self, nixpkgs, nixos-generators }: {
    devShells.x86_64-linux.default = with nixpkgs.legacyPackages.x86_64-linux; mkShell {
      packages = [
        terraform
        awscli2
      ];
    };
    nixosConfigurations.webserver = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixos-generators.nixosModules.amazon
        ./config/webserver.nix
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

  };
}
