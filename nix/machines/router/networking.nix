{ ... }:
{
  systemd.network = {
    enable = true;
    links = {
      "1-wan" = {
        matchConfig.PermanentMACAddress = "00:19:99:ed:37:04";
        linkConfig.Name = "wan0";
      };
      "42-management" = {
        matchConfig.PermanentMACAddress = "00:00:0a:2a:01:01";
        linkConfig.Name = "mgmt0";
      };
      "100-trusted" = {
        matchConfig.PermanentMACAddress = "58:47:ca:76:66:33";
        linkConfig.Name = "trst0";
      };
      "200-untrusted" = {
        matchConfig.PermanentMACAddress = "58:47:ca:76:66:34";
        linkConfig.Name = "untrst0";
      };
    };
    networks = {
      "1-wan" = {
        matchConfig.Name = "wan0";
        linkConfig = {
          RequiredForOnline = "routable";
        };
        networkConfig = {
          DHCP = "ipv4";
        };
      };
      "42-management" = {
        matchConfig.Name = "mgmt0";
        linkConfig = {
          RequiredForOnline = "routable";
        };
        address = [
          "10.42.1.1/16"
        ];
      };
      "100-trusted" = {
        matchConfig.Name = "trst0";
        linkConfig = {
          RequiredForOnline = "routable";
          MTUBytes = "9000";
        };
        address = [
          "10.100.1.1/16"
        ];
      };
      "200-untrusted" = {
        matchConfig.Name = "untrst0";
        linkConfig = {
          RequiredForOnline = "routable";
        };
        address = [
          "10.200.1.1/16"
        ];
      };
    };
  };

  networking = {
    hostName = "router";
    networkmanager.enable = false;
    enableIPv6 = false;
    useDHCP = false;
  };
}
