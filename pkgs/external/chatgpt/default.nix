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
, libusb1
, libxkbcommon
, nspr
, nss
, openssl
, pango
, systemd
, tpm2-tss
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
, xdg-utils
}:

let
  version = "26.1013.31256";

  sources = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-cMzyub94CY57u/3b8e4Zao/dQr63538W3UL6ujZAMyQ=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-FynaC5Vc5fvXq+ToaX8/pYvpVDEByRGMR67UJVm4o5Y=";
    };
  };

  currentSource = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_${currentSource.arch}.deb";
    hash = currentSource.hash;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "chatgpt";
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
    libusb1
    libxkbcommon
    nspr
    nss
    openssl
    pango
    systemd
    tpm2-tss
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
  ];

  runtimeDependencies = [
    (lib.getLib systemd)
    libsecret
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

    mkdir -p $out/lib
    cp -r usr/lib/chatgpt $out/lib/

    mkdir -p $out/share
    cp -r usr/share/* $out/share/

    # 移除不需要的 doc 和 lintian 目录
    rm -rf $out/share/doc $out/share/lintian

    mkdir -p $out/bin
    makeWrapper $out/lib/chatgpt/ChatGPT $out/bin/.chatgpt-wrapped \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libsecret ]} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    # 启动脚本：支持 ~/.config/chatgpt-flags.conf (与 AUR 行为一致)
    cat > $out/bin/chatgpt <<'EOF'
#!${stdenv.shell}
flags_file="''${XDG_CONFIG_HOME:-''${HOME}/.config}/chatgpt-flags.conf"
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
    substituteInPlace $out/bin/chatgpt \
      --subst-var-by wrappedApp "$out/bin/.chatgpt-wrapped"
    chmod +x $out/bin/chatgpt

    # 提供 chatgpt-desktop 软链接作为备选名称
    ln -s $out/bin/chatgpt $out/bin/chatgpt-desktop

    # 修复 desktop 文件
    if [ -f $out/share/applications/chatgpt.desktop ]; then
      substituteInPlace $out/share/applications/chatgpt.desktop \
        --replace-warn "Exec=chatgpt" "Exec=$out/bin/chatgpt" \
        --replace-warn "/usr/bin/chatgpt" "$out/bin/chatgpt"
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "ChatGPT desktop application for Linux (official binary)";
    homepage = "https://chatgpt.com/download";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "chatgpt";
  };
})
