{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options = {
    primaryUser = mkOption {
      description = "Primary user username";
      type = types.str;
      default = "";
    };

    currentHostname = mkOption {
      description = "Machine hostname";
      type = types.str;
      default = "";
    };

    allowUnfree = mkOption {
      description = "List of allowed unfree packages";
      type = types.listOf types.str;
      default = [ ];
    };

    hmImports = mkOption {
      description = "List of files to be imported to home manager config";
      type = types.listOf types.path;
      default = [ ];
    };

    remoteDomain = mkOption {
      description = "A domain, used for remote HTTPS connections, with valid SSL certificate";
      type = types.str;
      default = "rzegocki.dev";
    };

    localDomain = mkOption {
      description = "Local domain used only internally to connect to machines";
      type = types.str;
      default = "home.arpa";
    };
  };
}
