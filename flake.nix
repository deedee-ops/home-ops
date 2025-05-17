{
  description = "homelab";

  nixConfig = {
    substituters = [
      "http://10.100.10.1:9000/nix?priority=30"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "homelab:mM9UlYU+WDQSnxRfnV0gNcE+gLD/F9nkGIz97E22VeU="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    extra-substituters = [
      "https://cache.garnix.io"
      "https://deploy-rs.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "deploy-rs.cachix.org-1:xfNobmiwF/vzvK1gpfediPwpdIP0rpDV2rYqx40zdSI="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    builders-use-substitutes = true;
    connect-timeout = 5;
    warn-dirty = false;
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
      pre-commit-hooks,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [ "bws" ];
        };
      in
      {
        checks.pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            actionlint.enable = true;
            check-json.enable = true;
            commitizen.enable = true;
            markdownlint.enable = true;
            shellcheck = {
              enable = true;
              excludes = [ ".envrc" ];
              args = [ "-x" ];
            };
            terraform-format.enable = true;
            tflint.enable = true;
            yamllint.enable = true;
            zizmor = {
              enable = true;
              name = "zizmor";
              package = pkgs.zizmor;
              entry = "${pkgs.lib.getExe pkgs.zizmor}";
              files = ".github/workflows/.+\.yaml";
            };

            check-case-conflicts.enable = true;
            check-executables-have-shebangs.enable = true;
            check-merge-conflicts.enable = true;
            check-shebang-scripts-are-executable.enable = true;
            end-of-file-fixer.enable = true;
            fix-byte-order-marker.enable = true;
            mixed-line-endings.enable = true;
            trim-trailing-whitespace.enable = true;

            deadnix.enable = true;
            flake-checker.enable = true;
            nixfmt-rfc-style = {
              enable = true;
              excludes = [ ".direnv" ];
            };
            statix.enable = true;

            # custom linters
            lint-charts-for-oci = {
              enable = true;
              entry = "./scripts/lint-charts-for-oci.sh";
              args = [
                "-q"
              ];
            };
            lint-yaml-language-server = {
              enable = true;
              entry = "./scripts/lint-yaml-language-server.sh";
              args = [ "." ];
              always_run = true;
              pass_filenames = false;
            };
            popeye = {
              enable = false; # TODO: set to true when github runners migrated to k8s cluster
              package = pkgs.popeye;
              entry = "${pkgs.lib.getExe pkgs.popeye}";
              args = [
                "-l"
                "warn"
                "-A"
                "-f"
                ".spinach.yaml"
                "-o"
                "jurassic"
              ];
              always_run = true;
              pass_filenames = false;
            };
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = self.checks.${system}.pre-commit-check.enabledPackages ++ [
            pkgs.bws
            pkgs.go-task
            pkgs.helmfile
            pkgs.jq
            pkgs.k9s
            pkgs.kubectl
            pkgs.kubectl-node-shell
            pkgs.kustomize
            pkgs.minijinja
            pkgs.opentofu
            pkgs.popeye
            pkgs.talosctl
            pkgs.yq-go

            (pkgs.wrapHelm pkgs.kubernetes-helm {
              plugins = [
                pkgs.kubernetes-helmPlugins.helm-diff
              ];
            })
          ];

          shellHook =
            self.checks.${system}.pre-commit-check.shellHook
            + ''
              export ROOT_DIR="$(git rev-parse --show-toplevel)"
              source .env

              if [[ ! -e "$ROOT_DIR/.current-cluster" || ! -s "$ROOT_DIR/.current-cluster" ]]; then
                echo "MISSING '.current-cluster' file, some features may not work properly."
              else
                export CURRENT_CLUSTER="$(cat "$ROOT_DIR/.current-cluster")"
                export BWS_ACCESS_TOKEN="$(${pkgs.lib.getExe pkgs.rbw} get "BWS_ACCESS_TOKEN_''${CURRENT_CLUSTER^^}")"

                bws secret list | jq -r '.[] | select(.key == "TALCONFIG_TALOSCONFIG") | .value' > "$ROOT_DIR/talosconfig"
                bws secret list | jq -r '.[] | select(.key == "TOFU_TFVARS") | .value' > "$ROOT_DIR/opentofu/terraform.tfvars"
                export AWS_ACCESS_KEY_ID="$(bws secret list | jq -r '.[] | select(.key == "TOFU_AWS_ACCESS_KEY_ID") | .value')"
                export AWS_SECRET_ACCESS_KEY="$(bws secret list | jq -r '.[] | select(.key == "TOFU_AWS_SECRET_ACCESS_KEY") | .value')"
              fi
            '';
        };
      }
    );
}
