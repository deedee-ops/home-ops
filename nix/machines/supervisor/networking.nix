{ ... }:
{
  networking = {
    hostName = "supervisor";
    networkmanager.enable = true;
    enableIPv6 = false;
  };
}

