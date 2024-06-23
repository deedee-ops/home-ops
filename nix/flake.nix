{
  description = "homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    arion.url = "github:hercules-ci/arion";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, arion, sops-nix, ... }@inputs:
  {
    nixosConfigurations.router = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./machines/router

        sops-nix.nixosModules.sops
      ];
    };
    nixosConfigurations.supervisor = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./machines/supervisor

        arion.nixosModules.arion
        sops-nix.nixosModules.sops
      ];
    };
  };
}
