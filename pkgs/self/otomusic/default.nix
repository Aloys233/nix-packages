{ lib
, stdenv
, fetchFromGitHub
, nodejs
, pnpm
, fetchPnpmDeps
, pnpmConfigHook
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, electron
, mpv-unwrapped
}:

let
  version = "1.0.3";
  src = fetchFromGitHub {
    owner = "Aloys233";
    repo = "OtoMusic";
    tag = "v${version}";
    hash = "sha256-QOgYgWXtUXLwTSSdKF8+1AT1gpajZs85Agc35Ey9Huo=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "otomusic";
  inherit version src;

  pnpmDeps = fetchPnpmDeps {
    pname = "${finalAttrs.pname}-pnpm-deps";
    inherit (finalAttrs) version src;
    fetcherVersion = 4;
    hash = "sha256-MQOM0zOqAjy3y4zYl/0qm2+6b0a3OBLLgb39UqPuGlk=";
  };

  nativeBuildInputs = [
    nodejs
    pnpmConfigHook
    pnpm
    makeWrapper
    copyDesktopItems
  ];

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/otomusic
    cp -r dist dist-electron electron package.json $out/share/otomusic/

    install -Dm644 otomusic.png $out/share/icons/hicolor/512x512/apps/otomusic.png

    makeWrapper ${electron}/bin/electron $out/bin/otomusic \
      --add-flags "$out/share/otomusic" \
      --prefix PATH : ${lib.makeBinPath [ mpv-unwrapped ]} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "otomusic";
      exec = "otomusic %U";
      icon = "otomusic";
      desktopName = "OtoMusic";
      genericName = "Music Player";
      comment = "OtoMusic desktop player for Navidrome/Subsonic libraries";
      categories = [ "AudioVideo" "Audio" "Player" "Music" ];
      startupWMClass = "OtoMusic";
      terminal = false;
    })
  ];

  meta = with lib; {
    description = "OtoMusic desktop player for Navidrome/Subsonic libraries";
    homepage = "https://github.com/Aloys233/OtoMusic";
    platforms = platforms.linux;
    mainProgram = "otomusic";
  };
})
