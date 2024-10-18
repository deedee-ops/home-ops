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
        image = "public.ecr.aws/docker/library/postgres:17.0@sha256:8d3be35b184e70d81e54cbcbd3df3c0b47f37d06482c0dd1c140db5dbcc6a808";
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
