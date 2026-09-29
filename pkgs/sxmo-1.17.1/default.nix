# vlenovo/pkgs/sxmo-1.17.1/default.nix
# This is the "unwrapped" package, as close to upstream as possible.
# *** THE FIX: Accept `pkgs` and custom deps, then use `with`. ***
{ pkgs
, yt-dlp
, codemadness-frontends
}:

# This statement brings all names from `pkgs` into the current scope.
with pkgs;

stdenv.mkDerivation rec {
  pname = "sxmo-utils";
  version = "1.17.1";

  src = fetchFromSourcehut {
    owner = "~mil";
    repo = "sxmo-utils";
    rev = version;
    sha256 = "sha256-RU57qxfIlci0VuN+lAME1hrBt1aRIIxUzWOxkePYxlQ=";
  };

  patches = [
    ./002-remove-setcap.patch
    ./003-remove-problematic-installs.patch
  ];

  passthru.providedSessions = [ "swmo" ];

  # *** FIX: Remove busybox since it conflicts with coreutils ***
  nativeBuildInputs = [ scdoc pkg-config libcap findutils icu coreutils gnused ];
  
  # *** THE FIX: Explicitly define the unpack command. ***
  # This forces the builder to use the full-path GNU coreutils `cp` command,
  # which correctly handles the `--preserve=timestamps` flag. This bypasses
  # any ambiguity with the busybox version in the PATH.
  # unpackCmd = "cp -r ${src} ./source";
  # sourceRoot = "source";

  makeFlags = [
    "DESTDIR=$(out)"
    "PREFIX="
    "OPENRC=0"
  ];

  meta = with lib; {
    description = "Scripts and small C programs that glue the sxmo environment together (unwrapped)";
    homepage = "https://sxmo.org";
    license = licenses.agpl3Only;
    platforms = platforms.linux;
  };
}