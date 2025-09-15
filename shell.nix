{pkgs ? import <nixpkgs> {}}:
with pkgs;
  mkShell {
    name = "jess-webring";
    description = "A web ring for jess museum, built with axum :3";
    buildInputs = [
      rustup
      pkg-config
    ];
  }
