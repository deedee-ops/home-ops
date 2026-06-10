{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  isDevShell = !config.devenv.isTesting;
in
{
  packages = lib.optionals isDevShell [
    inputs.talos-pilot.packages."${pkgs.stdenv.system}".talos-pilot

    pkgs.fluxcd
    pkgs.gum
    pkgs.helmfile
    pkgs.jq
    pkgs.just
    pkgs.k9s
    pkgs.kubectl
    pkgs.kubectl-node-shell
    pkgs.kustomize
    pkgs.minijinja
    pkgs.sops
    pkgs.talosctl
    pkgs.vault
    pkgs.yamlfmt
    pkgs.yq-go
  ];

  languages = lib.optionalAttrs isDevShell {
    helm = {
      enable = true;
      lsp.enable = true;
      plugins = [ "helm-diff" ];
    };
    nix = {
      enable = true;
      lsp.enable = true;
    };
    opentofu = {
      enable = true;
      lsp.enable = true;
    };
    shell = {
      enable = true;
      lsp.enable = true;
    };
  };

  git-hooks.hooks = {
    actionlint = {
      enable = true;
      args = [
        "-config-file"
        ".forgejo/actionlint.yaml"
      ];
      files = ".forgejo/workflows/.+\.yaml";
    };
    check-json.enable = true;
    commitizen.enable = true;
    markdownlint.enable = true;
    shellcheck = {
      enable = true;
      args = [ "-x" ];
    };
    terraform-format.enable = true;
    tflint.enable = true;
    yamlfmt.enable = true;
    yamllint.enable = true;
    zizmor = {
      enable = true;
      args = [
        "-c"
        ".forgejo/zizmor.yaml"
      ];
      name = "zizmor";
      package = pkgs.zizmor;
      entry = "${pkgs.lib.getExe pkgs.zizmor}";
      files = ".forgejo/workflows/.+\.yaml";
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
    nixfmt.enable = true;

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
      extraPackages = [
        pkgs.curl
        pkgs.python3
      ];
    };
  };

  enterShell = lib.optionalString isDevShell ''
    export export SOPS_AGE_SSH_PRIVATE_KEY_FILE="$HOME/.config/sops-nix/secrets/features/home/ssh/privateKey"

    export ROOT_DIR="$(git rev-parse --show-toplevel)"
    export MINIJINJA_CONFIG_FILE="$ROOT_DIR/.minijinja.toml"

    export VAULT_ADDR=https://vault.ajgon.casa
    export $(${pkgs.lib.getExe pkgs.sops} -d scripts/vault.sops.env | xargs)

    if [ -f "$ROOT_DIR/.current-cluster" ]; then
      kc="$ROOT_DIR/talos/$(cat "$ROOT_DIR/.current-cluster")/kubeconfig"
      [ -f "$kc" ] && export KUBECONFIG=$kc
      tc="$ROOT_DIR/talos/$(cat "$ROOT_DIR/.current-cluster")/talosconfig"
      [ -f "$tc" ] && export TALOSCONFIG=$tc
      ${pkgs.lib.getExe pkgs.vault} kv get -field=TALOSCONFIG "$(cat "$ROOT_DIR/.current-cluster")/talos" > "$ROOT_DIR/talos/$(cat "$ROOT_DIR/.current-cluster")/talosconfig"
    fi

    # opentofu
    ${pkgs.lib.getExe pkgs.vault} kv get -field=TOFU_TFVARS global/opentofu > "$ROOT_DIR/opentofu/terraform.tfvars"
    export AWS_ACCESS_KEY_ID="$(${pkgs.lib.getExe pkgs.vault} kv get -field=AWS_ACCESS_KEY_ID global/opentofu)"
    export AWS_SECRET_ACCESS_KEY="$(${pkgs.lib.getExe pkgs.vault} kv get -field=AWS_SECRET_ACCESS_KEY global/opentofu)"
  '';
}
