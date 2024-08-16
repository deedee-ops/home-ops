_: {
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # necessary for backwards compatibility with alpine and (by extension) wg-easy
  boot.kernelModules = [ "iptable_nat" ];
}
