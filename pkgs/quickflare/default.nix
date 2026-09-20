{ lib
, stdenv
, fetchFromGitHub
, rustPlatform
, cargo-tauri
, nodejs
, pnpm
, fetchPnpmDeps
, pnpmConfigHook
, pkg-config
, wrapGAppsHook3
, makeWrapper
, openssl
, webkitgtk_4_1
, libayatana-appindicator
, cloudflared
}:

let
  version = "0.1.4";
  src = fetchFromGitHub {
    owner = "Aloys233";
    repo = "quickflare";
    tag = "v${version}";
    hash = "sha256-SfPPHC4bNSgAgYK9NzZCrpEby8ZYJj3H69oYI1TCQ74=";
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "quickflare";
  inherit version src;

  pnpmDeps = fetchPnpmDeps {
    pname = "${finalAttrs.pname}-pnpm-deps";
    inherit (finalAttrs) version src;
    fetcherVersion = 4;
    hash = "sha256-m8bCVYDW5xTl57pL1jypn9RgS5CnIyCvID8V8RTEu3g=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  cargoHash = "sha256-m8bCVYDW5xTl57pL1jypn9RgS5CnIyCvID8V8RTEu3g=";

  nativeBuildInputs = [
    nodejs
    pnpmConfigHook
    pnpm
    cargo-tauri.hook
    pkg-config
    wrapGAppsHook3
    makeWrapper
  ];

  buildInputs = [
    openssl
    webkitgtk_4_1
    libayatana-appindicator
  ];

  postFixup = ''
    wrapProgram $out/bin/quickflare \
      --prefix PATH : ${lib.makeBinPath [ cloudflared ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
  '';

  meta = with lib; {
    description = "A native-feeling Cloudflare Tunnel GUI";
    homepage = "https://github.com/Aloys233/quickflare";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "quickflare";
  };
})
