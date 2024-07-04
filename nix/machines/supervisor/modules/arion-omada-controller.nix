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
        image = "ghcr.io/deedee-ops/omada-controller:5.13-chromium@sha256:4790a24aa7b1c4d4cd42335ad654a1477575c29401d539e313e2d2bd593f8c90";
        networks = {
          # uncomment when bootstrapping omada switch from scratch
          # bootstrap = {
          #   ipv4_address = "192.168.0.130";
          # };
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
      };
    };
  };
  networks = {
    # uncomment when bootstrapping omada switch from scratch
    # bootstrap = {
    #   driver = "macvlan";
    #   driver_opts = {
    #     parent = "enp6s18";
    #   };
    #   ipam = {
    #     config = [{
    #       subnet = "192.168.0.0/24";
    #       ip_range = "192.168.0.128/25";
    #     }];
    #   };
    # };
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

