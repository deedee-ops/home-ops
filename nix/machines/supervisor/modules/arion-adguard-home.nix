{ ... }:
{
  services = {
    adguard-home = {
      service = {
        restart = "always";
        container_name = "adguard-home";
        image = "ghcr.io/deedee-ops/adguardhome:v0.107.51";
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
      };
    };
  };
}
