{ lib
, stdenv
, stdenvNoCC
, curl
, dpkg
, patchelf
, autoPatchelfHook
, wrapGAppsHook3
, makeWrapper
, imagemagick
, cacert
, alsa-lib
, bubblewrap
, cairo
, coreutils
, dbus
, fontconfig
, freetype
, glib
, glib-networking
, gnugrep
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
  version = "4.48.7.27441-1";
  installScriptUrl = "https://uuyc.163.com/install.sh";

  sources = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-e+RW6AEr/MqNDa0IYyZaO9J1bWxMDKe6E8xlwe9kzQA=";
    };
  };

  currentSource = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  # 从官方安装脚本 https://uuyc.163.com/install.sh 解析 RELEASE_PACKAGE_URL 并获取对应的 deb 包
  src = stdenvNoCC.mkDerivation {
    name = "nrd-uuyc_${version}_${currentSource.arch}.deb";

    nativeBuildInputs = [
      curl
      dpkg
    ];

    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = currentSource.hash;

    preferLocalBuild = true;
    impureEnvVars = lib.fetchers.proxyImpureEnvVars;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      install_script="$TMPDIR/install.sh"
      curl --fail --show-error --silent --location --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 60 --retry 2 \
        --output "$install_script" -- "${installScriptUrl}"

      package_url="$(tr -d '\r' < "$install_script" \
        | sed -n "s/^[[:space:]]*RELEASE_PACKAGE_URL=['\"]\([^'\"]*\)['\"][[:space:]]*$/\1/p" \
        | head -n 1)"

      if [ -z "$package_url" ]; then
        echo "错误：未能从 ${installScriptUrl} 中解析出 RELEASE_PACKAGE_URL" >&2
        exit 1
      fi

      if ! printf '%s\n' "$package_url" | grep -Eq '^https://[A-Za-z0-9][A-Za-z0-9.-]*(:[0-9]+)?/[^[:space:]]+$'; then
        echo "错误：解析到的下载链接不合法: $package_url" >&2
        exit 1
      fi

      echo "Fetching uuyc package from $package_url (via ${installScriptUrl})..." >&2
      curl --fail --show-error --location --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 600 --retry 2 \
        --output "$out" -- "$package_url"

      # 校验 deb 包元数据（与官方 install.sh 校验逻辑保持一致）
      pkg_name="$(dpkg-deb -f "$out" Package)"
      pkg_arch="$(dpkg-deb -f "$out" Architecture)"
      pkg_ver="$(dpkg-deb -f "$out" Version)"

      if [ "$pkg_name" != "uuyc" ]; then
        echo "错误：deb 包名不匹配，期望 uuyc，实际 $pkg_name" >&2
        exit 1
      fi
      if [ "$pkg_arch" != "${currentSource.arch}" ]; then
        echo "错误：deb 架构不匹配，期望 ${currentSource.arch}，实际 $pkg_arch" >&2
        exit 1
      fi
      if [ "$pkg_ver" != "${version}" ]; then
        echo "提示：上游最新版本 ($pkg_ver) 与当前声明版本 (${version}) 不同，请同步更新 version 与 hash" >&2
      fi
    '';
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
    patchelf
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

    # uuyc_server 会在安装根目录下创建 config/sensor/{server,client}（需要可写），
    # 这里预留空目录作为 systemd BindPaths 的挂载点
    mkdir -p $out/opt/uuyc/config
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
Environment=PATH=${lib.makeBinPath [ systemd glib dbus coreutils gnugrep ]}:/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin
BindPaths=/var/lib/Netease/uuyc-config:$out/opt/uuyc/config"

    # 编译环境变量补齐共享库，并通过 patchelf 注入到服务组件中
    # 彻底解决 uuyc_service 启动子进程时清空 PATH、丢弃 SSL/D-Bus/GPU 驱动及 NRD_LOG_ROOT 导致的 -100 报错
    cp ${./env_inject.c} $out/opt/uuyc/lib/libuuyc_env_inject.c
    substituteInPlace $out/opt/uuyc/lib/libuuyc_env_inject.c \
      --subst-var-by cacert "${cacert}" \
      --subst-var-by out "$out" \
      --subst-var-by binPath "${lib.makeBinPath [ systemd glib dbus coreutils gnugrep ]}:/run/wrappers/bin:/run/current-system/sw/bin"
    $CC -shared -fPIC -O2 -Wall $out/opt/uuyc/lib/libuuyc_env_inject.c -o $out/opt/uuyc/lib/libuuyc_env_inject.so
    rm $out/opt/uuyc/lib/libuuyc_env_inject.c

    for bin in $out/opt/uuyc/bin/uuyc_server $out/opt/uuyc/bin/uuyc_service $out/opt/uuyc/bin/uuyc_healthd; do
      patchelf --add-needed libuuyc_env_inject.so "$bin"
    done

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
