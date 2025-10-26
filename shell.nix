{pkgs ? import <nixpkgs> {}}:
with pkgs;
  mkShell {
    name = "petring";
    description = "A web ring for jess museum, built with axum :3";
    buildInputs = [
      rustup
      pkg-config
      sqlite
      just
      openssl

      # linters and formatters
      markdownlint-cli
      prettierd
      biome
      nodePackages_latest.alex
      doctoc
      cbfmt
      actionlint
      taplo
      beautysh
      dockerfmt
      hadolint

      # lsp
      nixd
      bash-language-server
      docker-language-server
    ];
  }
