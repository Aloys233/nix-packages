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
        # 自研软件
        quickflare = final.callPackage ./pkgs/self/quickflare { };
        komiraquake = final.callPackage ./pkgs/self/komiraquake { };
        otomusic = final.callPackage ./pkgs/self/otomusic { };

        # 第三方软件
        chatgpt = final.callPackage ./pkgs/external/chatgpt { };
        chatgpt-desktop = final.chatgpt;
        nanomuse = final.callPackage ./pkgs/external/nanomuse { };
        nanomuse-desktop = final.nanomuse;
        minecraft-launcher = final.callPackage ./pkgs/external/minecraft-launcher { };
        opentrace = final.callPackage ./pkgs/external/opentrace { };
        osu-lazer-bin = final.callPackage ./pkgs/external/osu-lazer-bin { };
        uuyc = final.callPackage ./pkgs/external/uuyc { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlay ];
        };
      in {
        packages = {
          quickflare = pkgs.quickflare;
          komiraquake = pkgs.komiraquake;
          otomusic = pkgs.otomusic;
          chatgpt = pkgs.chatgpt;
          chatgpt-desktop = pkgs.chatgpt-desktop;
          nanomuse = pkgs.nanomuse;
          nanomuse-desktop = pkgs.nanomuse-desktop;
          minecraft-launcher = pkgs.minecraft-launcher;
          opentrace = pkgs.opentrace;
          osu-lazer-bin = pkgs.osu-lazer-bin;
          uuyc = pkgs.uuyc;
          default = pkgs.quickflare;
        };

        apps = {
          quickflare = flake-utils.lib.mkApp { drv = pkgs.quickflare; };
          komiraquake = flake-utils.lib.mkApp { drv = pkgs.komiraquake; };
          otomusic = flake-utils.lib.mkApp { drv = pkgs.otomusic; };
          chatgpt = flake-utils.lib.mkApp { drv = pkgs.chatgpt; };
          nanomuse = flake-utils.lib.mkApp { drv = pkgs.nanomuse; };
          minecraft-launcher = flake-utils.lib.mkApp { drv = pkgs.minecraft-launcher; };
          opentrace = flake-utils.lib.mkApp { drv = pkgs.opentrace; };
          osu-lazer-bin = flake-utils.lib.mkApp { drv = pkgs.osu-lazer-bin; };
          uuyc = flake-utils.lib.mkApp { drv = pkgs.uuyc; };
          default = self.apps.${system}.quickflare;
        };
      }
    ) // {
      overlays.default = overlay;
      nixosModules.uuyc = import ./modules/uuyc.nix { inherit self; };
    };
}
