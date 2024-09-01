{ config, pkgs, ... }:
let
  allowedNetworks = [
    "10.42.0.0/16"
    "10.100.0.0/16"
    "10.200.0.0/16"
  ];
in
{
  sops = {
    secrets = {
      "bind/dhcp_bind_key" = {
        owner = "named";
        group = "named";
        restartUnits = [ "bind.service" ];
      };
      "bind/home_arpa_zone" = {
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
      ${pkgs.bind}/sbin/rndc freeze ${config.localDomain} || true
      ${pkgs.bind}/sbin/rndc freeze 100.10.in-addr.arpa || true
      ${pkgs.bind}/sbin/rndc freeze 200.10.in-addr.arpa || true
    '';
    # "restart-bind" is alphabetically after "etc" script
    restart-bind.text = ''
      for zone in /etc/bind/zones/*.zone; do ${pkgs.gnused}/bin/sed -i"" "s@1000000099@$(date +%s)@g" $zone; done
      ${pkgs.bind}/sbin/rndc thaw ${config.localDomain} || true
      ${pkgs.bind}/sbin/rndc thaw 100.10.in-addr.arpa || true
      ${pkgs.bind}/sbin/rndc thaw 200.10.in-addr.arpa || true
      ${pkgs.bind}/sbin/rndc sync
      ${pkgs.systemd}/bin/systemctl restart bind
    '';
  };

  services.bind = {
    enable = true;
    forwarders = [ ];
    ipv4Only = true;
    cacheNetworks = allowedNetworks;
    extraOptions = ''
      recursion yes;
      allow-recursion { any; };
      allow-transfer { none; };
    '';
    zones = {
      "${config.localDomain}" = {
        master = true;
        file = "/etc/bind/zones/${config.localDomain}.zone";
        extraConfig = ''
          update-policy {
            grant dhcp-bind wildcard *.${config.localDomain} A DHCID;
          };
        '';
        allowQuery = allowedNetworks;
      };
      "${config.remoteDomain}" = {
        master = true;
        file = "/etc/bind/zones/${config.remoteDomain}.zone";
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
              hash = "sha256-rWqbuFjqMsfM7Y7KTwZhK7y+uCijXj9zvpWCi850aH8=";
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

    "bind/zones/${config.remoteDomain}.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0400";
      text = ''
        $TTL  21600
        @ IN SOA ns.${config.remoteDomain}. admin.${config.remoteDomain}. (
            1000000099    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.${config.remoteDomain}.
        ns                   IN  A   10.42.1.1
        ns                   IN  A   10.100.1.1
        ns                   IN  A   10.200.1.1

        ; management
        supervisor           IN  A   10.42.1.2
        dexter               IN  A   10.42.1.2
        netia                IN  A   10.42.1.2
        pbs                  IN  A   10.42.1.2
        wg                   IN  A   10.42.1.2

        ; trusted
        adguard              IN  A   10.100.1.2
        attic                IN  A   10.100.1.2
        homelab              IN  A   10.100.1.2
        nas                  IN  A   10.100.10.1
        home                 IN  A   10.100.1.2
        minio                IN  A   10.100.1.2
        omada                IN  A   10.100.1.2
        s3                   IN  A   10.100.1.2
        *                    IN  A   10.99.20.1

        ; untrusted
        relay                IN  A   10.200.1.4
      '';
    };

    "bind/zones/${config.localDomain}.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0640";
      text = ''
        $TTL  21600
        @ IN SOA ns.${config.localDomain}. admin.${config.localDomain}. (
            1000000099    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.${config.localDomain}.
        ns                   IN  A   10.42.1.1
        ns                   IN  A   10.100.1.1
        ns                   IN  A   10.200.1.1

        router               IN  A   10.42.1.1
        supervisor           IN  A   10.42.1.2
        dexter               IN  A   10.42.1.10
        nas                  IN  A   10.100.10.1
        pbs                  IN  A   10.100.10.2
        piecyk               IN  A   10.100.100.10
        rustdesk             IN  A   10.200.1.4

        ; extras
        $INCLUDE ${config.sops.secrets."bind/home_arpa_zone".path}
      '';
    };

    "bind/zones/100.10.in-addr.arpa.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0640";
      text = ''
        $TTL  21600
        @ IN SOA ns.${config.localDomain}. admin.${config.localDomain}. (
            1000000099    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.${config.localDomain}.
      '';
    };

    "bind/zones/200.10.in-addr.arpa.zone" = {
      enable = true;
      user = "named";
      group = "named";
      mode = "0640";
      text = ''
        $TTL  21600
        @ IN SOA ns.${config.localDomain}. admin.${config.localDomain}. (
            1000000099    ; Serial
                 21600    ; Refresh
                  3600    ; Retry
               2592000    ; Expire
                172800 )  ; Negative Cache TTL
        ;

        @                    IN  NS  ns.${config.localDomain}.
      '';
    };
  };
}
