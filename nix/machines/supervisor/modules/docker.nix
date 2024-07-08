{ config, ... }:
{
  sops = {
    secrets = {
      "dockerd/tlscacert" = {
        mode = "0440";
        owner = "root";
        group = "docker";
      };
      "dockerd/tlscert" = {
        mode = "0440";
        owner = "root";
        group = "docker";
      };
      "dockerd/tlskey" = {
        mode = "0440";
        owner = "root";
        group = "docker";
      };
    };
  };

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
      daemon.settings = {
        hosts = [ "tcp://0.0.0.0:2376" ];
        tls = true;
        tlsverify = true;
        tlscacert = config.sops.secrets."dockerd/tlscacert".path;
        tlscert = config.sops.secrets."dockerd/tlscert".path;
        tlskey = config.sops.secrets."dockerd/tlskey".path;
      };
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
  };

  users.users.ajgon.extraGroups = [ "docker" ];
}
