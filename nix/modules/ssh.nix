{ ... }:
{
  services.openssh = {
    enable = true;
    # require public key authentication for better security
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };
  programs.ssh.startAgent = true;

  # pass ssh-agent socket when using sudo
  security.sudo.extraConfig = ''
    Defaults:root,%wheel env_keep+=SSH_AUTH_SOCK
  '';
}
