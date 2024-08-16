{ pkgs, ... }:
{
  system.activationScripts = {
    push-to-attic.text = ''
      ${pkgs.attic-client}/bin/attic push homelab $(ls -d /nix/store/*/ | grep -v fake_nixpkgs)
    '';
  };

  environment.systemPackages = [ pkgs.attic-client ];
}
