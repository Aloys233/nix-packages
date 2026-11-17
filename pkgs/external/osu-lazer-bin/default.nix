{ lib
, stdenvNoCC
, fetchurl
, appimageTools
, makeWrapper
, nativeWayland ? false
}:

let
  pname = "osu-lazer-bin";
  version = "2026.1117.0";

  sources = {
    x86_64-linux = {
      hash = "sha256-TrvLW1gcA28WeFUAr1yNE60ebZMZb9Nr6PJFwqDqHS0=";
    };
  };

  currentSource = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "osu-lazer-bin: ${stdenvNoCC.hostPlatform.system} is unsupported.");

  src = fetchurl {
    url = "https://github.com/ppy/osu/releases/download/${version}-lazer/osu.AppImage";
    hash = currentSource.hash;
  };
in
appimageTools.wrapType2 (finalAttrs: {
  inherit
    pname
    version
    src
    ;

  extraPkgs = pkgs: with pkgs; [ icu ];

  extraInstallCommands = ''
    . ${makeWrapper}/nix-support/setup-hook
    mv -v $out/bin/${pname} $out/bin/osu!

    wrapProgram $out/bin/osu! \
      ${lib.optionalString nativeWayland "--set SDL_VIDEODRIVER wayland"} \
      --set OSU_EXTERNAL_UPDATE_PROVIDER 1

    install -m 444 -D ${finalAttrs.contents}/osu!.desktop -t $out/share/applications
    for i in 16 32 48 64 96 128 256 512 1024; do
      install -D ${finalAttrs.contents}/osu.png $out/share/icons/hicolor/''${i}x$i/apps/osu.png
    done
  '';

  meta = {
    description = "Rhythm is just a *click* away (AppImage version for score submission and multiplayer)";
    homepage = "https://osu.ppy.sh";
    changelog = "https://osu.ppy.sh/home/changelog/lazer/${version}";
    license = with lib.licenses; [
      mit
      cc-by-nc-40
      unfreeRedistributable # osu-framework contains libbass.so in repository
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [
      gepbird
      stepbrobd
      Guanran928
    ];
    mainProgram = "osu!";
    platforms = [ "x86_64-linux" ];
  };
})
