{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    talhelper.url = "github:budimanjojo/talhelper";
  };
  outputs = { self, nixpkgs, talhelper, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          devShells.default = pkgs.mkShell {
            buildInputs = [
              pkgs.age
              pkgs.go-task
              pkgs.kubernetes-helm
              pkgs.jq
              pkgs.lefthook
              pkgs.opentofu
              pkgs.sops
              talhelper.packages.${system}.default
              pkgs.yq-go

              # linters
              pkgs.kubeconform
              pkgs.shellcheck
              pkgs.tflint
              pkgs.yamllint
            ];

            shellHook = ''
              sh -c 'cd opentofu && ${pkgs.opentofu}/bin/tofu init -backend-config=<(grep '^#' terraform.tfvars | sed "s@^# *@@g") -upgrade'
            '';
          };
        }
      );
}
