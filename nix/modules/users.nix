{ ... }:
{
  users.users.ajgon = {
    isNormalUser = true;
    description = "ajgon";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOrBLT88ZZ+lO8hHcj+4jqtor79OLhQZcDWF98kkWkfn personal"
    ];
    # packages = with pkgs; [];
  };
}
