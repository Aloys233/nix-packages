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
  version = "0.1.3";
  src = fetchFromGitHub {
    owner = "Aloys233";
    repo = "quickflare";
    tag = "v${version}";
    hash = "sha256-VXBWpTXb74FvopViq7Q0bwVA3Zu+Zhrl/Hje93OEFRs=";
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "quickflare";
  inherit version src;

  pnpmDeps = fetchPnpmDeps {
    pname = "${finalAttrs.pname}-pnpm-deps";
    inherit (finalAttrs) version src;
    fetcherVersion = 2;
    hash = lib.fakeHash;
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  cargoHash = lib.fakeHash;

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
      --prefix PATH : ${lib.makeBinPath [ cloudflared ]}
  '';

  meta = with lib; {
    description = "A native-feeling Cloudflare Tunnel GUI";
    homepage = "https://github.com/Aloys233/quickflare";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "quickflare";
  };
})
