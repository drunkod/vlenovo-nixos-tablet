# /home/alex/Documents/nix-config/vlenovo/modules/nixos/sxmo-utils/default.nix
{ lib, pkgs, config, ... }:

with lib;

let
  # cfg variable to easily access the module's options
  cfg = config.services.xserver.desktopManager.sxmo;
  # sxmopkgs = import ./mix.nix { inherit pkgs; }; # Removed this line
  # codemadness-frontends = pkgs.callPackage ./pkgs/codemadness-frontends {};
in

{
  # environment.systemPackages = [
  #   codemadness-frontends
  # ];

  options.services.xserver.desktopManager.sxmo = {
    enable = mkEnableOption "Sxmo (Simple X Mobile) session started via systemd";

    user = mkOption {
      description = lib.mdDoc "The user to run the Sxmo session for.";
      type = types.str;
      example = "alex";
    };

    group = mkOption {
      description = lib.mdDoc "The primary group for the Sxmo user.";
      type = types.str;
      example = "users";
    };
  };

  # --- CONFIGURATION ---
  # This section is activated only if the user enables the module.
  config = mkIf cfg.enable {

    # Configure logind to let Sxmo's power menu handle power events.
    services.logind.extraConfig = ''
      HandlePowerKey=ignore
      HandlePowerKeyLongPress=poweroff
    '';

    # Set the default boot target to graphical.
    systemd.defaultUnit = "graphical.target";

    # Install Sxmo's udev rules for hardware like LEDs and sensors.
    services.udev.packages = [ pkgs.sxmo-utils ];

    # Ensure the user is in the correct groups to access hardware.
    users.users.${cfg.user}.extraGroups = [ "input" "video" ];

    # Enable doas and configure it with Sxmo's required permissions.
    security.doas.enable = lib.mkDefault true;
    security.doas.extraConfig = builtins.readFile "${pkgs.sxmo-utils}/share/sxmo/configs/doas/sxmo.conf";

    # Megapixels requires this, and bemenu is much more fluent with this
    hardware.graphics.enable = lib.mkDefault true;

    # Disable the standard text login on TTY1 to prevent conflicts.
    console.enable = false;

    # --- The Sxmo systemd Service ---
    # This service starts the entire graphical session.
    systemd.services.sxmo = {
      description = "Sxmo graphical session";
      wantedBy = [ "graphical.target" ];
      
      # This service conflicts with any getty service on tty7.
      conflicts = [ "getty@tty7.service" ];

      serviceConfig = {
        # ExecStartPre = "+${pkgs.sxmo-utils}/bin/sxmo_setpermissions.sh"; # Changed sxmopkgs.sxmo-utils to pkgs.sxmo-utils (though it's commented out)
        ExecStart = "${pkgs.sxmo-utils}/bin/sxmo_winit.sh"; # Changed sxmopkgs.sxmo-utils to pkgs.sxmo-utils
        User = cfg.user;
        Group = cfg.group;

        # CRITICAL: Use the "login" PAM profile. This creates a proper,
        # "seated" user session that systemd-logind recognizes,
        # which is required for Polkit permissions to work.
        PAMName = "login";
        
        WorkingDirectory = "~";
        Restart = "always";
        RestartSec = "2s"; # Add a small delay to prevent rapid-fire crash loops.

        # Standard options to correctly allocate a virtual terminal (VT)
        # to the graphical session. We use tty7 by convention.
        TTYPath = "/dev/tty7";
        TTYReset = "yes";
        TTYVHangup = "yes";
        TTYVTDisallocate = "yes";
        StandardInput = "tty-fail";
        StandardOutput = "journal";
        StandardError = "journal";
        UtmpIdentifier = "tty7";
        UtmpMode = "user";
      };
    };
  };
}