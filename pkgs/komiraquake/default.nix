{ lib
, stdenv
, fetchFromGitHub
, cmake
, ninja
, pkg-config
, qt6
, speechd
, gst_all_1
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "komiraquake";
  version = "1.0.2";

  # 对应 tag v1.0.0；auto-update 会由 tag 解析出 commit 回填 rev/hash。
  src = fetchFromGitHub {
    owner = "Aloys233";
    repo = "KomiraQuake-Desktop";
    rev = "664d7053eab5417576362cc001e0975d2577efb3";
    hash = "sha256-R7zqtrPDNlfOJCVXukHoLA8Xux7+8ikfmoGFJGJ5umo=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwebsockets
    qt6.qtsvg
    qt6.qtmultimedia
    qt6.qtspeech
    speechd
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
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
