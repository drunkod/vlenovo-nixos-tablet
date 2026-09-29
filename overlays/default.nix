# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory.
  # This should make `pkgs.sxmo-utils` refer to our wrapped version.
  additions = final: _prev:
    # FIX: We now pass the required `pkgsUnstable` argument here as well.
    # The `final` package set gives us the correct `system` for this context.
    import ../pkgs {
      pkgs = final;
      pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${final.system};
    };

  # This one contains whatever you want to overlay.
  # For now, it's empty, which is correct since 'additions' is handling the override.
  modifications = final: prev: {
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}