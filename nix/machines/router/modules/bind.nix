{ config, pkgs, root_domain, ... }:
let
  allowedNetworks = [ "10.42.0.0/16" "10.100.0.0/16" "10.200.0.0/16" ];
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
      ${pkgs.bind}/sbin/rndc freeze home.arpa
      ${pkgs.bind}/sbin/rndc freeze 100.10.in-addr.arpa
      ${pkgs.bind}/sbin/rndc freeze 200.10.in-addr.arpa
    '';
    # "restart-bind" is alphabetically after "etc" script
    restart-bind.text = ''
      for zone in /etc/bind/zones/*.zone; do ${pkgs.gnused}/bin/sed -i"" "s@1000000099@$(date +%s)@g" $zone; done
      ${pkgs.bind}/sbin/rndc thaw home.arpa
      ${pkgs.bind}/sbin/rndc thaw 100.10.in-addr.arpa
      ${pkgs.bind}/sbin/rndc thaw 200.10.in-addr.arpa
      ${pkgs.bind}/sbin/rndc sync
      ${pkgs.systemd}/bin/systemctl restart bind
    '';
  };

  services.bind = {
    enable = true;
    forwarders = [];
    ipv4Only = true;
    cacheNetworks = allowedNetworks;
    extraOptions = ''
      recursion yes;
      allow-recursion { any; };
      allow-transfer { none; };
    '';
    zones = {
      "home.arpa" = {
        master = true;
        file = "/etc/bind/zones/home.arpa.zone";
        extraConfig = ''
          update-policy {
            grant dhcp-bind wildcard *.home.arpa A DHCID;
          };
        '';
        allowQuery = allowedNetworks;
      };
      "${root_domain}" = {
        master = true;
        file = "/etc/bind/zones/${root_domain}.zone";
        allowQuery = allowedNetworks;
      };
      "100.10.in-addr.arpa" = {
        master = true;
        file = "/etc/bind/zones/100.10.in-addr.arpa.zone";
        extraConfig = ''
          update-policy {
            grant dhcp-bind wildcard *.100.10.in-addr.arpa PTR DHCID;
          };
        '';
        allowQuery = allowedNetworks;
      };
      "200.10.in-addr.arpa" = {
        master = true;
        file = "/etc/bind/zones/200.10.in-addr.arpa.zone";
        extraConfig = ''
          update-policy {
            grant dhcp-bind wildcard *.200.10.in-addr.arpa PTR DHCID;
          };
        '';
        allowQuery = allowedNetworks;
      };
    };
    extraConfig = ''
      include "${config.sops.secrets."bind/dhcp_bind_key".path}";
      include "/etc/bind/default-zones.conf";
    '';
  };

  environment.etc = {
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
           1000000099   ; Serial
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
           1000000099   ; Serial
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
           1000000099   ; Serial
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
           1000000099   ; Serial
               604800		; Refresh
                86400		; Retry
              2419200		; Expire
               604800 )	; Negative Cache TTL
        ;
        @	IN	NS	localhost.
      '';
    };

    "bind/zones/${root_domain}.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        $TTL  21600
        @ IN SOA ns.${root_domain}. admin.${root_domain}. (
            1000000099    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.${root_domain}.
        ns                   IN  A   10.42.1.1
        ns                   IN  A   10.100.1.1
        ns                   IN  A   10.200.1.1

        ; management
        supervisor           IN  A   10.42.1.2
        adguard              IN  A   10.42.1.2
        dexter               IN  A   10.42.1.2
        netia                IN  A   10.42.1.2
        omada                IN  A   10.42.1.2

        ; trusted
        nas                  IN  A   10.100.10.1
        home                 IN  A   10.100.1.2
        *                    IN  A   10.99.20.1
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
            1000000099    ; Serial
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
        dexter               IN  A   10.42.1.10
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
            1000000099    ; Serial
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
            1000000099    ; Serial
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
