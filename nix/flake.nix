{
  description = "homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    arion.url = "github:hercules-ci/arion";
    sops-nix.url = "github:Mic92/sops-nix";
    comin = {
      url = "github:ajgon/comin/feat/git-subdirs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, arion, comin, sops-nix, ... }@inputs:
  {
    nixosConfigurations.router = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit nixpkgs-unstable; };
      modules = [
        ./machines/router

        comin.nixosModules.comin
        sops-nix.nixosModules.sops
      ];
    };
    nixosConfigurations.supervisor = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./machines/supervisor

        arion.nixosModules.arion
        comin.nixosModules.comin
        sops-nix.nixosModules.sops
      ];
    };
  };
}
