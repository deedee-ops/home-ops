{ config, ... }:
{
  sops = {
    secrets = {
      "ddclient/cloudflare_token" = {
        restartUnits = [ "ddclient.service" ];
      };
    };
  };

  services.ddclient = {
    enable = true;
    ssl = true;
    use = "web, web=https://cloudflare.com/cdn-cgi/trace, web-skip='ip='";
    protocol = "cloudflare";
    zone = "${config.remoteDomain}";
    extraConfig = "ttl=1";
    domains = [ "homelab.${config.remoteDomain}" ];
    username = "token";
    passwordFile = config.sops.secrets."ddclient/cloudflare_token".path;
  };
}
