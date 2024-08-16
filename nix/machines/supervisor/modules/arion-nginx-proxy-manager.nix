{ config, ... }:
{
  services = {
    nginx-proxy-manager = {
      service = {
        restart = "always";
        container_name = "nginx-proxy-manager";
        # by default DNS is set to adguard in docker which causes internal loopback and resolving problems
        # that's why we need to force it to actual gateway
        dns = [ "10.42.1.1" ];
        image = "ghcr.io/deedee-ops/nginx-proxy-manager:2.11.3";
        ports = [
          "80:80"
          "443:443"
        ];
        environment = {
          DISABLE_IPV6 = "true";
          TZ = "Europe/Warsaw";
        };
        volumes = [
          "/data/nginx-proxy-manager/data:/data"
          "/data/nginx-proxy-manager/letsencrypt:/etc/letsencrypt"
        ];
        labels = {
          "homepage.group" = "External";
          "homepage.name" = "Supervisor";
          "homepage.icon" = "nginx-proxy-manager.png";
          "homepage.href" = "https://supervisor.${config.remoteDomain}/";
          "homepage.description" = "Nginx Proxy Manager for external services";
        };
      };
    };
  };
}
