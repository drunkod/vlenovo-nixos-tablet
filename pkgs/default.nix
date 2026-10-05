# Custom packages, that can be defined similarly to ones from nixpkgs
{ pkgs, pkgsUnstable, pkgsRust }:

let
  frontends = pkgs.callPackage ./codemadness-frontends { };

  # Keep the NixOS 25.05 package set while using a current Rust toolchain.
  flickRustPlatform = pkgs.makeRustPlatform {
    cargo = pkgsRust.cargo;
    rustc = pkgsRust.rustc;
  };

  # 1. Build the unwrapped package first and give it a name.
  sxmo-utils-unwrapped = pkgs.callPackage ./sxmo-1.17.1 {
    yt-dlp = pkgsUnstable.yt-dlp;
    codemadness-frontends = frontends;
  };
in
{
  codemadness-frontends = frontends;

  flick = pkgs.callPackage ./flick { rustPlatform = flickRustPlatform; };

  # 2. Call the wrapper, passing the unwrapped package and its dependencies to it.
  #    This final, wrapped package is what will be used by your system.
  sxmo-utils = pkgs.callPackage ./sxmo-wrapper {
    # *** THE FIX: Explicitly assign the `frontends` variable ***
    inherit sxmo-utils-unwrapped; # This is fine as the variable name matches the argument name
    codemadness-frontends = frontends; # Assign your `frontends` variable to this argument
    yt-dlp = pkgsUnstable.yt-dlp;
  };
}