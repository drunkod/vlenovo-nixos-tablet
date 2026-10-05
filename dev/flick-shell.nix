{ pkgs, rustPkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    rustPkgs.cargo
    rustPkgs.rustc
    rustPkgs.rustfmt
    rustPkgs.clippy
    pkg-config
    clang
    llvmPackages.libclang

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
    liberation_ttf
    dejavu_fonts

    networkmanager
    bluez
    util-linux
    alsa-utils
    pulseaudio
    brightnessctl
    pciutils
    usbutils
    evtest
  ];

  LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.libdrm
    pkgs.libgbm
    pkgs.libglvnd
    pkgs.libinput
    pkgs.seatd
    pkgs.libxkbcommon
    pkgs.systemd
    pkgs.fontconfig
    pkgs.freetype
  ] + ":/run/opengl-driver/lib";

  FONTCONFIG_FILE = pkgs.makeFontsConf {
    fontDirectories = [
      pkgs.liberation_ttf
      pkgs.dejavu_fonts
    ];
  };

  CARGO_BUILD_JOBS = "2";
  RUST_BACKTRACE = "1";
}
