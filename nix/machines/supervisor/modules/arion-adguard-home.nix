{ config, ... }:
{
  services = {
    adguard-home = {
      service = {
        restart = "always";
        container_name = "adguard-home";
        # by default DNS is set to adguard in docker which causes internal loopback and resolving problems
        # that's why we need to force it to actual gateway
        dns = [ "10.42.1.1" ];
        image = "ghcr.io/deedee-ops/adguardhome:v0.107.52";
        ports = [
          "53:53/tcp"
          "53:53/udp"
        ];
        environment = {
          TZ = "Europe/Warsaw";
        };
        volumes = [
          "/data/adguard-home/conf:/opt/adguardhome/conf"
          "/data/adguard-home/work:/opt/adguardhome/work"
        ];
        labels = {
          "homepage.group" = "External";
          "homepage.name" = "AdguardHome";
          "homepage.icon" = "adguard-home.png";
          "homepage.href" = "https://adguard.${config.remoteDomain}/";
          "homepage.description" = "AD Blocker";
        };
      };
    };
  };
}
