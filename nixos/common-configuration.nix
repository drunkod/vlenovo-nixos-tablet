# This file contains settings shared between the real system and the test VM.
# It does NOT contain overlays, to prevent infinite recursion.
{ config, pkgs, lib, ... }:

{
  # Import your hardware configuration. The test VM will ignore this, which is fine.
  imports = [ ./hardware-configuration.nix ];

  # Remove the nix.registry and nix.nixPath setup from here
  # We'll handle it in the main configuration.nix instead

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
    # This tablet has only 2 GiB RAM. Keep local builds from saturating memory.
    max-jobs = 1;
    cores = 1;
  };

  # Bootloader (will be used by the real build)
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
    forcei686 = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;
  boot.kernelParams = [
    "systemd.mask=systemd-vconsole-setup.service"
    "systemd.mask=dev-tpmrm0.device" #this is to mask that stupid 1.5 mins systemd bug
  ];

  # Low-memory profile: prefer compressed RAM over slow eMMC swap.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
    priority = 100;
  };
  boot.kernel.sysctl."vm.swappiness" = 100;

  # Bound persistent logs and crash dumps so a faulty monitor cannot fill the
  # eMMC or spend minutes compressing thousands of cores again.
  services.journald.extraConfig = ''
    SystemMaxUse=128M
    RuntimeMaxUse=64M
    MaxRetentionSec=7day
  '';
  systemd.coredump.extraConfig = ''
    Storage=external
    MaxUse=128M
    KeepFree=1G
  '';
  # Common settings for both real and test builds
  networking.hostName = "vlenovo";
  networking.networkmanager.enable = true;

  # Sxmo battery/audio monitors expect system services on NixOS.
  services.upower.enable = true;
  services.pulseaudio.enable = true;

  # Bay Trail fixed-function video acceleration. Mesa Crocus already handles
  # 3D; the legacy i965 VA-API driver provides H.264/MPEG-2/VC-1/JPEG media.
  hardware.graphics.extraPackages = with pkgs; [
    intel-vaapi-driver
  ];

  # Bluetooth keyboard support.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # User definition
  users.users.alex = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "input" "video" ];
    shell = pkgs.bash; # Use a standard shell.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIkYD/8JhMZS28UdaztfiN+++vUpSpWdJ3CLyJcs7DFP frisson-10-gusty@icloud.com"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  # Service configuration
  services.xserver.desktopManager.sxmo = {
    enable = true;
    user = "alex";
    group = "users";
    deviceName = "vlenovo";
  };

  # Systemd overrides
  systemd.services."getty@tty1".enable = false;
  systemd.services.sxmo = {
    conflicts = [ "getty@tty1.service" ];
    serviceConfig = {
      TTYPath = lib.mkForce "/dev/tty1";
      UtmpIdentifier = lib.mkForce "tty1";
    };
  };

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-emoji
    nerd-fonts.fira-code
  ];
  fonts.fontconfig.defaultFonts = {
    serif = [ "Noto Serif" ];
    sansSerif = [ "Noto Sans" ];
    monospace = [ "Fira Code Nerd Font" ];
  };

  # Base system packages
  environment.systemPackages = with pkgs; [ git rsync ];

  # SSH service
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # State version
  system.stateVersion = "25.05";
}