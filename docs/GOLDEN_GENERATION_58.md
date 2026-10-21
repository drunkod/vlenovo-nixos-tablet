# Lenovo Miix 2 10 — golden Slint Direct KMS GPU generation 58

**Frozen verified working configuration.** Recorded on 2026-10-21.
Git branch: `lenovo-gen58-slint-kms-gpu-touch-golden-2026-10-21`.
Previous golden: `lenovo-gen57-touch-gpu-golden-2026-10-21`.

## Physical user acceptance
After the new system booted, the tablet owner **physically confirmed the touchscreen works fine and tap response has improved significantly**. This is separate from the earlier Slint Wayland test. The new running native LinuxKMS Rust/Slint process logged **18** UI callbacks after reboot (help 8, status 5, network 5). The source records these to `/home/alex/lenovo-mvp/native-events.tsv`. Do not confuse confirmation of tapping with untested drag/rotation/suspend.

## Exact system
- NixOS generation **58**, active and boot-verified; boot ID `4dce8da6-52f9-4387-aefc-d7fe6b2c4758`.
- System: `/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4`.
- Slint GPU executable: `/nix/store/3ns0ac33wxqxgrpfkl303h1s6zrww2xy-lenovo-slint-kms-gpu-0.1.0`.
- Kernel: `/nix/store/mifh5p043cma8pbywl2lvlkp1z1bd8i2-linux-6.12.36/bzImage`.
- Initrd: `/nix/store/8hla2afa7n9vgs76l3558wy7gywxv8gv-initrd-linux-6.12.36/initrd`.
- Intel Bay Trail (PCI 8086:0f31), i915 DRM, DSI-1 1920×1200, Mesa EGL/GBM, OpenGL ES Slint `linuxkms-femtovg` with `MESA_LOADER_DRIVER_OVERRIDE=crocus`.
- ELAN1001 I2C HID multitouch, ACPI power D0, udev `/dev/input/by-path/first-touchscreen`; event number may vary on reboot. Slint automatically opened that node.
- **No Flick, Wayland or QML** in the active display session; Rust is the direct fullscreen KMS UI.
- **32-bit UEFI** booting **64-bit x86_64** Linux through GRUB `boot.loader.grub.forcei686`, unchanged kernel and initrd from generation 57.
- SSH, NetworkManager, Wi-Fi, seatd retained. Restore `seat` in `users.users.alex.extraGroups`.
- Necessary EGL runtime fix: include `pkgs.libglvnd` and `pkgs.libgbm` in display service `LD_LIBRARY_PATH` before `/run/opengl-driver/lib`; without these, GPU startup failed.
- The full pinned NixOS flake, Cargo.lock, Rust UI source and deployment logs are in `experiments/nextgen-images/` on this branch, specifically `GENERATION_58_STATUS.md` and `scripts/verify-direct-kms.sh`.

## Remote measured checkpoint (same day)
- Generation 58 Slint service process **PID 884**, **0 restarts** after real GRUB reboot; no failed systemd units.
- Around 08:15 UTC, **1,472 MiB MemAvailable** of 1,866 MiB; per-process PSS about **74 MiB**; idle CPU 0.5–1% sampled after process warmup.
- DRM fdinfo confirmed i915 card1, ~39 MiB allocations; Mesa EGL/GBM/Gallium mapped, no new kernel GPU hangs or reset. A historical i915 panel GPIO-ownership warning remains, but display works.
- GRUB contains entries for 58, 57, 56.

## Complete replayable binary backup

The Git branch is the **source configuration**; it is not itself a multi-gigabyte installer image. MacBook retained the verified gen57 Nix-store NAR archive and the exactly 14 new Nix-store paths that produce generation 58.

1. `~/Documents/Work/vlenovo-nixos-tablet/.local/archives/lenovo-nixos-gen57-store-closure.nar.zst`
   - 1,319 paths. SHA256: `092786817aa043cd61d3380c0579fbe2ad04e55dbfe7249a87b843083a5724a9`
2. `~/Documents/Work/vlenovo-nixos-tablet/.local/archives/lenovo-nixos-gen58-delta-from-gen57.nar.zst`
   - 14 **additional** paths, ~2.95 MiB compressed / 11.8 MiB export.
   - SHA256: `a331f9f2aec5b4ea9bece1b209cd63eceaf84d3da8ee4f27199d0f935f9c8145`
   - Archive verified with `zstd -t` on Mac.
3. This branch tracks full `gen58-store-closure.txt` (1,222 paths) and `gen58-vs-gen57-new-paths.txt` (14 paths).
4. On a **compatible, trusted x86_64 Nix Linux target** (not directly in macOS), import both archives via `zstd -dc FILE | sudo nix-store --import`, verify `sudo nix-store --verify-path SYSTEM_PATH` and compare requisites manifest. These are immutable store snapshots **not** EFI partition or user data dumps.
5. On **this Lenovo tablet only**, with SSH and rollback available, activate via `sudo nix-env -p /nix/var/nix/profiles/system --set SYSTEM_PATH`, `sudo SYSTEM_PATH/bin/switch-to-configuration boot`, then `switch` following safe systemd rollback watchdog practices. This is a replay procedure, not a command to run automatically.

## Recovery
At GRUB choose `NixOS - Configuration 57`; or with SSH:
```sh
sudo nix-env -p /nix/var/nix/profiles/system --switch-generation 57
sudo /nix/var/nix/profiles/system-57-link/bin/switch-to-configuration switch
```
Keep the generation 57 system `/nix/store/14drwqmla8jzr9iinsj4an1shb704xd2-nixos-system-vlenovo-25.05.20250708.88983d4` and generation 56. Do **not** garbage-collect those roots.

## Limitations
This preserves a precise Nix build closure, but not writable state such as secrets, Wi-Fi credentials, EFI NVRAM, personal files or filesystem partitions. Rebuilding without archives may need matching caches, Nix versions and the existing IA32 GRUB outputs in the remote Linux builder. Asterinas kernel experiments must **not** change this golden branch or the tablet's default boot.
