{}: let
  pkgs = import <nixpkgs> {};
  unstablePkgs = import <nixos-unstable> {};

  lib = pkgs.lib;
  stdenv = pkgs.stdenv;

  config = import <config> {};
  configPath = builtins.getEnv "NIXOS_CONFIGURATION_DIR" + "/.";
  currentDir = ./.;
in
  pkgs.mkShell {
    buildInputs = with unstablePkgs; [
		beam27Packages.rebar3
		inotify-tools
    ];

    shellHook = ''
      echo "Welcome to the 'White Dog 🐶' compilation shell"
      export PS1="\\[\\033[1;36m\\][\\u@🐶(\\h):\\w]$\\[\\033[0m\\] "
    '';
  }
