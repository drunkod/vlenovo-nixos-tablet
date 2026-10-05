{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, clang
, llvmPackages
, seatd
, libinput
, libdrm
, libdisplay-info
, libgbm
, libglvnd
, libxkbcommon
, pixman
, wayland
, wayland-protocols
, systemd
, pam
, fontconfig
, freetype
, liberation_ttf
, dejavu_fonts
, makeFontsConf
, symlinkJoin
, makeWrapper
, stdenvNoCC
, qt5
}:

let
  flick-unwrapped = rustPlatform.buildRustPackage rec {
  pname = "flick";
  version = "unstable-2026-01-04";

  src = fetchFromGitHub {
    owner = "ruapotato";
    repo = "Flick";
    rev = "729cdecedad05be3192b21f7d4310eb0ff7ae563";
    hash = "sha256-1PCrxojPfZd99vf3UMcIrmIlM0dtdK2ubo6o9rOUdIY=";
  };

  patches = [
    ../../patches/flick/0001-enable-native-drm-backend.patch
    ../../patches/flick/0002-add-cargo-lock.patch
    ../../patches/flick/0003-pin-smithay-jan-2026.patch
    ../../patches/flick/0004-refresh-native-drm-backend-api.patch
    ../../patches/flick/0005-handle-new-ui-actions.patch
    ../../patches/flick/0006-fix-native-status-telemetry.patch
  ];

  # Upstream does not currently ship shell/Cargo.lock. Use the lock file
  # generated and reviewed in this repository for reproducible vendoring.
  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "smithay-0.7.0" = "sha256-yURt1QK6pxCxfx9hA7tcyxt6tsdVGW3S0I+sZayJnI4=";
    };
  };

  cargoRoot = "shell";
  buildAndTestSubdir = "shell";

  nativeBuildInputs = [
    pkg-config
    clang
    rustPlatform.bindgenHook
    fontconfig
  ];

  buildInputs = [
    seatd
    libinput
    libdrm
    libdisplay-info
    libgbm
    libglvnd
    libxkbcommon
    pixman
    wayland
    wayland-protocols
    systemd
    pam
    fontconfig
    freetype
  ];

  env = {
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    CARGO_BUILD_JOBS = "2";
    LD_LIBRARY_PATH = lib.makeLibraryPath [
      fontconfig
      freetype
    ];
    FONTCONFIG_FILE = makeFontsConf {
      fontDirectories = [
        liberation_ttf
        dejavu_fonts
      ];
    };
  };

  # cargo-auditable 0.6.5 panics under the Mac's amd64/Rosetta Linux builder
  # after rustc succeeds. Audit metadata is non-essential for runtime; disable it
  # so this x86_64 package remains reproducibly buildable on the offload builder.
  auditable = false;

  doCheck = false;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    flickBin="$(find target -type f -path '*/release/flick' -print -quit)"
    test -n "$flickBin"
    install -m755 "$flickBin" "$out/bin/flick"
    runHook postInstall
  '';

  meta = {
    description = "Flick mobile-first Wayland compositor, native DRM build";
    homepage = "https://github.com/ruapotato/Flick";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "flick";
  };
};

  # Keep the validated Rust compositor derivation unchanged. Package the
  # external QML shell assets separately so UI integration does not trigger
  # another Rust/Smithay rebuild.
  flick-assets = stdenvNoCC.mkDerivation {
    pname = "flick-assets";
    version = flick-unwrapped.version;
    src = flick-unwrapped.src;

    dontConfigure = true;
    dontBuild = true;
    dontWrapQtApps = true;

    nativeBuildInputs = [ qt5.wrapQtAppsHook ];
    buildInputs = [
      qt5.qtbase
      qt5.qtdeclarative
      qt5.qtquickcontrols2
      qt5.qtwayland
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p \
        "$out/share/flick/apps/lockscreen" \
        "$out/share/flick/apps/settings"

      cp -R apps/lockscreen/. "$out/share/flick/apps/lockscreen/"
      install -m755 apps/settings/flick-settings-ctl \
        "$out/share/flick/apps/settings/flick-settings-ctl"
      install -m755 ${./run_lockscreen_nixos.sh} \
        "$out/share/flick/apps/lockscreen/run_lockscreen.sh"

      # The lock-screen QML needs a state directory, but Qt5 qmlscene does not
      # forward arbitrary application arguments. Replace upstream Theme.stateDir
      # references with a tiny per-user singleton generated at runtime from
      # FLICK_STATE_DIR.
      for qml in main.qml MediaControls.qml LockScreen.qml; do
        sed -i '1i import FlickRuntime 1.0' \
          "$out/share/flick/apps/lockscreen/$qml"
        substituteInPlace "$out/share/flick/apps/lockscreen/$qml" \
          --replace-fail "Theme.stateDir" "Runtime.stateDir"
      done

      substituteInPlace "$out/share/flick/apps/lockscreen/run_lockscreen.sh" \
        --replace-fail "@qmlscene@" "${qt5.qtdeclarative.dev}/bin/qmlscene"

      patchShebangs "$out/share/flick/apps"
      runHook postInstall
    '';

    postFixup = ''
      wrapQtApp "$out/share/flick/apps/lockscreen/run_lockscreen.sh"
    '';
  };
in
symlinkJoin {
  name = "flick-${flick-unwrapped.version}";
  paths = [ flick-unwrapped flick-assets ];
  nativeBuildInputs = [ makeWrapper ];

  # Smithay/winit load these at runtime with dlopen(), so ordinary ELF
  # references are not enough for Nix to discover them automatically.
  postBuild = ''
    wrapProgram "$out/bin/flick" \
      --set FLICK_ROOT "$out/share/flick" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ wayland libxkbcommon libglvnd libgbm ]}:/run/opengl-driver/lib"
  '';

  passthru = {
    unwrapped = flick-unwrapped;
    assets = flick-assets;
  };
  meta = flick-unwrapped.meta;
}
