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
}:

rustPlatform.buildRustPackage rec {
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

  doCheck = false;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    cp target/release/flick "$out/bin/flick"
    runHook postInstall
  '';

  meta = {
    description = "Flick mobile-first Wayland compositor, native DRM build";
    homepage = "https://github.com/ruapotato/Flick";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "flick";
  };
}
