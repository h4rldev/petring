{pkgs ? import <nixpkgs> {}}:
with pkgs;
  mkShell {
    name = "petring";
    description = "A web ring for jess museum, built with axum :3";
    buildInputs = [
      rustup
      pkg-config
      sqlite
      openssl

      # linters and formatters
      markdownlint-cli
      prettierd
      alejandra
    ];
  }
