{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix

    ../../modules/options.nix

    ../../modules/comin.nix
    ../../modules/locales.nix
    ../../modules/os.nix
    ../../modules/ssh.nix
    ../../modules/users.nix
    ../../modules/vm.nix

    ./modules/boot.nix
    ./modules/rustdesk.nix
  ];

  primaryUser = "ajgon";
  currentHostname = "rustdesk";

  # system packages
  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  system.stateVersion = "24.05";
}
