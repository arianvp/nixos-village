{
  description = "NixOS Village AWS cloud";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-generators }: {
    devShells.x86_64-linux.default = with nixpkgs.legacyPackages.x86_64-linux; mkShell {
      packages = [
        opentofu
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
