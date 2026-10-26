{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, wrapGAppsHook3
, makeWrapper
, alsa-lib
, at-spi2-core
, cairo
, cups
, dbus
, expat
, gdk-pixbuf
, glib
, gtk3
, libdrm
, mesa
, libglvnd
, libnotify
, libpulseaudio
, libsecret
, libxkbcommon
, nspr
, nss
, pango
, systemd
, vulkan-loader
, libx11
, libxcomposite
, libxcursor
, libxdamage
, libxext
, libxfixes
, libxi
, libxrandr
, libxrender
, libxtst
, libxcb
, libxshmfence
, zlib
, xdg-utils
}:

let
  version = "1.0.7";

  sources = {
    x86_64-linux = {
      arch = "x64";
      hash = "sha256-hcYVyT4urdWPI0BwZ+AdVFUI8ReFqi6mEVOGBO/gszc=";
    };
  };

  currentSource = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/nano-muse/nanoMuse/releases/download/v${version}/nanoMuse-Desktop-${version}-linux-${currentSource.arch}.deb";
    hash = currentSource.hash;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "nanomuse";
  inherit version src;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    mesa
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libxkbcommon
    nspr
    nss
    pango
    systemd
    vulkan-loader
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
    libxshmfence
    zlib
    stdenv.cc.cc.lib
  ];

  runtimeDependencies = [
    (lib.getLib systemd)
  ];

  dontConfigure = true;
  dontBuild = true;

  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
    "libc.musl-x86_64.so.1"
    "libc.musl-aarch64.so.1"
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/nanomuse
    cp -r opt/nanoMuse/* $out/lib/nanomuse/

    mkdir -p $out/share
    cp -r usr/share/* $out/share/

    # 移除不需要的 doc 目录
    rm -rf $out/share/doc

    mkdir -p $out/bin
    makeWrapper $out/lib/nanomuse/nanomuse-desktop $out/bin/.nanomuse-wrapped \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    # 启动脚本：支持 ~/.config/nanomuse-flags.conf
    cat > $out/bin/nanomuse <<'EOF'
#!${stdenv.shell}
flags_file="''${XDG_CONFIG_HOME:-''${HOME}/.config}/nanomuse-flags.conf"
extra_flags=()
if [ -r "$flags_file" ]; then
  while IFS= read -r flag || [ -n "$flag" ]; do
    flag="$(printf '%s' "$flag" | tr -d '\r')"
    # 去除首尾空白
    flag="$(printf '%s' "$flag" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$flag" in
      ""|\#*) continue ;;
      *) extra_flags+=("$flag") ;;
    esac
  done < "$flags_file"
fi

exec "@wrappedApp@" "''${extra_flags[@]}" "$@"
EOF
    substituteInPlace $out/bin/nanomuse \
      --subst-var-by wrappedApp "$out/bin/.nanomuse-wrapped"
    chmod +x $out/bin/nanomuse

    # 提供 nanomuse-desktop 软链接作为备选名称
    ln -s $out/bin/nanomuse $out/bin/nanomuse-desktop

    # 修复 desktop 文件
    if [ -f $out/share/applications/nanomuse-desktop.desktop ]; then
      substituteInPlace $out/share/applications/nanomuse-desktop.desktop \
        --replace-warn "Exec=/opt/nanoMuse/nanomuse-desktop" "Exec=$out/bin/nanomuse"
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "nanoMuse Desktop built on DeepSeek Harness";
    homepage = "https://github.com/nano-muse/nanoMuse";
    license = licenses.unfree; # 可根据具体 LICENSE 确认
    platforms = [ "x86_64-linux" ];
    mainProgram = "nanomuse";
  };
})
