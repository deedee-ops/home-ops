{ config, ... }:
{
  services.prometheus.exporters = {
    node.enable = true;
    systemd.enable = true;
  };

  services.promtail = {
    enable = true;
    configuration = {
      clients = [ { url = "https://loki.${config.remoteDomain}/loki/api/v1/push"; } ];
      server.disable = true;
      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            json = false;
          };
          relabel_configs = [
            {
              source_labels = [ "__journal__hostname" ];
              target_label = "host";
            }
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "systemd_unit";
              regex = "(.+)";
            }
            {
              source_labels = [ "__journal__systemd_user_unit" ];
              target_label = "systemd_user_unit";
              regex = "(.+)";
            }
            {
              source_labels = [ "__journal__transport" ];
              target_label = "transport";
              regex = "(.+)";
            }
            {
              source_labels = [ "__journal_priority_keyword" ];
              target_label = "severity";
              regex = "(.+)";
            }
          ];
        }
      ];
    };
  };
}
