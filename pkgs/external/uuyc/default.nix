{ lib
, stdenv
, fetchurl
, dpkg
, autoPatchelfHook
, wrapGAppsHook3
, makeWrapper
, imagemagick
, cacert
, alsa-lib
, bubblewrap
, cairo
, dbus
, fontconfig
, freetype
, glib
, glib-networking
, gst_all_1
, gtk3
, libdrm
, libglvnd
, libpulseaudio
, libva
, libx11
, libxcb
, libxcb-image
, libxcb-keysyms
, libxcb-render-util
, libxcb-wm
, libxext
, libxfixes
, libxi
, libxkbcommon
, libxrandr
, libxrender
, libxres
, libxtst
, linux-pam
, mesa
, pipewire
, systemd
, vulkan-loader
, webkitgtk_4_1
, xdg-dbus-proxy
, xdg-utils
, zstd
}:

let
  version = "4.48.4.59255-1";

  sources = {
    x86_64-linux = {
      # 官方标准下载入口（会 302 跳转至对应版本的签名 deb 包，避免带 key1/key2 的临时链接过期）
      url = "https://api.nrd.nie.163.com/api/v1/release/dl/8?channel=gwqd";
      hash = "sha256-70k/8v4ZSuA8BF0mdIacUnfCuEbv2ynpOgInDNZTrwY=";
    };
  };

  currentSource = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  src = fetchurl {
    name = "nrd-uuyc_${version}_amd64.deb";
    url = currentSource.url;
    hash = currentSource.hash;
  };

  # dlopen 动态加载的库以及运行期图形/多媒体依赖，写入各 ELF 的 RUNPATH
  dlopenLibs = map lib.getLib [
    alsa-lib
    dbus
    glib
    libdrm
    libglvnd
    libpulseaudio
    libva
    libx11
    libxcb
    libxext
    libxfixes
    libxrandr
    libxres
    libxtst
    linux-pam
    mesa
    pipewire
    systemd
    vulkan-loader
    webkitgtk_4_1
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "uuyc";
  inherit version src;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
    imagemagick
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
    cairo
    dbus
    fontconfig
    freetype
    glib
    glib-networking
    gtk3
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    libdrm
    libglvnd
    libpulseaudio
    libva
    libx11
    libxcb
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxres
    libxtst
    linux-pam
    mesa
    systemd
    vulkan-loader
    webkitgtk_4_1
    zstd
  ];

  runtimeDependencies = dlopenLibs;

  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true;

  # NVIDIA 编码/解码库按需由宿主机 /run/opengl-driver/lib 提供
  autoPatchelfIgnoreMissingDeps = [
    "libcuda.so.1"
    "libnvcuvid.so.1"
    "libnvidia-encode.so.1"
  ];

  unpackPhase = ''
    runHook preUnpack
    # 避免 dpkg-deb -x 尝试还原 fusermount3 的 setuid 权限位导致沙盒 tar 报错
    dpkg-deb --fsys-tarfile "$src" | tar --no-same-owner --no-same-permissions -xf -
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/uuyc $out/lib/uuyc $out/share $out/bin

    cp -r opt/uuyc/* $out/opt/uuyc/
    cp -r usr/lib/uuyc/* $out/lib/uuyc/
    cp -r usr/share/* $out/share/

    # 移除不需要的 doc 目录
    rm -rf $out/share/doc

    # 确保辅助二进制在 store 中具备常规可执行权限
    chmod 0755 $out/opt/uuyc/libexec/fusermount3

    # 修补辅助脚本内的路径引用
    substituteInPlace $out/opt/uuyc/bin/terminal-launcher/xdg-terminal-exec \
      --replace-warn "/bin/sh" "${stdenv.shell}"

    substituteInPlace $out/lib/uuyc/start-after-install \
      --replace-warn "/usr/bin/systemctl" "systemctl" \
      --replace-warn "/usr/bin/loginctl" "loginctl" \
      --replace-warn "/usr/bin/env" "env" \
      --replace-warn "/usr/sbin/runuser" "runuser" \
      --replace-warn "/usr/lib/uuyc" "$out/lib/uuyc"

    # 修复 systemd unit 文件中的路径，供 NixOS module 或用户会话复用
    mkdir -p $out/lib/systemd/system $out/lib/systemd/user
    cp lib/systemd/system/* $out/lib/systemd/system/
    cp usr/lib/systemd/user/* $out/lib/systemd/user/

    for unit in $out/lib/systemd/system/uuyc.service $out/lib/systemd/user/uuyc-gui.service; do
      substituteInPlace "$unit" \
        --replace-warn "/opt/uuyc" "$out/opt/uuyc"
    done
    # 由 autoPatchelfHook 写入 RUNPATH，不全局导出 LD_LIBRARY_PATH=/opt/uuyc/lib，避免污染系统库与 webkitgtk
    sed -i 's/\r$//' \
      $out/lib/systemd/system/uuyc.service \
      $out/lib/systemd/system/uuyc.socket \
      $out/lib/systemd/user/uuyc-gui.service
    sed -i '/^Environment=LD_LIBRARY_PATH=/d' \
      $out/lib/systemd/system/uuyc.service \
      $out/lib/systemd/user/uuyc-gui.service
    substituteInPlace $out/lib/systemd/system/uuyc.service \
      --replace-warn "Environment=SPA_PLUGIN_DIR=$out/opt/uuyc/lib/spa-0.2" \
      "Environment=SPA_PLUGIN_DIR=$out/opt/uuyc/lib/spa-0.2
Environment=NRD_LOG_ROOT=/var/log/uuyc
Environment=LD_LIBRARY_PATH=/run/opengl-driver/lib
Environment=TERMINFO_DIRS=$out/opt/uuyc/share/terminfo
Environment=SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
Environment=SSL_CERT_DIR=/etc/ssl/certs
Environment=CURL_CA_BUNDLE=${cacert}/etc/ssl/certs/ca-bundle.crt
Environment=PATH=${lib.makeBinPath [ systemd glib dbus ]}:/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin"

    # 提取 .ico 中的 256x256 PNG 图标，提高 Linux 桌面环境图标兼容性
    if [ -f $out/share/icons/hicolor/256x256/apps/uuyc.ico ]; then
      magick "$out/share/icons/hicolor/256x256/apps/uuyc.ico[0]" \
        $out/share/icons/hicolor/256x256/apps/uuyc.png
      mkdir -p $out/share/pixmaps
      ln -sf $out/share/icons/hicolor/256x256/apps/uuyc.png $out/share/pixmaps/uuyc.png
    fi

    # 修复 desktop 文件
    if [ -f $out/share/applications/uuyc.desktop ]; then
      substituteInPlace $out/share/applications/uuyc.desktop \
        --replace-warn "/usr/lib/uuyc/uuyc-gui-session-start" "$out/bin/uuyc" \
        --replace-warn "Icon=/usr/share/icons/hicolor/256x256/apps/uuyc.ico" "Icon=uuyc"
    fi

    # 包装主客户端与 CLI，注意不要将 $out/opt/uuyc/lib 注入 LD_LIBRARY_PATH，以免干扰 webkitgtk_4_1
    makeWrapper $out/opt/uuyc/bin/uuyc $out/bin/.uuyc-wrapped \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils bubblewrap xdg-dbus-proxy dbus glib ]} \
      --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib" \
      --set QT_PLUGIN_PATH "$out/opt/uuyc/plugins" \
      --set-default QT_QPA_PLATFORMTHEME "xdgdesktopportal" \
      --set PIPEWIRE_MODULE_DIR "$out/opt/uuyc/lib/pipewire-0.3" \
      --set PIPEWIRE_CONFIG_PREFIX "$out/opt/uuyc/share/pipewire" \
      --set SPA_PLUGIN_DIR "$out/opt/uuyc/lib/spa-0.2" \
      --set TERMINFO_DIRS "$out/opt/uuyc/share/terminfo" \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set-default SSL_CERT_DIR "/etc/ssl/certs" \
      --set-default CURL_CA_BUNDLE "${cacert}/etc/ssl/certs/ca-bundle.crt"

    cat > $out/bin/uuyc <<'EOF'
#!${stdenv.shell}
# 将日志重定向到用户可写目录，避免写入只读的 /nix/store
if [ -z "''${NRD_LOG_ROOT:-}" ]; then
  export NRD_LOG_ROOT="''${XDG_STATE_HOME:-''${HOME}/.local/state}/uuyc/log"
fi
mkdir -p "$NRD_LOG_ROOT/client/log" "$NRD_LOG_ROOT/webview_host" "$NRD_LOG_ROOT/launcher/log"

# 上游 Qt5 未附带 wayland QPA 插件，Wayland 会话下需回退到 xcb (XWayland)
case "''${QT_QPA_PLATFORM:-}" in
  ""|wayland*) export QT_QPA_PLATFORM="xcb" ;;
esac

# 仅在系统明确运行 ibus 且未配置其他输入法时启用 ibus 插件
if { [ -z "''${QT_IM_MODULE:-}" ] || [ "''${QT_IM_MODULE:-}" = "xim" ]; } \
   && pgrep -u "$(id -u)" -x ibus-daemon >/dev/null 2>&1; then
  export QT_IM_MODULE=ibus
fi

cd "@binDir@" || exit 1
exec "@wrappedApp@" "$@"
EOF
    substituteInPlace $out/bin/uuyc \
      --subst-var-by binDir "$out/opt/uuyc/bin" \
      --subst-var-by wrappedApp "$out/bin/.uuyc-wrapped"
    chmod +x $out/bin/uuyc

    makeWrapper $out/opt/uuyc/bin/uuyc-cli $out/bin/.uuyc-cli-wrapped \
      --set TERMINFO_DIRS "$out/opt/uuyc/share/terminfo" \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set-default SSL_CERT_DIR "/etc/ssl/certs" \
      --set-default CURL_CA_BUNDLE "${cacert}/etc/ssl/certs/ca-bundle.crt"

    cat > $out/bin/uuyc-cli <<'EOF'
#!${stdenv.shell}
if [ -z "''${NRD_LOG_ROOT:-}" ]; then
  export NRD_LOG_ROOT="''${XDG_STATE_HOME:-''${HOME}/.local/state}/uuyc/log"
fi
mkdir -p "$NRD_LOG_ROOT/uuyc-cli/log"
cd "@binDir@" || exit 1
exec "@wrappedApp@" "$@"
EOF
    substituteInPlace $out/bin/uuyc-cli \
      --subst-var-by binDir "$out/opt/uuyc/bin" \
      --subst-var-by wrappedApp "$out/bin/.uuyc-cli-wrapped"
    chmod +x $out/bin/uuyc-cli

    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath "$out/opt/uuyc/lib"
  '';

  meta = with lib; {
    description = "NetEase UU Remote (网易UU远程) remote desktop client for Linux";
    homepage = "https://uuyc.163.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "uuyc";
  };
})
