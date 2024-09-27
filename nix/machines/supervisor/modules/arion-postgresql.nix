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
        image = "public.ecr.aws/docker/library/postgres:16.4@sha256:5b8e928c9f4deada97460020379683966529df4c9f1199224a83640ff1df143d";
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
