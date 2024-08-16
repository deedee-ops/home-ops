{ config, pkgs, ... }:
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

    ./modules/attic-server.nix
    ./modules/boot.nix
    ./modules/firewall.nix

    (import ./modules/docker.nix { inherit config pkgs; })
  ];

  primaryUser = "ajgon";
  currentHostname = "supervisor";

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

  system.stateVersion = "24.05";
}
