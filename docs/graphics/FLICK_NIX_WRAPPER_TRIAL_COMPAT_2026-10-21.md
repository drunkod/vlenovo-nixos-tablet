# Safe candidate wrapper preserving known-good Flick Nix runtime environment

The tablet's active Flick system service starts the known-good wrapped package, not the unwrapped Nix output. Its package launcher is a 33-line bash script with FLICK_ROOT and LD_LIBRARY_PATH assignments (Mesa, libgbm, libGLVND, libxkbcommon and Wayland), followed by the exec of its hidden wrapped binary.

Testing a staged unwrapped candidate by replacing the systemd ExecStart directly could omit this environment, causing failures unrelated to the DRM driver change. An ELF --help smoke test alone would not detect a missing runtime integration.

The tool create-flick-runtime-wrapper.py reads the actual installed wrapper, validates its NixOS shebang and exact single exec line, verifies a pinned SHA-256 and ELF signature for a staged candidate, and atomically writes a user-owned unactivated launcher in the same staging directory. It replaces **only** the known-good binary's final exec path, not the wrapper's environment. It explicitly refuses existing output, symlinks, unsupported path names, missing inputs and mismatched hashes. The paired regression test passed positive and negative cases.

This utility does not alter /etc/systemd, /run/systemd, the running process, the bootloader or the Nix store. The launcher can later be smoke-tested by --help; it must not be used to restart the DRM service until a privileged system-manager rollback has passed an independent rehearsal.
