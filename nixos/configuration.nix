# This is your system's main configuration file.
{ inputs, outputs, lib, config, ... }:

{
  imports = [
    # Import all the shared settings.
    ./common-configuration.nix

    # Import the module that provides the sxmo-utils service.
    outputs.nixosModules.sxmo-utils
  ];

  # Add the overlays. This is the only part the test can't share.
  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config = {
      allowUnfree = true;
    };
  };

  # Handle the flake registry setup here instead of in common-configuration.nix
  nix.registry = (lib.mapAttrs (_: flake: {inherit flake;})) ((lib.filterAttrs (_: lib.isType "flake")) inputs);

  nix.nixPath = ["/etc/nix/path"];
  environment.etc =
    lib.mapAttrs'
    (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    })
    config.nix.registry;

  # VM-specific settings for your real build
  virtualisation.vmVariant.virtualisation.forwardPorts = [
    { from = "host"; host.port = 2222; guest.port = 22; }
  ];
}