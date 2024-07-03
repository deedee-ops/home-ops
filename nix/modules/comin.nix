{ ... }: {
  services.comin = {
    enable = true;
    repo_dir = "nix";
    remotes = [{
      name = "origin";
      url = "https://github.com/deedee-ops/home-ops.git";
      branches = {
        main.name = "master";
        testing.name = "";
      };
      poller.period = 120; # 2 minutes
    }];
  };
}
