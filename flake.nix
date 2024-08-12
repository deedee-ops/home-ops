{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    talhelper.url = "github:budimanjojo/talhelper";
  };
  outputs =
    {
      self,
      nixpkgs,
      talhelper,
      flake-utils,
      pre-commit-hooks,
    }:
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
            flake-checker.enable = true;
            statix.enable = true;
            nixfmt = {
              enable = true;
              package = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
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
    );
}
