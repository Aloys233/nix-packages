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
  version = "2.0.0";

  # 尚无 tag，先固定到 main 上的提交；等打了 v2.0.0 再换成 tag = "v${version}"。
  src = fetchFromGitHub {
    owner = "Aloys233";
    repo = "KomiraQuake-Desktop";
    rev = "2cc9e325410e8ec73c9c0ce61d8dac4f4c1af7f6";
    hash = "sha256-n7xQK2enO0C0qwfl9ZdxZEDNPlLJ4YxNN8dkXb0784c=";
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
