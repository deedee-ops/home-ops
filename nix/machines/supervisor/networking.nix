{ config, pkgs, lib, ... }:
{
  networking = {
    hostName = "supervisor";
    networkmanager.enable = true;
    enableIPv6 = false;

    # nixos firewall adds unnecessary mess
    firewall.enable = false;

    # when arion restarts, it brings all current containers down, before pulling new ones
    # this means, adguard is down, which is a dns for supervisor, and new containers
    # cannot be pulled
    # to fix that, force dns to actual router
    nameservers = [ "10.42.1.1" ];
  };

  # generate an immutable /etc/resolv.conf from the nameserver settings
  # above (otherwise DHCP overwrites it):
  environment.etc."resolv.conf" = {
    source = pkgs.writeText "resolv.conf" ''
      search home.arpa
      ${lib.concatStringsSep "\n" (map (ns: "nameserver ${ns}") config.networking.nameservers)}
      options edns0
    '';
  };
}

