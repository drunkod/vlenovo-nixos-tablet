{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    cargo
    rustc
    rustfmt
    clippy
    pkg-config
    clang
    llvmPackages.libclang

    seatd
    libinput
    libdrm
    libgbm
    libglvnd
    libxkbcommon
    pixman
    wayland
    wayland-protocols
    systemd
    pam
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
  ] + ":/run/opengl-driver/lib";

  CARGO_BUILD_JOBS = "1";
  RUST_BACKTRACE = "1";
}
