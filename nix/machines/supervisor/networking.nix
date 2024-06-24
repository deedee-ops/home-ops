{ ... }:
{
  networking = {
    hostName = "supervisor";
    networkmanager.enable = true;
    enableIPv6 = false;

    # nixos firewall adds unnecessary mess
    firewall.enable = false;
  };
}

