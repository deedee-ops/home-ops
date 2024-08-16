{ config, ... }:
{
  services = {
    wg-easy = {
      service = {
        restart = "always";
        container_name = "wg-easy";
        # by default DNS is set to adguard in docker which causes internal loopback and resolving problems
        # that's why we need to force it to actual gateway
        dns = [ "10.42.1.1" ];
        image = "ghcr.io/wg-easy/wg-easy:14";
        ports = [ "53201:53201/udp" ];
        environment = {
          LANG = "en";
          PORT = "51821";
          UI_CHART_TYPE = "2";
          UI_TRAFFIC_STATS = "true";
          WG_ALLOWED_IPS = "10.99.0.0/16, 10.100.0.0/16, 10.250.1.0/24";
          WG_DEFAULT_ADDRESS = "10.250.1.x";
          WG_DEFAULT_DNS = "10.100.1.1";
          WG_HOST = "homelab.${config.remoteDomain}";
          WG_PORT = "53201";
          TZ = "Europe/Warsaw";
        };
        volumes = [ "/data/wg-easy:/etc/wireguard" ];
        capabilities = {
          NET_ADMIN = true;
          SYS_MODULE = true;
        };
        sysctls = {
          "net.ipv4.conf.all.src_valid_mark" = 1;
          "net.ipv4.ip_forward" = 1;
        };
        labels = {
          "homepage.group" = "External";
          "homepage.name" = "WireGuard Easy";
          "homepage.icon" = "wireguard.png";
          "homepage.href" = "https://wg.${config.remoteDomain}/";
          "homepage.description" = "Wireguard Gateway";
        };
      };
    };
  };
}
