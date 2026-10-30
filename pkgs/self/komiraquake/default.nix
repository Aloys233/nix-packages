{ lib
, stdenv
, fetchFromGitHub
, fetchgit
, cmake
, ninja
, pkg-config
, qt6
, curl
, zlib
, speechd
, gst_all_1
}:

let
  sentryNative = fetchgit {
    url = "https://github.com/getsentry/sentry-native.git";
    rev = "0.12.1";
    fetchSubmodules = true;
    hash = "sha256-PlV+Rqvf5KjeEDsZt9+qcfRwwcLFY0PeUmtLQ87BFrU=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "komiraquake";
  version = "1.3.8";

  # 对应 tag v1.2.3；源码和 sentry-native 都在 Nix 沙箱外预取，构建阶段不联网。
  src = fetchFromGitHub {
    owner = "Aloys233";
    repo = "KomiraQuake-Desktop";
    rev = "f1f5d57c35b049f1f9bf25b6c625172322560b0f";
    hash = "sha256-rZ1royGOpBSewV2gLuFOoHccwj4TgmVSONKn1KZJYD4=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    curl
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwebsockets
    qt6.qtsvg
    qt6.qtmultimedia
    qt6.qtspeech
    speechd
    zlib
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_SENTRY_NATIVE" "${sentryNative}")
  ];

  # 资源在 CMake 里 install 到 share/komiraquake/assets，
  # 与 app_controller.cpp 的运行时回退路径一致，无需额外处理。

  qtWrapperArgs = [
    # QTextToSpeech 后端（libqtexttospeech_speechd）运行期需要 libspeechd。
    "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ speechd ]}"
    # QtMultimedia 的 GStreamer 后端需要能找到解码插件。
    "--prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" [
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav
    ]}"
  ];

  meta = {
    description = "Earthquake early warning and monitoring client";
    homepage = "https://github.com/Aloys233/KomiraQuake-Desktop";
    platforms = lib.platforms.linux;
    mainProgram = "komiraquake";
  };
})
