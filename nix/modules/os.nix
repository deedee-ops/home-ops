{
  inputs,
  config,
  lib,
  ...
}:
{
  # Flakes
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    registry = {
      nixpkgs-unstable.flake = inputs.nixpkgs-unstable;
    };
    settings = {
      use-xdg-base-directories = true;
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };

  # save power
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # allow some of the unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) config.allowUnfree;
}
