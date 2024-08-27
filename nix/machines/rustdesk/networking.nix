{ config, lib, ... }:
{
  networking = {
    hostName = config.currentHostname;
    networkmanager.enable = true;
    enableIPv6 = false;
    useDHCP = lib.mkForce true;
  };
}
