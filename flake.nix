{
  description = "Aloys's Personal Nix Packages Repository";

  nixConfig = {
    extra-substituters = [
      "https://aloys23.cachix.org"
    ];
    extra-trusted-public-keys = [
      "aloys23.cachix.org-1:COmV4eR1tSqvJ/e7tzDrpvG0RaB14pl3YgX9vH7YWNo="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        quickflare = final.callPackage ./pkgs/quickflare { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in {
        packages = {
          quickflare = pkgs.quickflare;
          default = pkgs.quickflare;
        };

        apps = {
          quickflare = flake-utils.lib.mkApp { drv = pkgs.quickflare; };
          default = self.apps.${system}.quickflare;
        };
      }
    ) // {
      overlays.default = overlay;
    };
}
