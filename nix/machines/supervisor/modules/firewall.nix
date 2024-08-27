_: {
  # nixos fw messes up custom nftables config
  networking.firewall.enable = false;

  # enable NAT
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.nftables = {
    enable = true;
    flushRuleset = false;
    # need to ensure chain exists, to flush it, otherwise nft throws error and deriviation fails
    extraDeletions = ''
      table ip filter {
        chain INPUT {
          type filter hook input priority filter; policy drop;
        }
      }
      flush chain filter INPUT
    '';
    ruleset = ''
      table ip filter {
        chain INPUT {
          type filter hook input priority filter; policy drop;
          ct state related,established accept
          iifname "lo" accept
          udp dport 53 accept

          # allow icmp
          icmp type echo-request accept

          # dockerd
          tcp dport 2376 accept

          # node-exporter
          tcp dport 9100 accept

          # systemd-exporter
          tcp dport 9558 accept

          # allow docker communication
          ip saddr 172.16.0.0/12 accept

          # allow mgmt network
          ip saddr 10.42.0.0/16 accept

          # allow nginx and DNS on trusted network
          ip saddr 10.100.0.0/16 tcp dport 443 accept
          ip saddr 10.100.0.0/16 udp dport 53 accept
        }
      }
    '';
  };
}
