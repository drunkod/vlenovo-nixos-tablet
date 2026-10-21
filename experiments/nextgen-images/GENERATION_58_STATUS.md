# Generation 58 — Slint Direct KMS GPU: installed, booted, remotely verified

Date: 2026-10-21. Repository branch: `lenovo-gen58-slint-direct-kms-gpu-candidate`.
**Actual tablet profile version: 58 (current).** Test results below were collected on the physical Lenovo Miix 2 10, not just in a VM.

## Exact built artifacts

- NixOS system: `/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4`.
- Direct-KMS GPU dashboard: `/nix/store/3ns0ac33wxqxgrpfkl303h1s6zrww2xy-lenovo-slint-kms-gpu-0.1.0`.
- NixOS configuration: `nixosConfigurations.slint-kms-gpu` in `experiments/nextgen-images/flake.nix`; lockfile is pinned in this directory.
- Rust UI uses Slint **1.7.2**, `linuxkms-femtovg` via DRM/KMS, GBM, EGL, OpenGL ES; no Flick/Wayland compositor in the active system.
- Keep Linux kernel `6.12.36`, kernel file `/nix/store/mifh5p043cma8pbywl2lvlkp1z1bd8i2-linux-6.12.36/bzImage` and initrd `/nix/store/8hla2afa7n9vgs76l3558wy7gywxv8gv-initrd-linux-6.12.36/initrd` **exactly unchanged from generation 57**.
- Preserve `boot.loader.grub.forcei686=true`, 32-bit UEFI firmware, 64-bit x86_64 OS, i915/DSI-1, ELAN1001 I2C HID, udev rules, Wi-Fi, SSH and seatd.
- GUI service sets `LIBSEAT_BACKEND=seatd`, `SLINT_BACKEND=linuxkms-femtovg`, `SLINT_DRM_OUTPUT=DSI-1`, `MESA_LOADER_DRIVER_OVERRIDE=crocus`, and the Mesa runtime GBM paths. Its library search path **must include** `pkgs.libglvnd` and `pkgs.libgbm` before `/run/opengl-driver/lib`.
- Explicitly restore `seat` to `users.users.alex.extraGroups`, and give the graphical service supplementary `seat`, `input`, `video`, `audio` groups.

## Build, activation, and reboot evidence

1. Regenerated `native-kms/Cargo.lock` with Rust 1.98; all pinned Slint 1.7.2 LinuxKMS/FemtoVG dependencies resolve.
2. The optimized Rust package built, linked and completed Nix's check/install phases; its Cargo test harness has **zero defined tests**, so this alone is not hardware acceptance.
3. Full x86_64 NixOS closure built on the MacBook's Colima Linux builder, was exported/imported over SSH to the tablet, and passed `nix-store --verify-path`. Full generation 58 closure contains **1,222** paths. Difference from 57: 14 added paths, 111 removed paths at first build.
4. First live attempt failed because `alex` lacked `seat` in generated groups and EGL's libglvnd library could not be found. Automatic rollback restored generation 57 successfully. Controlled experiments under 57 isolated the EGL issue: after adding libglvnd + libgbm paths, the *same* GPU executable logged `Using FemtoVG OpenGL renderer` and `Rendering at 1920x1200` during a 12-second run without Flick.
5. Corrected the NixOS config, built a new system derivation (only five new paths vs first candidate), removed *only* failed profile generation 58 and re-created generation **58** pointing to the corrected system.
6. Protected second live switch succeeded with exit code **0**. Service started with zero restarts, and Flick stopped. After a controlled reboot, GRUB booted generation **58** directly. Fresh boot ID `4dce8da6-52f9-4387-aefc-d7fe6b2c4758`.
7. Booted kernel reported ELAN1001 over I2C HID/multitouch in D0. Udev recognized the touch device with `ID_INPUT_TOUCHSCREEN=1`. Post-reboot device path was `/dev/input/event4` (previously `event5`); the Slint process *automatically opened the new path*.
8. Slint PID **884** opened `/dev/dri/card1` and `/dev/input/event4`. Runtime maps loaded Mesa EGL, GBM, Gallium; process logged FemtoVG OpenGL at **1920x1200**. DRM fdinfo identified **i915**. No GPU hang/reset or failed systemd units observed.
9. Follow-up at 08:08 UTC, >6 minutes after reboot: dashboard active, **NRestarts=0**, SSH/NetworkManager/seatd active; sampled `ps` CPU **0.5%** of a core; process RSS **~78 MiB**, PSS **~74 MiB**, RAM available **~1,487 MiB** out of 1,866 MiB, no swap in use. The postboot verification script also returned **exit code 0** later.

## Touchscreen acceptance boundary

Kernel enumeration, udev classification, live Slint/libinput file-descriptor access, and unchanged working driver **are verified**. **Physical tap, drag, rotation/coordinate mapping, and visual response on this new direct-KMS interface require a person at the tablet**. Do not treat prior touch acceptance on the different Wayland Slint app as confirmation for direct KMS.

## Recovery and reusable test commands

GRUB still offers configurations **58, 57 and 56**. Generation 57 is unchanged at `/nix/store/14drwqmla8jzr9iinsj4an1shb704xd2-nixos-system-vlenovo-25.05.20250708.88983d4`.

To restore 57 live if needed from SSH:
```sh
sudo nix-env -p /nix/var/nix/profiles/system --switch-generation 57
sudo /nix/var/nix/profiles/system-57-link/bin/switch-to-configuration switch
```
To restore it at boot, choose **NixOS - Configuration 57** in the GRUB menu. The temporary automatic rollback timer was stopped after successful live tests, before the reboot; it is **not** a persistent post-reboot watchdog. Do not assume future boots auto-rollback if Slint fails.

Read-only verification from a MacBook:
```sh
cd ~/Documents/Work/vlenovo-nixos-tablet/.local/worktrees/vlenovo-gen58-kms-gpu
cat experiments/nextgen-images/scripts/verify-direct-kms.sh | \
  ssh -T -F ~/.ssh/vlenovo_config vlenovo 'sh -s'
```

Full reproducibility requires the pinned flake/lock/source and available Nix binary caches/build environment. GitHub stores **source + configuration + exact system store IDs**, not a multi-gigabyte disk-image binary. Do not run Nix garbage collection deleting generations 57/58 before recovery testing is finished.
