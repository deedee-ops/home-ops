{ ... }:
{
  # nixos fw messes up custom nftables config
  networking.firewall.enable = false;

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
          type filter hook forward priority filter; policy accept;
          ct state related,established accept
          iifname "mgmt0" oifname "wan0" accept
          iifname "trst0" oifname "wan0" accept
          iifname "untrst0" oifname "wan0" accept
        }
        chain OUTPUT {
          type filter hook output priority filter; policy accept;
        }
      }

      table ip nat {
        chain POSTROUTING {
          type nat hook postrouting priority srcnat; policy accept;
          oifname "wan0" masquerade
        };
      };
    '';
  };
}

