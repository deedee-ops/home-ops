{ ... }:
{
  services = {
    nginx-proxy-manager = {
      service = {
        restart = "always";
        container_name = "nginx-proxy-manager";
        image = "ghcr.io/deedee-ops/nginx-proxy-manager:2.11.2";
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
      };
    };
  };
}
