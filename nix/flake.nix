{
  description = "homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, sops-nix, ... }@inputs:
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

        sops-nix.nixosModules.sops
      ];
    };
  };
}
