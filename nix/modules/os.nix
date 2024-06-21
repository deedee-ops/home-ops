{ ... }:
{
  # Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # swapfile
  swapDevices = [{
    device = "/swapfile";
    size = 4096; # 4GB
  }];
}
