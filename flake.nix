{
  description = "homelab";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://attic.rzegocki.dev/homelab"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "homelab:4QC5tI8xexADyKayaRCRJzZDwFx7Vt56kLz+cVkXQoo="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    arion = {
      url = "github:hercules-ci/arion";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    attic = {
      url = "github:zhaofengli/attic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    talhelper = {
      url = "github:budimanjojo/talhelper";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    {
      self,
      arion,
      attic,
      comin,
      flake-utils,
      nixpkgs,
      nixpkgs-unstable,
      pre-commit-hooks,
      sops-nix,
      talhelper,
    }@inputs:
    let
      upkgs = nixpkgs-unstable.legacyPackages.x86_64-linux;
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        checks.pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            actionlint.enable = true;
            check-json = {
              enable = true;
              excludes = [ "kubernetes/apps/external/gokapi/files/config.json" ];
            };
            markdownlint.enable = true;
            shellcheck.enable = true;
            terraform-format.enable = true;
            tflint.enable = true;
            yamllint.enable = true;

            check-case-conflicts.enable = true;
            check-shebang-scripts-are-executable.enable = true;
            mixed-line-endings.enable = true;

            egress-comment = {
              enable = true;
              entry = "./.taskfiles/Lint/egress-comment-job.sh";
            };
            yaml-json-schema = {
              enable = true;
              entry = "./.taskfiles/Lint/yaml-json-schema-job.sh";
            };

            deadnix.enable = true;
            flake-checker = {
              enable = true;
              package = upkgs.flake-checker;
            };
            statix.enable = true;
            nixfmt-rfc-style = {
              enable = true;
              excludes = [ ".direnv" ];
            };
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = self.checks.${system}.pre-commit-check.enabledPackages ++ [
            pkgs.age
            pkgs.go-task
            pkgs.kubernetes-helm
            pkgs.jq
            pkgs.lefthook
            pkgs.opentofu
            pkgs.sops
            talhelper.packages.${system}.default
            pkgs.yq-go

            # extra linters
            pkgs.kubeconform
          ];

          shellHook =
            self.checks.${system}.pre-commit-check.shellHook
            + ''
              [ ! -f opentofu/terraform.tfvars ] || sh -c 'cd opentofu && ${pkgs.opentofu}/bin/tofu init -backend-config=<(grep '^#' terraform.tfvars | sed "s@^# *@@g") -upgrade'
            '';
        };
      }
    )
    // {
      nixosConfigurations = {
        router = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs upkgs;
          };
          modules = [
            ./nix/machines/router

            comin.nixosModules.comin
            sops-nix.nixosModules.sops
          ];
        };
        supervisor = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs upkgs;
          };
          modules = [
            ./nix/machines/supervisor

            arion.nixosModules.arion
            attic.nixosModules.atticd
            comin.nixosModules.comin
            sops-nix.nixosModules.sops
          ];
        };
        rustdesk = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs upkgs;
          };
          modules = [
            ./nix/machines/rustdesk

            comin.nixosModules.comin
          ];
        };
      };
    };
}
