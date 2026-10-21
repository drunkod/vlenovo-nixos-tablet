{
  description = "Isolated x86_64-linux Flick package experiment; does not activate NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-rust.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nixpkgs-rust, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      rustPkgs = nixpkgs-rust.legacyPackages.x86_64-linux;
      rustPlatform = pkgs.makeRustPlatform {
        cargo = rustPkgs.cargo;
        rustc = rustPkgs.rustc;
      };
      flickPackages = pkgs.callPackage ./pkgs/flick { inherit rustPlatform; };
    in {
      # Known-good, logging-only build: remains the default.
      packages.x86_64-linux.flick = flickPackages;
      packages.x86_64-linux.default = flickPackages;

      # Independent experiment. The eighth patch is NOT in the default build.
      packages.x86_64-linux.flick-qml-experimental =
        flickPackages.unwrapped.overrideAttrs (old: {
          patches = old.patches ++ [
            ./patches/flick/0008-skip-qml-obscured-slint-render.patch
          ];
        });

      # Third independent candidate: logging fix + verified native DMA-BUF
      # advertising/import, WITHOUT the QML full-screen raster skip.
      packages.x86_64-linux.flick-dmabuf-experimental =
        flickPackages.unwrapped.overrideAttrs (old: {
          patches = old.patches ++ [
            ./patches/flick/0009-native-drm-validated-dmabuf.patch
          ];
        });

      # Fourth isolated experiment. Existing variants remain unchanged.
      # Includes validated DMA-BUF protocol PLUS wl_drm/Wayland-EGL binding.
      packages.x86_64-linux.flick-qt-egl-experimental =
        flickPackages.unwrapped.overrideAttrs (old: {
          patches = old.patches ++ [
            ./patches/flick/0009-native-drm-validated-dmabuf.patch
            ./patches/flick/0010-enable-qt-wl-drm-egl-import.patch
          ];
        });

      # Fifth isolated combination. All previous variants stay independent.
      # Adds QML-obscured full-frame skip to validated DMA-BUF + wl_drm EGL.
      packages.x86_64-linux.flick-qt-egl-qml-experimental =
        flickPackages.unwrapped.overrideAttrs (old: {
          patches = old.patches ++ [
            ./patches/flick/0008-skip-qml-obscured-slint-render.patch
            ./patches/flick/0009-native-drm-validated-dmabuf.patch
            ./patches/flick/0010-enable-qt-wl-drm-egl-import.patch
          ];
        });

      # Independent NixOS-ready wrapper of the exact fifth source and assets.
      packages.x86_64-linux.flick-qt-egl-qml-system =
        let
          unwrapped = flickPackages.unwrapped.overrideAttrs (old: {
            patches = old.patches ++ [
              ./patches/flick/0008-skip-qml-obscured-slint-render.patch
              ./patches/flick/0009-native-drm-validated-dmabuf.patch
              ./patches/flick/0010-enable-qt-wl-drm-egl-import.patch
            ];
          });
        in pkgs.symlinkJoin {
          name = "flick-qt-egl-qml-system";
          paths = [ unwrapped flickPackages.assets ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram "$out/bin/flick"               --set FLICK_ROOT "$out/share/flick"               --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [
                pkgs.wayland pkgs.libxkbcommon pkgs.libglvnd pkgs.libgbm
              ]}:/run/opengl-driver/lib"
          '';
          passthru = {
            inherit unwrapped;
            assets = flickPackages.assets;
          };
        };

      # Same exact source as fifth production candidate. Deliberately separate
      # derivation that compiles and executes the Rust unit-test harness.
      # Does not modify or activate the previously built package.
      packages.x86_64-linux.flick-qt-egl-qml-tests =
        flickPackages.unwrapped.overrideAttrs (old: {
          patches = old.patches ++ [
            ./patches/flick/0008-skip-qml-obscured-slint-render.patch
            ./patches/flick/0009-native-drm-validated-dmabuf.patch
            ./patches/flick/0010-enable-qt-wl-drm-egl-import.patch
          ];
          doCheck = true;
          cargoTestFlags = [ "--bin" "flick" ];
        });
    };
}
