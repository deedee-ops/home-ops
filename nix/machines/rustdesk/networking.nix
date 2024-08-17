{ config, lib, ... }:
{
  networking = {
    hostName = config.currentHostname;
    networkmanager.enable = true;
    enableIPv6 = false;
    useDHCP = lib.mkForce true;
    extraHosts = ''
      10.200.1.2 attic.${config.remoteDomain}
    '';
  };
}
