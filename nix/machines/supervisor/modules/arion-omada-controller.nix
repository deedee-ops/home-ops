{ ... }:
{
  services = {
    omada-controller = {
      service = {
        restart = "always";
        container_name = "omada-controller";
        # by default DNS is set to adguard in docker which causes internal loopback and resolving problems
        # that's why we need to force it to actual gateway
        dns = [ "10.42.1.1" ];
        image = "ghcr.io/deedee-ops/omada-controller:5.14-chromium@sha256:4ac9dccc0158ed3e57cf98043cc4e24fce4eae51c1298c6a1a20faacec542d17";
        networks = {
          # uncomment when bootstrapping omada switch from scratch
          # bootstrap = {
          #   ipv4_address = "192.168.0.130";
          # };
          # this one should be always uncommented
          mgmt = {
            ipv4_address = "10.42.2.1";
          };
          default = {};
        };
        environment = {
          TZ = "Europe/Warsaw";
        };
        volumes = [
          "/data/omada-controller/data:/opt/tplink/EAPController/data"
          "/data/omada-controller/logs:/opt/tplink/EAPController/logs"
        ];
        labels = {
          "homepage.group" = "External";
          "homepage.name" = "Omada";
          "homepage.icon" = "omada.png";
          "homepage.href" = "https://omada.rzegocki.dev/";
          "homepage.description" = "Omada Controller";
        };
      };
    };
  };
  networks = {
    # uncomment when bootstrapping omada switch from scratch
    # bootstrap = {
    #   driver = "macvlan";
    #   driver_opts = {
    #     parent = "enp6s20";
    #   };
    #   ipam = {
    #     config = [{
    #       subnet = "192.168.0.0/24";
    #       ip_range = "192.168.0.128/25";
    #     }];
    #   };
    # };
    # this one should be always uncommented
    mgmt = {
      driver = "macvlan";
      driver_opts = {
        parent = "enp6s18";
      };
      ipam = {
        config = [{
          subnet = "10.42.0.0/16";
          ip_range = "10.42.2.0/24";
        }];
      };
    };
  };
}

