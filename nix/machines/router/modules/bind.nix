{ config, pkgs, lib, root_domain, ... }:
let
  serial = lib.readFile "${pkgs.runCommand "timestamp" { env.when = builtins.currentTime; } "echo -n `date -d @$when +%s` > $out"}";
in
{
  sops = {
    secrets = {
      "bind/dhcp_bind_key" = {
        owner = "named";
        group = "named";
        restartUnits = [ "bind.service" ];
      };
    };
  };

  system.activationScripts = {
    # "bind-zones" is alphabetically before "etc" script
    bind-zones.text = ''
      mkdir -p /etc/bind/zones
      chown named:named /etc/bind /etc/bind/zones || chown 995:994 /etc/bind /etc/bind/zones
      chmod 510 /etc/bind
      chmod 750 /etc/bind/zones
    '';
    # "restart-bind" is alphabetically after "etc" script
    restart-bind.text = ''
      ${pkgs.bind}/sbin/rndc sync
      ${pkgs.systemd}/bin/systemctl restart bind
    '';
  };

  services.bind = {
    enable = true;
    forwarders = [];
    ipv4Only = true;
    cacheNetworks = [ "10.42.0.0/16" "10.100.0.0/16" "10.200.0.0/16" ];
    extraOptions = ''
      recursion yes;
      allow-recursion { any; };
      allow-transfer { none; };
    '';
    extraConfig = ''
      include "/etc/bind/acl.conf";
      include "${config.sops.secrets."bind/dhcp_bind_key".path}";

      view "base" {
        match-clients { none; };

        zone "home.arpa" {
          type master;
          file "/etc/bind/zones/home.arpa.zone";
          update-policy {
            grant dhcp-bind wildcard *.home.arpa A DHCID;
          };
        };
      };

      view "management-view" {
        match-clients { management; };

        include "/etc/bind/default-zones.conf";

        zone "home.arpa" {
          in-view "base";
        };

        zone "${root_domain}" {
          type master;
          file "/etc/bind/zones/management.${root_domain}.zone";
        };
      };

      view "trusted-view" {
        match-clients { trusted; };

        include "/etc/bind/default-zones.conf";

        zone "${root_domain}" {
          type master;
          file "/etc/bind/zones/trusted.${root_domain}.zone";
        };

        zone "home.arpa" {
          in-view "base";
        };

        zone "100.10.in-addr.arpa" {
          type master;
          file "/etc/bind/zones/100.10.in-addr.arpa.zone";
          update-policy {
            grant dhcp-bind wildcard *.100.10.in-addr.arpa PTR DHCID;
          };
        };
      };

      view "untrusted-view" {
        match-clients { untrusted; };

        include "/etc/bind/default-zones.conf";

        zone "${root_domain}" {
          type master;
          file "/etc/bind/zones/untrusted.${root_domain}.zone";
        };

        zone "home.arpa" {
          in-view "base";
        };

        zone "200.10.in-addr.arpa" {
          type master;
          file "/etc/bind/zones/200.10.in-addr.arpa.zone";
          update-policy {
            grant dhcp-bind wildcard *.200.10.in-addr.arpa PTR DHCID;
          };
        };
      };

      view "default" {
        match-clients { any; };
        include "/etc/bind/default-zones.conf";
      };
    '';
  };

  environment.etc = {
    "bind/acl.conf" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        acl management {
          10.42.0.0/16;
        };

        acl trusted {
          10.100.0.0/16;
        };

        acl untrusted {
          10.200.0.0/16;
        };
      '';
    };

    "bind/default-zones.conf" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        zone "." {
          type hint;
          file "${
            pkgs.fetchurl {
              url = "http://www.internic.net/domain/named.root";
              hash = "sha256-Jfu4b5dfgUrVwzUR2svc/AfLINCje0lv7e+nJC7zGIs=";
            }
          }";
        };

        zone "localhost" {
          type master;
          file "/etc/bind/zones/local.zone";
        };

        zone "127.in-addr.arpa" {
          type master;
          file "/etc/bind/zones/127.in-addr.arpa.zone";
        };

        zone "0.in-addr.arpa" {
          type master;
          file "/etc/bind/zones/0.in-addr.arpa.zone";
        };

        zone "255.in-addr.arpa" {
          type master;
          file "/etc/bind/zones/255.in-addr.arpa.zone";
        };
      '';
    };

    "bind/zones/local.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        ;
        ; BIND data file for local loopback interface
        ;
        $TTL	604800
        @	IN	SOA	localhost. root.localhost. (
                    2		; Serial
               604800		; Refresh
                86400		; Retry
              2419200		; Expire
               604800 )	; Negative Cache TTL
        ;
        @	IN	NS	localhost.
        @	IN	A	127.0.0.1
        @	IN	AAAA	::1
      '';
    };

    "bind/zones/127.in-addr.arpa.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        ;
        ; BIND reverse data file for local loopback interface
        ;
        $TTL	604800
        @	IN	SOA	localhost. root.localhost. (
                    1		; Serial
               604800		; Refresh
                86400		; Retry
              2419200		; Expire
               604800 )	; Negative Cache TTL
        ;
        @	IN	NS	localhost.
        1.0.0	IN	PTR	localhost.
      '';
    };

    "bind/zones/0.in-addr.arpa.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        ;
        ; BIND reverse data file for "this host on this network" zone
        ;
        $TTL	604800
        @	IN	SOA	localhost. root.localhost. (
                    1		; Serial
               604800		; Refresh
                86400		; Retry
              2419200		; Expire
               604800 )	; Negative Cache TTL
        ;
        @	IN	NS	localhost.
      '';
    };

    "bind/zones/255.in-addr.arpa.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        ;
        ; BIND reverse data file for broadcast zone
        ;
        $TTL	604800
        @	IN	SOA	localhost. root.localhost. (
                    1		; Serial
               604800		; Refresh
                86400		; Retry
              2419200		; Expire
               604800 )	; Negative Cache TTL
        ;
        @	IN	NS	localhost.
      '';
    };

    "bind/zones/management.${root_domain}.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        $TTL  21600
        @ IN SOA ns.${root_domain}. admin.${root_domain}. (
            ${serial}    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.${root_domain}.
        ns                   IN  A   10.42.1.1

        supervisor           IN  A   10.42.1.2
        omada                IN  A   10.42.1.2
        netia                IN  A   10.42.1.2
      '';
    };

    "bind/zones/trusted.${root_domain}.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        $TTL  21600
        @ IN SOA ns.${root_domain}. admin.${root_domain}. (
            ${serial}    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.${root_domain}.
        ns                   IN  A   10.100.1.1

        nas                  IN  A   10.100.10.1

        *                    IN  A   10.99.20.10
      '';
    };

    "bind/zones/untrusted.${root_domain}.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        $TTL  21600
        @ IN SOA ns.${root_domain}. admin.${root_domain}. (
            ${serial}    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.${root_domain}.
        ns                   IN  A   10.200.1.1

        jellyfin             IN  A   10.200.20.10
        atuin                IN  A   10.200.20.11
      '';
    };

    "bind/zones/home.arpa.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0640";
      text = ''
        $TTL  21600
        @ IN SOA ns.home.arpa. admin.home.arpa. (
            ${serial}    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.home.arpa.
        ns                   IN  A   10.42.1.1
        ns                   IN  A   10.100.1.1
        ns                   IN  A   10.200.1.1

        router               IN  A   10.42.1.1
        supervisor           IN  A   10.42.1.2
      '';
    };

    "bind/zones/100.10.in-addr.arpa.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0640";
      text = ''
        $TTL  21600
        @ IN SOA ns.home.arpa. admin.home.arpa. (
            ${serial}    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.home.arpa.
      '';
    };

    "bind/zones/200.10.in-addr.arpa.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0640";
      text = ''
        $TTL  21600
        @ IN SOA ns.home.arpa. admin.home.arpa. (
            ${serial}    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.home.arpa.
      '';
    };
  };
}
