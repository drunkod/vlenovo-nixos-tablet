# Custom packages, that can be defined similarly to ones from nixpkgs
{ pkgs, pkgsUnstable }:

let
  frontends = pkgs.callPackage ./codemadness-frontends { };

  # 1. Build the unwrapped package first and give it a name.
  sxmo-utils-unwrapped = pkgs.callPackage ./sxmo-1.17.1 {
    yt-dlp = pkgsUnstable.yt-dlp;
    codemadness-frontends = frontends;
  };
in
{
  codemadness-frontends = frontends;

  # 2. Call the wrapper, passing the unwrapped package and its dependencies to it.
  #    This final, wrapped package is what will be used by your system.
  sxmo-utils = pkgs.callPackage ./sxmo-wrapper {
    # *** THE FIX: Explicitly assign the `frontends` variable ***
    inherit sxmo-utils-unwrapped; # This is fine as the variable name matches the argument name
    codemadness-frontends = frontends; # Assign your `frontends` variable to this argument
    yt-dlp = pkgsUnstable.yt-dlp;
  };
}