{ config, ... }:
{
  nix.settings = {
    substituters = [ "https://attic.${config.remoteDomain}/homelab" ];
    trusted-substituters = [ "https://attic.${config.remoteDomain}/homelab" ];
    trusted-public-keys = [ "homelab:kwqUnjVjjHr+9sNlHHOx5KgLUBrwzvG7+ibw2Z/g8uQ=" ];
  };
}
