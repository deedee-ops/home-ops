{ ... }:
{
  # nixos fw messes up custom nftables config
  networking.firewall.enable = false;

  # enable NAT
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.nftables = {
    enable = true;
    flushRuleset = true;
    extraDeletions = ''
      table inet nixos-fw;
      delete table inet nixos-fw;
    '';
    ruleset = ''
      table ip filter {
        chain INPUT {
          type filter hook input priority filter; policy accept;
        }
        chain FORWARD {
          type filter hook forward priority filter; policy drop;
          ct state related,established accept
          iifname "mgmt0" oifname "wan0" accept
          iifname "trst0" oifname "wan0" accept
          iifname "untrst0" oifname "wan0" accept
          ip daddr 10.99.0.0/16 iifname "trst0" accept
        }
        chain OUTPUT {
          type filter hook output priority filter; policy accept;
        }
      }

      table ip nat {
        chain PREROUTING {
          type nat hook prerouting priority dstnat; policy accept;
          tcp dport 10000 dnat to 192.168.100.1:80
        }

        chain POSTROUTING {
          type nat hook postrouting priority srcnat; policy accept;
          oifname "wan0" masquerade
          ip daddr 192.168.100.1 masquerade
        };
      };
    '';
  };
}

