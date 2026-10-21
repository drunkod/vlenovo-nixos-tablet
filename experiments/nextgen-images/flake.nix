{
  description = "Lenovo next-gen Slint image lab (generation 57 stays untouched)";
  inputs = {
    goldenSystem.url = "github:drunkod/vlenovo-nixos-tablet/393a699?dir=experiments/nixos-gpu-generation";
    integration.url = "github:drunkod/vlenovo-nixos-tablet/a3dcc0637b92bff7c30bc8914bda6ee1a3f50281";
    goldenSource = {
      url = "github:drunkod/vlenovo-nixos-tablet/393a699";
      flake = false;
    };
    nixpkgs.url = "github:NixOS/nixpkgs/88983d4b665fb491861005137ce2b11a9f89f203";
  };
  outputs = { self, goldenSystem, integration, goldenSource, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      base = goldenSystem.nixosConfigurations.vlenovo;
      baseDirect = integration.nixosConfigurations.vlenovo;
      nativeDir = goldenSource + "/mvp/native";
      mkNative = { src, features ? [ ], gpu ? false }:
        pkgs.rustPlatform.buildRustPackage {
          pname = if gpu then "lenovo-slint-kms-gpu" else "lenovo-slint-dashboard";
          version = "0.1.0";
          inherit src;
          cargoLock.lockFile = src + "/Cargo.lock";
          cargoBuildFlags = builtins.concatMap (f: [ "--features" f ]) features;
          nativeBuildInputs = with pkgs; [ pkg-config makeWrapper ];
          buildInputs = with pkgs; [
            fontconfig freetype libxkbcommon wayland libinput seatd
            libdrm mesa udev
          ];
          # Slint 1.7.2 loads fontconfig dynamically, keep it in system closure.
          postFixup = ''
            wrapProgram $out/bin/lenovo-native-mvp \
              --set FONTCONFIG_FILE /etc/fonts/fonts.conf \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath (with pkgs; [ fontconfig freetype wayland libxkbcommon libinput seatd libdrm mesa ])}"
          '';
        };
      waylandApp = mkNative { src = nativeDir; };
      kmsApp = mkNative { src = ./native-kms; };
      kmsGpuApp = mkNative { src = ./native-kms; features = [ "gpu" ]; gpu = true; };
      mkService = app: direct: renderer: {
        description = "Lenovo Rust Slint dashboard (experimental)";
        wantedBy = [ "multi-user.target" ];
        after = if direct then [ "seatd.service" "systemd-udev-settle.service" ] else [ "flick.service" ];
        requires = if direct then [ "seatd.service" ] else [ "flick.service" ];
        environment = {
          SLINT_BACKEND = renderer;
          FONTCONFIG_FILE = "/etc/fonts/fonts.conf";
          HOME = "/home/alex";
          RUST_BACKTRACE = "1";
        } // (if direct then {
          LIBSEAT_BACKEND = "seatd";
          SLINT_DRM_OUTPUT = "DSI-1";
        } else {
          XDG_RUNTIME_DIR = "/run/user/1001";
          WAYLAND_DISPLAY = "wayland-1";
        });
        serviceConfig = {
          User = "alex";
          Group = "users";
          WorkingDirectory = "/home/alex";
          ExecStart = "${app}/bin/lenovo-native-mvp";
          Restart = "on-failure";
          RestartSec = 5;
          SupplementaryGroups = [ "input" "video" "seat" ];
        } // (if direct then {
          PAMName = "login";
          TTYPath = "/dev/tty1";
          StandardInput = "tty";
        } else { });
      };
      moduleFor = { app, direct, renderer }: { lib, ... }: {
        services.flick.enable = lib.mkForce (!direct);
        services.flick.autostart = lib.mkForce (!direct);
        services.seatd.enable = lib.mkForce true;
        fonts.fontconfig.enable = true;
        systemd.services.lenovo-slint-dashboard = mkService app direct renderer;
        # Keep kernel/i915, touchscreen udev/ACPI, SSH, Wi-Fi, and GRUB IA32.
        boot.loader.grub.forcei686 = lib.mkForce true;
      };
    in {
      packages.x86_64-linux = {
        native-wayland = waylandApp;
        native-kms-software = kmsApp;
        native-kms-gpu = kmsGpuApp;
      };
      nixosConfigurations = {
        slint-wayland = base.extendModules {
          modules = [ (moduleFor { app = waylandApp; direct = false; renderer = "winit-software"; }) ];
        };
        slint-kms = baseDirect.extendModules {
          modules = [ (moduleFor { app = kmsApp; direct = true; renderer = "linuxkms-software"; }) ];
        };
        # GPU-only direct rendering via EGL/GBM, experimental on Bay Trail.
        slint-kms-gpu = baseDirect.extendModules {
          modules = [ (moduleFor { app = kmsGpuApp; direct = true; renderer = "linuxkms-femtovg"; }) ];
        };
      };
    };
}
