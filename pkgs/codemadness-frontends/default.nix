# We now use stdenv.lib.fetchgit to fetch from a git repository
{ stdenv, lib, fetchgit, libressl, glibc, ... }:

stdenv.mkDerivation rec {
  pname = "codemadness-frontends";
  version = "unstable-2025-07-08";

  # --- FINAL CHANGE: Use the git:// protocol URL ---
  src = fetchgit {
    url = "git://git.codemadness.org/frontends"; # <--- This is the correct URL
    rev = "dfe9d705355efc8d67dfb40f015f503bc5a089bf";
    # We still need to find the correct hash.
    sha256 = "sha256-auMdqiFuMVkKe9w6naMNGKMl1uitvY0zrv0t6Z3sib0=";
  };

  # --- FIX 1: Use the robust `sed` command instead of `--prepend` ---
  # This inserts the required line at the top of util.c.
  # postPatch = ''
  #   sed -i '1i#include <wchar.h>' util.c
  # '';
  postPatch = ''
    # Remove static linking flags that cause build failures in Nix
    sed -i 's/-static//g' Makefile
    sed -i 's/-static//g' */Makefile || true
    sed -i 's/-static//g' archived/*/Makefile || true
  '';

  buildInputs = [ libressl glibc ];

  makeFlags = [ "RANLIB=${stdenv.cc.targetPrefix}ranlib" ];

  NIX_CFLAGS_COMPILE = "-D_GNU_SOURCE -include wchar.h";

  installPhase = ''
    runHook preInstall

    # First, build the required components
    make youtube
    # make -C archived/reddit

    # Create the destination directory
    install -d $out/bin

    # install -D reddit/cli $out/bin/reddit-cli
    # install -D reddit/gopher $out/bin/reddit-gopher
    # install -D duckduckgo/cli $out/bin/duckduckgo-cli
    # install -D duckduckgo/gopher $out/bin/duckduckgo-gopher

    # Now, install the binaries that we just built
    install -D youtube/cli $out/bin/youtube-cli
    # install -D archived/reddit/cli $out/bin/reddit-cli

    runHook postInstall
  '';

  meta = with lib; {
    description = "Frontends for duckduckgo, reddit, twitch, and youtube";
    homepage = "https://git.codemadness.org/frontends";
    license = licenses.isc;
    platforms = platforms.linux;
    maintainers = with maintainers; [ wentam ];
  };
}