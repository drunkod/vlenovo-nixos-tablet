{ config, lib, pkgs, ... }:

let
  cfg = config.services.flick;
in
{
  options.services.flick = {
    enable = lib.mkEnableOption "Flick mobile Wayland shell";

    user = lib.mkOption {
      type = lib.types.str;
      default = "alex";
      description = "User that owns the Flick graphical session.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.flick;
      description = "Flick compositor package.";
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start Flick automatically on tty1. Keep false until manual DRM testing succeeds.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics.enable = true;
    services.seatd.enable = true;

    users.users.${cfg.user}.extraGroups = [
      "seat"
      "video"
      "input"
      "audio"
    ];

    environment.systemPackages = with pkgs; [
      cfg.package
      networkmanager
      bluez
      brightnessctl
      pulseaudio
      alsa-utils
      util-linux
      xwayland
    ];

    systemd.services.flick = lib.mkIf cfg.autostart {
      description = "Flick mobile Wayland compositor";
      wantedBy = [ "graphical.target" ];
      after = [
        "systemd-user-sessions.service"
        "seatd.service"
        "NetworkManager.service"
        "sxmo.service"
      ];
      wants = [ "seatd.service" ];
      conflicts = [ "getty@tty1.service" "sxmo.service" ];

      environment = {
        FLICK_BACKEND = "drm";
        LIBSEAT_BACKEND = "seatd";
        QT_QPA_PLATFORM = "wayland";
        RUST_BACKTRACE = "1";
        HOME = "/home/${cfg.user}";
        USER = cfg.user;
      };

      serviceConfig = {
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
        ExecStart = "${cfg.package}/bin/flick";
        User = cfg.user;
        PAMName = "login";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
        TTYVTDisallocate = true;
        StandardInput = "tty-fail";
        StandardOutput = "journal";
        StandardError = "journal";
        Restart = "on-failure";
        RestartSec = "2s";
        SupplementaryGroups = [ "seat" "video" "input" "audio" ];
      };
    };
  };
}
