{
  lib,
  stdenv,
  rustPlatform,
  buildGoModule,
  go_1_27,
  cmake,
  pkg-config,
  qt6,
  kdePackages,
  makeDesktopItem,
  copyDesktopItems,
  polkit,
}:

let
  pname = "newbee-linux";
  version = "0.1.0";

  linuxSrc = builtins.fetchGit {
    url = "ssh://git@git-ssh.aloys23.link:23333/catchnullpointer/newbee-linux.git";
    rev = "3a470dc53c99083e8ad5af7adb052319d6474d35";
  };

  coreSrc = builtins.fetchGit {
    url = "ssh://git@git-ssh.aloys23.link:23333/catchnullpointer/newbeecore.git";
    rev = "db2062b2d3791e03569960db876ebb1adedb4572";
  };

  kernelSrc = builtins.fetchGit {
    url = "ssh://git@git-ssh.aloys23.link:23333/catchnullpointer/newbeekernel.git";
    rev = "d84644f00f083073fe74c1297e7aba83010b86fc";
    submodules = true;
  };

  core = rustPlatform.buildRustPackage {
    pname = "newbee-core";
    inherit version;
    src = coreSrc;
    cargoLock.lockFile = "${coreSrc}/Cargo.lock";
    cargoBuildFlags = [ "--lib" ];
    doCheck = false;
    installPhase = ''
      runHook preInstall
      coreLibrary="$(find "$NIX_BUILD_TOP" -type f -name libnewbee_core.so -print -quit)"
      test -n "$coreLibrary"
      install -Dm755 "$coreLibrary" "$out/lib/libnewbee_core.so"
      install -Dm644 include/newbee_core.h "$out/include/newbee_core.h"
      runHook postInstall
    '';
  };

  kernel = (buildGoModule.override { go = go_1_27; }) {
    pname = "newbee-kernel";
    inherit version;
    src = kernelSrc;
    vendorHash = "sha256-RZ/e0JNFkhynATx4gj7kkb9LkzM2CkqbNrxHXaS8b54=";
    subPackages = [ "." ];
    tags = [ "with_gvisor" ];
    doCheck = false;
    ldflags = [ "-s" "-w" ];
    overrideModAttrs = old: {
      postPatch = (old.postPatch or "") + ''
        cat >> go.sum <<'EOF'
        golang.org/x/mod v0.41.0 h1:qJmnOUb4YB+FsEuM3HcWucdZASCPGhsX6uljO6pog0c=
        golang.org/x/tools v0.49.0 h1:3NI7VXzL9+1WZD52Dx2ttoPwD5DWrFGpl9mFZDlmisI=
        EOF
      '';
    };
    buildPhase = ''
      runHook preBuild
      mkdir -p "$GOPATH/bin"
      go build -tags with_gvisor -buildvcs=false -ldflags "-s -w" \
        -o "$GOPATH/bin/newbee-kernel" .
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 "$GOPATH/bin/newbee-kernel" "$out/bin/newbee-kernel"
      runHook postInstall
    '';
  };

  desktopItem = makeDesktopItem {
    name = "newbee-linux";
    desktopName = "Newbee";
    exec = "newbee-linux";
    icon = "newbee";
    categories = [ "Network" "Utility" ];
    terminal = false;
    startupNotify = true;
  };
in
stdenv.mkDerivation {
  inherit pname version;
  src = linuxSrc;

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
    copyDesktopItems
  ];
  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    kdePackages.kirigami
  ];

  postPatch = ''
    mkdir -p assets
    cp ${./assets}/* assets/
    substituteInPlace resources.qrc \
      --replace-fail '../[OLD]Newbee/shared/src/commonMain/composeResources/drawable/' 'assets/'
    substituteInPlace CMakeLists.txt \
      --replace-fail 'set(NEWBEE_CORE_DIR "''${CMAKE_CURRENT_SOURCE_DIR}/../NewbeeCore")' \
        'set(NEWBEE_CORE_DIR "''${CMAKE_CURRENT_SOURCE_DIR}/../NewbeeCore" CACHE PATH "NewbeeCore source or install directory")' \
      --replace-fail 'target_link_directories(newbee-linux PRIVATE "''${NEWBEE_CORE_DIR}/target/release")' \
        'target_link_directories(newbee-linux PRIVATE "''${NEWBEE_CORE_DIR}/lib")' \
      --replace-fail 'BUILD_RPATH "''${NEWBEE_CORE_DIR}/target/release"' \
        'BUILD_RPATH "''${NEWBEE_CORE_DIR}/lib"'
  '';

  configurePhase = ''
    runHook preConfigure
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DNEWBEE_CORE_DIR=${core}
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    cmake --build build --parallel "$NIX_BUILD_CORES"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 build/newbee-linux "$out/bin/newbee-linux"
    install -Dm755 ${kernel}/bin/newbee-kernel "$out/bin/newbee-kernel"
    install -Dm755 ${core}/lib/libnewbee_core.so "$out/lib/libnewbee_core.so"
    install -Dm644 assets/newbee_logo_256.png \
      "$out/share/icons/hicolor/256x256/apps/newbee.png"
    runHook postInstall
  '';

  desktopItems = [ desktopItem ];
  qtWrapperArgs = [ "--prefix" "PATH" ":" (lib.makeBinPath [ polkit ]) ];

  meta = {
    description = "Newbee Linux proxy client";
    homepage = "https://git.aloys23.link/catchnullpointer/newbee-linux";
    mainProgram = "newbee-linux";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
