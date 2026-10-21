{
  description = "Lenovo Gen59 WPE WebKit 2.54 DRM living nebula derived from physically working gen58";
  inputs = {
    golden58.url = "github:drunkod/vlenovo-nixos-tablet/8a422fd?dir=experiments/nextgen-images";
    webPkgs.url = "github:NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe";
    webRecipe.url = "github:eval-exec/nix-wpe-webkit/f00a6fa7b7fe678bba8588edc21e233ac1eedce8";
    webRecipe.inputs.nixpkgs.follows = "webPkgs";
  };
  outputs = { self, golden58, webPkgs, webRecipe, ... }:
    let
      system = "x86_64-linux";
      pkgsWeb = import webPkgs {
        inherit system;
        overlays = [ webRecipe.overlays.default ];
      };
      oldSystem = golden58.nixosConfigurations.slint-kms-gpu;
      oldPkgs = oldSystem.pkgs;
      wpe = pkgsWeb.wpewebkit.overrideAttrs (final: prev: {
        version = "2.54.1";
        # The upstream overlay expects a devdoc output, but this kiosk disables
        # documentation. A missing devdoc would fail the Nix build at the end.
        outputs = [ "out" "dev" ];
        postFixup = "";
        src = pkgsWeb.fetchurl {
          url = "https://wpewebkit.org/releases/wpewebkit-2.54.1.tar.xz";
          hash = "sha256-Dei9+6AR+c1jupqRcfpgON0sCCN4lPQIKru4IfKdP+k=";
        };
        cmakeFlags = prev.cmakeFlags ++ (with pkgsWeb.lib; [
          (cmakeBool "ENABLE_WPE_PLATFORM" true)
          (cmakeBool "ENABLE_WPE_PLATFORM_DRM" true)
          (cmakeBool "ENABLE_WPE_PLATFORM_HEADLESS" true)
          (cmakeBool "ENABLE_WPE_PLATFORM_WAYLAND" false)
          (cmakeBool "ENABLE_WPE_LEGACY_API" false)
          (cmakeBool "ENABLE_DOCUMENTATION" false)
          (cmakeBool "ENABLE_INTROSPECTION" false)
          (cmakeBool "ENABLE_MINIBROWSER" false)
          (cmakeBool "ENABLE_SPEECH_SYNTHESIS" false)
          (cmakeBool "ENABLE_SPELLCHECK" false)
          (cmakeBool "ENABLE_GAMEPAD" false)
          (cmakeBool "ENABLE_WEBXR" false)
          (cmakeBool "ENABLE_API_TESTS" false)
        ]);
        enableParallelBuilding = true;
        NIX_BUILD_CORES = 2;
      });
      webAssets = oldPkgs.runCommand "lenovo-living-nebula-web" { } ''
        mkdir -p $out/share/living-nebula/web
        cp ${./web/viewer.html} $out/share/living-nebula/web/viewer.html
        cp ${./web/controller.html} $out/share/living-nebula/web/controller.html
        cp ${./server.mjs} $out/share/living-nebula/server.mjs
      '';
      kiosk = pkgsWeb.stdenv.mkDerivation {
        pname = "lenovo-wpe-kiosk";
        version = "0.1.0";
        src = ./kiosk.c;
        dontUnpack = true;
        nativeBuildInputs = [ pkgsWeb.pkg-config pkgsWeb.makeWrapper ];
        buildInputs = [ wpe pkgsWeb.glib ];
        buildPhase = ''
          runHook preBuild
          $CC "$src" -o lenovo-wpe-kiosk $(pkg-config --cflags --libs wpe-webkit-2.0 gio-unix-2.0)
          runHook postBuild
        '';
        installPhase = ''
          mkdir -p $out/bin
          install -m755 lenovo-wpe-kiosk $out/bin/lenovo-wpe-kiosk
          wrapProgram $out/bin/lenovo-wpe-kiosk \
            --set-default WPE_PLATFORM drm \
            --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib"
        '';
      };
      module = { config, lib, pkgs, ... }: {
        # Keep the known-working generation-58 direct-KMS Slint executable in
        # the closure as an emergency fallback; do not start it by default.
        systemd.services.lenovo-slint-dashboard.wantedBy = lib.mkForce [ ];
        systemd.services.lenovo-wpe-scene = {
          description = "Lenovo local Nebula scene state (loopback only)";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          environment = {
            HOME = "/home/alex";
            SCENE_BIND = "127.0.0.1";
            SCENE_PORT = "17858";
          };
          serviceConfig = {
            User = "alex";
            Group = "users";
            WorkingDirectory = "${webAssets}/share/living-nebula";
            ExecStart = "${pkgs.nodejs}/bin/node ${webAssets}/share/living-nebula/server.mjs";
            Restart = "on-failure";
            RestartSec = 3;
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            PrivateTmp = true;
            MemoryMax = "200M";
          };
        };
        systemd.services.lenovo-wpe-fallback = {
          description = "Restore gen58 Slint display if WPE cannot start";
          serviceConfig.Type = "oneshot";
          script = "${pkgs.systemd}/bin/systemctl start lenovo-slint-dashboard.service";
        };
        systemd.services.lenovo-wpe-kiosk = {
          description = "Lenovo generation 59 WPE 2.54 DRM living nebula";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-user-sessions.service" "seatd.service" "lenovo-wpe-scene.service" ];
          requires = [ "seatd.service" "lenovo-wpe-scene.service" ];
          conflicts = [ "lenovo-slint-dashboard.service" "flick.service" "getty@tty1.service" "sxmo.service" ];
          unitConfig = {
            OnFailure = "lenovo-wpe-fallback.service";
            StartLimitIntervalSec = 90;
            StartLimitBurst = 3;
          };
          environment = {
            WPE_PLATFORM = "drm";
            HOME = "/home/alex";
            FONTCONFIG_FILE = "/etc/fonts/fonts.conf";
            LIBSEAT_BACKEND = "seatd";
            MESA_LOADER_DRIVER_OVERRIDE = "crocus";
            LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ pkgs.libglvnd pkgs.libgbm ]}:/run/opengl-driver/lib";
            GBM_BACKENDS_PATH = "/run/opengl-driver/lib/gbm";
            LIBGL_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
          };
          serviceConfig = {
            User = "alex";
            Group = "users";
            SupplementaryGroups = [ "video" "input" "seat" "audio" "render" ];
            WorkingDirectory = "/home/alex";
            ExecStart = "${kiosk}/bin/lenovo-wpe-kiosk http://127.0.0.1:17858/viewer";
            Restart = "on-failure";
            RestartSec = 5;
            MemoryHigh = "800M";
            MemoryMax = "950M";
            PAMName = "login";
            TTYPath = "/dev/tty1";
            StandardInput = "tty-fail";
            TTYReset = true;
            TTYVHangup = true;
            TTYVTDisallocate = true;
            StandardOutput = "journal";
            StandardError = "journal";
          };
        };
        # Don't replace gen58's GRUB IA32, kernel, initrd, i915, Mesa stack or ELAN udev.
        boot.loader.grub.forcei686 = lib.mkForce true;
        environment.systemPackages = [ kiosk wpe ];
      };
    in {
      packages.${system} = {
        inherit wpe kiosk webAssets;
        default = kiosk;
      };
      nixosConfigurations.gen59-wpe = oldSystem.extendModules {
        modules = [ module ];
      };
    };
}
