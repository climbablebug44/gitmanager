{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    with nixpkgs.lib;
    let
      archs = [
        "x86_64-linux"
        "aarch64-linux"
        "riscv64-linux"
      ];
      genStr = repoPath: origin: "${repoPath}:${origin}";
    in
    {

      packages = nixpkgs.lib.genAttrs archs (system: with nixpkgs.legacyPackages.${system}; rec {
        gitmanager = nixpkgs.stdenv.mkDerivation {
          src = ./src;
          unpack = false;
          installPhase = ''
            # $out is an automatically generated filepath by nix,
            # but it's up to you to make it what you need. We'll create a directory at
            # that filepath, then copy our sources into it.
            mkdir $out/bin
            cp -rv $src/* $out
          '';
        };
      });

      nixosModules.gitmanager = { config, pkgs, lib, ... }: with nixpkgs.lib; {
        options.services.gitmanager = {
          enable = mkEnableOption "Gitmanager Service";
          freq = mkOption {
            type = with types; str;
            default = "60m";
          };
          repos = mkOption {
            type = with types; listOf attrs;
            default = [ ];
          };
        };

        config = mkIf config.services.gitmanager.enable {
          system.fsPackages = [ self.packages.${pkgs.system}.gitmanager ];
          systemd = {
            timers.gitmanager = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = cfg.freq;
                OnUnitActiveSec = cfg.freq;
                Unit = "gitmanager.service";
              };
            };
            services.gitmanager = {
              wantedBy = [ "multi-user.target" ];
              path = with pkgs; [
                git
                self.packages.${pkgs.system}.gitmanager
              ];
              serviceConfig = {
                Type = "oneshot";
                User = "root";
              };
              script = "gitmanager '${lib.concatMapStrings (x: x+"\n") (map (x: genStr x.repoPath x.origin) config.repos) }'";
            };
          };
        };
      };
    };
}
    
