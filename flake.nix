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
      genStr = repoPath: origin: remote: "${repoPath}:${origin}:${remote}";
    in
    {

      packages = nixpkgs.lib.genAttrs archs (system: with nixpkgs.legacyPackages.${system}; rec {
        gitmanager = stdenv.mkDerivation {
          src = ./src;
          pname = "climbablebug_gitmanager";
          version = "0.1.0";
          unpack = false;
          installPhase = ''
            # $out is an automatically generated filepath by nix,
            # but it's up to you to make it what you need. We'll create a directory at
            # that filepath, then copy our sources into it.
            mkdir -p $out/bin
            cp -rv $src/* $out/bin/
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
          user = mkOption {
            type = with types; str;
            default = "root";
          };
        };

        config = mkIf config.services.gitmanager.enable {
          system.fsPackages = [ self.packages.${pkgs.system}.gitmanager ];
          systemd = {
            timers.gitmanager = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = config.services.gitmanager.freq;
                OnUnitActiveSec = config.services.gitmanager.freq;
                Unit = "gitmanager.service";
              };
            };
            services.gitmanager = {
              wantedBy = [ "multi-user.target" ];
              path = with pkgs; [
                git
                self.packages.${pkgs.system}.gitmanager
                gawk
                gnugrep
                openssh
              ];
              serviceConfig = {
                Type = "oneshot";
                User = config.services.gitmanager.user;
              };
              preStart="pre-gitmanager-start '${lib.concatMapStrings (x: x+"\n") (map (x: genStr x.repoPath x.origin x.remoteURL) config.services.gitmanager.repos) }'";
              script = "gitmanager '${lib.concatMapStrings (x: x+"\n") (map (x: genStr x.repoPath x.origin) config.services.gitmanager.repos) }'";
            };
          };
        };
      };
    };
}
    
