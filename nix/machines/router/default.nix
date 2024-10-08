{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix

    ../../modules/options.nix

    ../../modules/attic-client.nix
    ../../modules/cache.nix
    ../../modules/comin.nix
    ../../modules/locales.nix
    ../../modules/monitoring.nix
    ../../modules/os.nix
    ../../modules/ssh.nix
    ../../modules/users.nix
    ../../modules/vm.nix

    ./modules/bind.nix
    ./modules/boot.nix
    ./modules/ddclient.nix
    ./modules/firewall.nix
    ./modules/frr.nix
    ./modules/kea.nix
  ];

  primaryUser = "ajgon";
  currentHostname = "router";

  # sops
  sops = {
    defaultSopsFile = ./secrets.sops.yaml;
    age.keyFile = /etc/age/keys.txt;
  };

  # system packages
  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
