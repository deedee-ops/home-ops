{ config, ... }:
{
  services = {
    postgresql = {
      service = {
        restart = "always";
        container_name = "postgresql";
        # by default DNS is set to adguard in docker which causes internal loopback and resolving problems
        # that's why we need to force it to actual gateway
        dns = [ "10.42.1.1" ];
        image = "public.ecr.aws/docker/library/postgres:17.0@sha256:d6edd9c58fd2c862a1936218ab7380e156a328e2630c3bad8fa7a9060c9404aa";
        ports = [ "5432:5432" ];
        environment = {
          POSTGRES_PASSWORD_FILE = "/run/passwd";
          TZ = "Europe/Warsaw";
        };
        volumes = [
          "/data/postgresql:/var/lib/postgresql/data"
          "${config.sops.secrets."postgresql/password".path}:/run/passwd"
        ];
      };
    };
  };
}
