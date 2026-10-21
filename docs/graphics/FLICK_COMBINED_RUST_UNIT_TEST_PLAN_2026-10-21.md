# Isolated Rust unit-test derivation for fifth Flick candidate

The normal five release packages intentionally have doCheck=false to reduce the burden on the emulated x86_64 Linux builder and avoid unexpectedly executing compositor-related code.

A sixth *test-only derivation*, packages.x86_64-linux.flick-qt-egl-qml-tests, uses exactly the same pinned upstream commit and identical patch stack as the fifth experimental binary. It differs only in doCheck=true and cargoTestFlags selecting the Rust flick binary unit-test harness. The original five compiled derivations, installed tablet files and NixOS generation are untouched.

This run checks Rust binary unit tests (viewport coordinate/scale, touch animation state, word prediction). Those tests do not create a Wayland compositor or acquire DRM/KMS, so they can execute in MacBook's isolated Nix x86_64 Linux Rosetta builder. A Rust test harness run is **not** evidence of graphics hardware runtime correctness. If the unit-test derivation fails, retain logs and investigate without activating it on the tablet.

Build from Mac's persistent Colima container using Nix 2.28.4 with sandbox=false, filter-syscalls=false, max-jobs=2 and cores=2, plus a 3 GiB VM swap margin. Do not switch the tablet's working compositor while building.
