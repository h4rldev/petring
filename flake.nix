{
  description = "petring - A webring and website add service in Erlang OTP/28 :3";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch63-linux"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {inherit system;}));
  in {
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "petring";

        buildInputs = with pkgs; [
          beamPackages.erlang
          beamPackages.rebar3
          sqlite
          brotli
          file
          pkg-config
          libargon2
          deno
        ];

        packages = with pkgs; [
          erlang-language-platform
          just
          svelte-language-server
          svelte-check
          typescript-language-server
          tailwindcss-language-server
          prettierd
          prettier
        ];

        shellHook = ''
          export ERL_ROOT="${pkgs.beamPackages.erlang}/lib/erlang/"
        '';
      };
    });
  };
}
