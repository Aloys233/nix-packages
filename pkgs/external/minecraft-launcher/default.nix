{ lib
, stdenv
, fetchurl
, buildFHSEnv
, writeShellScript
, makeDesktopItem
, alsa-lib
, at-spi2-atk
, at-spi2-core
, atk
, cairo
, cups
, curl
, dbus
, expat
, flite
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gtk3
, libGL
, libdrm
, libgbm
, libglvnd
, libgpg-error
, libpulseaudio
, libsecret
, libuuid
, libxkbcommon
, mesa
, nspr
, nss
, openal
, openssl
, pango
, systemd
, udev
, vulkan-loader
, which
, xdg-utils
, libx11
, libxcomposite
, libxcursor
, libxdamage
, libxext
, libxfixes
, libxi
, libxrandr
, libxrender
, libxscrnsaver
, libxtst
, libxcb
, libxshmfence
, libxxf86vm
, zlib
}:

let
  pname = "minecraft-launcher";
  version = "2.1.3";

  src = fetchurl {
    url = "https://launcher.mojang.com/download/Minecraft.tar.gz";
    hash = "sha256-aVJpKBVHu7z0f+dGMwJ6Dk3cE6YQYMaGpyF+hdMU5F4=";
  };

  icon = fetchurl {
    url = "https://launcher.mojang.com/download/minecraft-launcher.svg";
    hash = "sha256-NcK8rrCfpLiGTpQi/Wa/YIR3Bvi0QA7EpmumQ2sQH3E=";
  };

  unwrapped = stdenv.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version src;

    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      if [ -f minecraft-launcher ]; then
        install -Dm755 minecraft-launcher $out/bin/minecraft-launcher
      else
        install -Dm755 */minecraft-launcher $out/bin/minecraft-launcher
      fi
      runHook postInstall
    '';
  };

  desktopItem = makeDesktopItem {
    name = "minecraft-launcher";
    desktopName = "Minecraft Launcher";
    genericName = "Minecraft Launcher";
    comment = "Official Minecraft Launcher";
    icon = "minecraft-launcher";
    exec = "minecraft-launcher %u";
    categories = [ "Game" "Application" ];
    startupNotify = true;
  };

  runScript = writeShellScript "minecraft-launcher-bootstrap" ''
    # 解决 Mojang MCL-25003 / KDE 501866 CEF 缓存崩溃问题（与 AUR 一致）
    cef_version_file="$HOME/.minecraft/webcache2/CEF_VERSION"
    if [ -e "$cef_version_file" ]; then
      rm -f "$cef_version_file"
    fi

    # 确保自动下载的核心模块具有执行权限
    if [ -d "$HOME/.minecraft/launcher" ]; then
      chmod +x "$HOME/.minecraft/launcher/liblauncher.so" "$HOME/.minecraft/launcher/minecraft-launcher" 2>/dev/null || true
    fi

    # 强制使用 X11 (XWayland) 后端，防止 CEF 窗口嵌入与 GTK 在 Wayland 环境崩溃
    export GDK_BACKEND=x11

    exec minecraft-launcher "$@"
  '';
in
buildFHSEnv {
  inherit pname version;

  targetPkgs = pkgs: with pkgs; [
    unwrapped
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curl
    dbus
    expat
    flite
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libGL
    libdrm
    libgbm
    libglvnd
    libgpg-error
    libpulseaudio
    libsecret
    libuuid
    libxkbcommon
    mesa
    nspr
    nss
    openal
    openssl
    pango
    stdenv.cc.cc.lib
    systemd
    udev
    vulkan-loader
    which
    xdg-utils
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxtst
    libxcb
    libxshmfence
    libxxf86vm
    zlib
  ];

  inherit runScript;

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/symbolic/apps
    mkdir -p $out/share/icons/hicolor/scalable/apps
    mkdir -p $out/share/pixmaps

    install -Dm644 ${icon} $out/share/icons/hicolor/symbolic/apps/minecraft-launcher.svg
    install -Dm644 ${icon} $out/share/icons/hicolor/scalable/apps/minecraft-launcher.svg
    install -Dm644 ${icon} $out/share/pixmaps/minecraft-launcher.svg
    install -Dm644 ${desktopItem}/share/applications/* $out/share/applications/

    ln -s $out/bin/minecraft-launcher $out/bin/minecraft-launcher.sh
  '';

  meta = with lib; {
    description = "Official Minecraft Launcher";
    homepage = "https://mojang.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "minecraft-launcher";
  };
}
