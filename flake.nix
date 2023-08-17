{
  description = "NixOS Village AWS cloud";
  outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default = with nixpkgs.legacyPackages.x86_64-linux; mkShell {
      packages = [
        terraform
        awscli2
      ];
    };
  };
}
