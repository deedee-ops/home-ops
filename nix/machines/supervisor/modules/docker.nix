{ ... }:
{
  virtualisation = {
    arion = {
      backend = "docker";
      projects = {
        supervisor = {
          settings = {
            imports = [
              ./arion-adguard-home.nix
              ./arion-nginx-proxy-manager.nix
              ./arion-omada-controller.nix
            ];
          };
        };
      };
    };
    docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
  };

  users.users.ajgon.extraGroups = [ "docker" ];
}
