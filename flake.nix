{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

    packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

    packages.gitmanager = nixpkgs.stdenv.mkDerivation{
      src = ./src;
      unpack=false;
      installPhase = ''
        # $out is an automatically generated filepath by nix,
        # but it's up to you to make it what you need. We'll create a directory at
        # that filepath, then copy our sources into it.
        mkdir $out/bin
        cp -rv $src/* $out
      '';

    };

    nixosModules.gitmanager = {
      options.services.gitmanager = {
				enable = mkEnableOption "Gitmanager Service";
			};

			config = mkIf config.services.gitmanager.enable {
				system.fsPackages = [ self.packages.${pkgs.system}.gitmanager ];
				systemd = {
					services.gitmanager = {
						wantedBy = [ "multi-user.target" ];
						path = with pkgs; [
							git
							self.packages.${pkgs.system}.gitmanager
						];
						script = "gitmanager";
					};
				};
			};

    };

  };
}
