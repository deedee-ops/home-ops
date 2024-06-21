{ config, root_domain, ... }:
{
  sops = {
    secrets = {
      "ddclient/cloudflare_token" = {};
    };
  };

  services.ddclient = {
    enable = true;
    ssl = true;
    use = "web, web=https://cloudflare.com/cdn-cgi/trace, web-skip='ip='";
    protocol = "cloudflare";
    zone = "${root_domain}";
    extraConfig = "ttl=1";
    domains = [ "homelab.${root_domain}" ];
    username = "token";
    passwordFile = config.sops.secrets."ddclient/cloudflare_token".path;
  };
}
