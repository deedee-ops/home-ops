{ config, ... }:
{
  sops = {
    secrets = {
      "dockerd/tlscacert" = {
        mode = "0440";
        owner = "root";
        group = "docker";
        restartUnits = [ "docker.service" ];
      };
      "dockerd/tlscert" = {
        mode = "0440";
        owner = "root";
        group = "docker";
        restartUnits = [ "docker.service" ];
      };
      "dockerd/tlskey" = {
        mode = "0440";
        owner = "root";
        group = "docker";
        restartUnits = [ "docker.service" ];
      };
      "postgresql/password" = {
        restartUnits = [
          "docker.service"
          "atticd.service"
        ];
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
              (import ./arion-adguard-home.nix { inherit config; })
              (import ./arion-nginx-proxy-manager.nix { inherit config; })
              (import ./arion-omada-controller.nix { inherit config; })
              (import ./arion-postgresql.nix { inherit config; })
              (import ./arion-wg-easy.nix { inherit config; })
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

  users.users."${config.primaryUser}".extraGroups = [ "docker" ];
}
