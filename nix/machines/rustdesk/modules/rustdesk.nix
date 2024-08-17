{ config, ... }:
{
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    relayIP = "relay.${config.remoteDomain}";
  };
}
