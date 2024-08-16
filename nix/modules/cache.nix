{ config, ... }:
{
  nix.settings = {
    substituters = [ "https://attic.${config.remoteDomain}/homelab" ];
    trusted-substituters = [ "https://attic.${config.remoteDomain}/homelab" ];
    trusted-public-keys = [ "homelab:4QC5tI8xexADyKayaRCRJzZDwFx7Vt56kLz+cVkXQoo=" ];
  };
}
