{ config, ... }:
{
  users.users."${config.primaryUser}" = {
    isNormalUser = true;
    description = "${config.primaryUser}";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOrBLT88ZZ+lO8hHcj+4jqtor79OLhQZcDWF98kkWkfn personal"
    ];
    # packages = with pkgs; [];
  };

  system.activationScripts = {
    create-media.text = ''
      mkdir -p /media || true
      chown ${config.primaryUser}:users /media
    '';
  };
}
