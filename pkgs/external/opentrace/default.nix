{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, wrapGAppsHook3
, makeWrapper
, python3
, zlib
, openssl
, icu
, gtk3
, glib
, glib-networking
, cairo
, pango
, atk
, gdk-pixbuf
, libnotify
, libayatana-appindicator
, webkitgtk_4_1
, libx11
, cacert
, nexttrace
}:

let
  version = "1.5.2";

  sources = {
    x86_64-linux = {
      arch = "x64";
      hash = "sha256-XFxokaj4yD44w8qmGFic93OdJmWt4lD8Xg1TlNKy9nI=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-R1iZ+H1i1RzKjdHN7cEGwL6c6nTbjcrwdNml6wOOAQI=";
    };
  };

  currentSource = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/Archeb/opentrace/releases/download/v${version}/linux-${currentSource.arch}.tar.gz";
    hash = currentSource.hash;
  };

  runtimeLibs = [
    stdenv.cc.cc.lib
    zlib
    (lib.getLib openssl)
    (lib.getLib icu)
    gtk3
    glib
    glib-networking
    cairo
    pango
    atk
    gdk-pixbuf
    libnotify
    libayatana-appindicator
    webkitgtk_4_1
    libx11
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "opentrace";
  inherit version src;

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
    python3
  ];

  buildInputs = runtimeLibs;

  sourceRoot = ".";

  # .NET 单文件 / 自包含发布中的 managed DLL 采用 PE 格式，默认 strip 会损坏 DLL (0x8007000B)
  dontStrip = true;
  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true;

  # libcoreclrtraceptprovider.so 的可选 LTTng 跟踪支持
  autoPatchelfIgnoreMissingDeps = [
    "liblttng-ust.so.0"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/opentrace
    cp -r * $out/lib/opentrace/

    # 1. 解决 WebKitGTK 兼容性：Eto.Gtk 写死依赖 libwebkit2gtk-4.0.so.37，将其软链接至系统的 webkitgtk_4_1
    ln -sf ${webkitgtk_4_1}/lib/libwebkit2gtk-4.1.so.0 $out/lib/opentrace/libwebkit2gtk-4.0.so.37
    ln -sf ${webkitgtk_4_1}/lib/libjavascriptcoregtk-4.1.so.0 $out/lib/opentrace/libjavascriptcoregtk-4.0.so.18

    # 2. 解决 TLS / OpenSSL 运行时加载：在程序根目录软链接 libssl 与 libcrypto，确保 CoreCLR 优先精准定位
    ln -sf ${(lib.getLib openssl)}/lib/libssl.so.3 $out/lib/opentrace/libssl.so.3
    ln -sf ${(lib.getLib openssl)}/lib/libcrypto.so.3 $out/lib/opentrace/libcrypto.so.3
    ln -sf ${(lib.getLib openssl)}/lib/libssl.so $out/lib/opentrace/libssl.so
    ln -sf ${(lib.getLib openssl)}/lib/libcrypto.so $out/lib/opentrace/libcrypto.so

    # 3. 修复上游在 Linux 下的地图与时区 Bug：
    # 上游 Program.cs 中写死判断 TimeZoneInfo.Local.Id == "China Standard Time"，在 Linux 下永远为假（Linux 为 Asia/Shanghai），
    # 导致中国大陆用户首次打开被强制分配被墙的 Google Maps 导致地图黑屏。
    # 通过二进制补丁将该跳转指令改为 pop; nop，使系统语言为中文时默认直选百度地图！
    python3 -c '
    import os
    dll_path = os.path.join(os.environ["out"], "lib", "opentrace", "OpenTrace.dll")
    with open(dll_path, "rb") as f:
        data = bytearray(f.read())
    # 匹配 Program.Main 中的 TimeZoneInfo.Local.Id == "China Standard Time" 跳转指令
    # 28 40 00 00 0a (call TimeZoneInfo::get_Local) ... 72 e9 00 00 70 (ldstr "China Standard Time") 28 3f 00 00 0a (call op_Equality) 2c 24 (brfalse.s)
    pattern = b"\x72\xe9\x00\x00\x70\x28\x3f\x00\x00\x0a\x2c\x24"
    idx = data.find(pattern)
    if idx != -1:
        brfalse_offset = idx + len(pattern) - 2
        data[brfalse_offset] = 0x26     # pop
        data[brfalse_offset + 1] = 0x00 # nop
        with open(dll_path, "wb") as f:
            f.write(data)
        print("[OpenTrace] Successfully patched Linux timezone check in OpenTrace.dll!")
    else:
        print("[OpenTrace] Warning: Timezone pattern not matched, skipping binary patch.")
    '

    # 4. 解决 Ping / Traceroute 权限问题：
    # OpenTrace 优先检测同级目录的 nexttrace。若直接放置无 capability 的二进制，会导致它完全跳过 NixOS 的 setcap 包装器。
    # 因此将自带二进制改名为 nexttrace-unwrapped，并部署智能权限调度分发脚本。
    if [ -f $out/lib/opentrace/nexttrace ]; then
      mv $out/lib/opentrace/nexttrace $out/lib/opentrace/nexttrace-unwrapped
    else
      ln -sf ${nexttrace}/bin/nexttrace $out/lib/opentrace/nexttrace-unwrapped
    fi

    cat > $out/lib/opentrace/nexttrace <<'EOF'
    #!/usr/bin/env bash
    # 1. 优先使用 NixOS 的 setcap wrapper（拥有 cap_net_raw，体验最佳且完全免密码）
    if [ -x "/run/wrappers/bin/nexttrace" ]; then
      exec /run/wrappers/bin/nexttrace "$@"
    fi

    # 2. 若当前已是 root 用户，直接运行原生程序
    if [ "$(id -u)" -eq 0 ]; then
      exec "@unwrappedNexttrace@" "$@"
    fi

    # 3. 检查 PATH 中是否存在带 cap_net_raw 权限的 nexttrace
    IFS=':' read -ra DIRS <<< "$PATH"
    for dir in "''${DIRS[@]}"; do
      if [ -n "$dir" ] && [ -x "$dir/nexttrace" ] && [ "$dir/nexttrace" != "$0" ] && [ "$dir/nexttrace" != "@unwrappedNexttrace@" ]; then
        if command -v getcap >/dev/null 2>&1; then
          if getcap "$dir/nexttrace" 2>/dev/null | grep -q "cap_net_raw"; then
            exec "$dir/nexttrace" "$@"
          fi
        fi
      fi
    done

    # 4. 若参数为版本或帮助查询，直接运行避免不必要的提权
    for arg in "$@"; do
      case "$arg" in
        -V|--version|-h|--help)
          exec "@unwrappedNexttrace@" "$@"
          ;;
      esac
    done

    # 5. 回退方案：直接运行（在 NixOS 下推荐开启 programs.nexttrace.enable 以获得完全免密 raw socket 权限）
    exec "@unwrappedNexttrace@" "$@"
    EOF

    substituteInPlace $out/lib/opentrace/nexttrace \
      --subst-var-by unwrappedNexttrace "$out/lib/opentrace/nexttrace-unwrapped"
    chmod +x $out/lib/opentrace/nexttrace

    # 4. 包装可执行程序
    mkdir -p $out/bin
    makeWrapper $out/lib/opentrace/OpenTrace $out/bin/.opentrace-wrapped \
      "''${gappsWrapperArgs[@]}" \
      --set CLR_ICU_VERSION_OVERRIDE 78 \
      --prefix GIO_EXTRA_MODULES : "${glib-networking}/lib/gio/modules" \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set-default SSL_CERT_DIR "/etc/ssl/certs" \
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1 \
      --set-default WEBKIT_DISABLE_COMPOSITING_MODE 1 \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}:$out/lib/opentrace

    # 5. 创建启动脚本并加入权限友好提示与配置自愈保护
    cat > $out/bin/opentrace <<'EOF'
    #!${stdenv.shell}
    if [ ! -x "/run/wrappers/bin/nexttrace" ] && [ "$(id -u)" -ne 0 ]; then
      echo "[OpenTrace] 提示：在 NixOS 下推荐在配置中添加 'programs.nexttrace.enable = true;' 以获得免密码 ping / traceroute 权限喵~" >&2
    fi

    # 自动自愈修复上游在 Linux 下因 language 初始为空或为 null 导致的偏好设置保存崩溃死锁
    ISO_STORAGE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/IsolatedStorage"
    if [ -d "$ISO_STORAGE_DIR" ]; then
      TARGET_LANG="zh-CN"
      case "''${LANG:-}" in
        *en*|*C*) TARGET_LANG="en" ;;
      esac
      for lang_file in "$ISO_STORAGE_DIR"/*/*/*/*/Files/v2.language; do
        if [ -f "$lang_file" ]; then
          # 若文件为空或已被上游写入 null 序列化标记 (AQIBBFJvb3QBBVZ)，立即自愈修复
          if [ ! -s "$lang_file" ] || grep -q "AQIBBFJvb3QBBVZ" "$lang_file" 2>/dev/null; then
            printf '%s' "$TARGET_LANG" > "$lang_file"
          fi
        fi
      done
    fi

    exec "@wrappedApp@" "$@"
    EOF

    substituteInPlace $out/bin/opentrace \
      --subst-var-by wrappedApp "$out/bin/.opentrace-wrapped"
    chmod +x $out/bin/opentrace

    # 6. 图标与桌面文件
    if [ -f $out/lib/opentrace/icon.png ]; then
      mkdir -p $out/share/icons/hicolor/512x512/apps
      cp $out/lib/opentrace/icon.png $out/share/icons/hicolor/512x512/apps/opentrace.png
      mkdir -p $out/share/pixmaps
      ln -sf $out/share/icons/hicolor/512x512/apps/opentrace.png $out/share/pixmaps/opentrace.png
    fi

    mkdir -p $out/share/applications
    cat > $out/share/applications/opentrace.desktop <<EOF
    [Desktop Entry]
    Name=OpenTrace
    Comment=Open Source Visualized Route Tracing Tool
    Exec=$out/bin/opentrace
    Icon=opentrace
    Terminal=false
    Type=Application
    Categories=Network;Monitor;
    Keywords=traceroute;mtr;network;ping;
    StartupWMClass=OpenTrace
    EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "Open Source Visualized Route Tracing Tool for macOS, Windows, and Linux";
    homepage = "https://github.com/Archeb/opentrace";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "opentrace";
  };
})
