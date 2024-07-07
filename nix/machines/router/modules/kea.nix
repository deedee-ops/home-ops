{ config, pkgs, nixpkgs-unstable, ... }:
{
  nixpkgs.overlays = [ (final: prev: { kea = nixpkgs-unstable.legacyPackages."x86_64-linux".kea; }) ];

  sops = {
    secrets = {
      "kea/dhcp_bind_key" = {
        owner = "kea";
        group = "kea";
        restartUnits = [ "kea-dhcp4-server.service" "kea-dhcp-ddns-server" ];
      };
    };
  };

  # We need to manually create kea user, so secrets can use it.
  # Normally kea uses DynamicUser from systemd which is created too late,
  # and initial secrets mount from sops-nix fails because of that.
  users.users.kea = {
    group = "kea";
    description = "KEA daemon user";
    isSystemUser = true;
  };
  users.groups.kea = { };

  services.kea = {
    dhcp4 = {
      enable = true;
      settings = {
        "interfaces-config" = {
          interfaces = [
            "mgmt0"
            "trst0"
            "untrst0"
          ];
        };
        "control-socket" = {
          "socket-type" = "unix";
          "socket-name" = "/run/kea/kea4-ctrl-socket";
        };
        "lease-database" = {
          type = "memfile";
          "lfc-interval" = 3600;
        };
        "early-global-reservations-lookup" = true;
        reservations = [
          # ignore omada devices to avoid suprises when provisioning them
          {
            # switch
            "hw-address" = "24:2f:d0:88:84:ab";
            "client-classes" = [
              "DROP"
            ];
          }
          {
            # EAP660HD
            "hw-address" = "3c:52:a1:7e:10:50";
            "client-classes" = [
              "DROP"
            ];
          }
          {
            # EAP610
            "hw-address" = "40:ed:00:7d:8e:98";
            "client-classes" = [
              "DROP"
            ];
          }
        ];
        "valid-lifetime" = 600;
        "max-valid-lifetime" = 7200;
        "dhcp-ddns" = {
          "enable-updates" = true;
        };
        "ddns-qualifying-suffix" = "home.arpa";
        "ddns-override-client-update" = true;
        "ddns-override-no-update" = true;
        "option-data" = [
          {
            name = "domain-search";
            data = "home.arpa";
          }
        ];
        subnet4 = [
          {
            id = 42;
            subnet = "10.42.1.1/16";
            interface = "mgmt0";
            pools = [
              {
                pool = "10.42.100.100 - 10.42.100.200";
              }
            ];
            reservations = [
              {
                # supervisor
                "hw-address" = "00:00:0a:2a:01:02";
                "ip-address" = "10.42.1.2";
              }
              {
                # piecyk
                "hw-address" = "c8:7f:54:8f:e7:34";
                "ip-address" = "10.42.100.10";
              }
            ];
            "option-data" = [
              {
                name = "routers";
                data = "10.42.1.1";
              }
              {
                name = "domain-name-servers";
                data = "10.42.1.2";
              }
            ];
          }
          {
            id = 100;
            subnet = "10.100.1.1/16";
            interface = "trst0";
            pools = [
              {
                pool = "10.100.100.100 - 10.100.100.200";
              }
            ];
            reservations = [
              {
                # supervisor
                "hw-address" = "00:00:0a:64:01:02";
                "ip-address" = "10.100.1.2";
              }
              {
                # HAOS VM
                "hw-address" = "00:00:0a:64:01:03";
                "ip-address" = "10.100.1.3";
              }
              {
                # mandark / NAS / 10gbe
                "hw-address" = "e4:1d:53:37:56:41";
                "ip-address" = "10.100.10.1";
              }
              {
                # Proxmox Backup Server VM
                "hw-address" = "00:00:0a:64:0a:02";
                "ip-address" = "10.100.10.2";
              }
            ];
            "option-data" = [
              {
                name = "routers";
                data = "10.100.1.1";
              }
              {
                name = "domain-name-servers";
                data = "10.100.1.2";
              }
              # static routes
              {
                code = 121;
                name = "classless-static-route";
                data = "10.99.0.0/16 - 10.100.1.1";
              }
            ];
          }
          {
            id = 200;
            subnet = "10.200.1.1/16";
            interface = "untrst0";
            pools = [
              {
                pool = "10.200.100.100 - 10.200.100.200";
              }
            ];
            reservations = [
              {
                # supervisor
                "hw-address" = "00:00:0a:c8:01:02";
                "ip-address" = "10.200.1.2";
              }
            ];
            "option-data" = [
              {
                name = "routers";
                data = "10.200.1.1";
              }
              {
                name = "domain-name-servers";
                data = "10.200.1.2";
              }
            ];
          }
        ];
        loggers = [
          {
            name = "kea-dhcp4";
            "output_options" = [
              {
                output = "stdout";
              }
            ];
            severity = "INFO";
            debuglevel = 0;
          }
        ];
      };
    };

    dhcp-ddns = {
      enable = true;
      configFile = pkgs.writeText "kea-dhcp-ddns.conf" ''
        {
           "DhcpDdns": {
              "ip-address": "127.0.0.1",
              "port": 53001,
              "control-socket": {
                 "socket-type": "unix",
                 "socket-name": "/run/kea/kea-ddns-ctrl-socket"
              },
              <?include "${config.sops.secrets."kea/dhcp_bind_key".path}"?>
              "forward-ddns": {
                 "ddns-domains": [
                    {
                       "name": "home.arpa.",
                       "key-name": "dhcp-bind",
                       "dns-servers": [
                          {
                             "ip-address": "10.100.1.1"
                          },
                          {
                             "ip-address": "10.200.1.1"
                          }
                       ]
                    }
                 ]
              },
              "reverse-ddns": {
                 "ddns-domains": [
                    {
                       "name": "100.10.in-addr.arpa.",
                       "key-name": "dhcp-bind",
                       "dns-servers": [
                          {
                             "ip-address": "10.100.1.1"
                          }
                       ]
                    },
                    {
                       "name": "200.10.in-addr.arpa.",
                       "key-name": "dhcp-bind",
                       "dns-servers": [
                          {
                             "ip-address": "10.200.1.1"
                          }
                       ]
                    }
                 ]
              },
              "loggers": [
                 {
                    "name": "kea-dhcp-ddns",
                    "output_options": [
                       {
                          "output": "stdout"
                       }
                    ],
                    "severity": "DEBUG",
                    "debuglevel": 99
                 }
              ]
           }
        }
      '';
    };
  };
}
