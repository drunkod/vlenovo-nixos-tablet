# Generation 58 — direct Slint LinuxKMS GPU: candidate, NOT INSTALLED

Date: 2026-10-21. Branch: `lenovo-gen58-slint-direct-kms-gpu-candidate`.

## Exact desired difference from working generation 57

Image attribute: `nixosConfigurations.slint-kms-gpu` in `experiments/nextgen-images/flake.nix`.
- Keep Linux **6.12.36 x86_64**, IA32 firmware GRUB (`boot.loader.grub.forcei686 = true`), kernel i915/DSI, input ELAN1001, seatd, sshd and NetworkManager.
- Disable Flick compositor; run **native Rust Slint 1.7.2** `linuxkms-femtovg` on KMS/GBM/EGL directly. One DRM master. No Wayland or X11 shell required.
- Touch support must be enabled by Slint's `backend-linuxkms` feature with `compat-1-2` (which includes libinput + libseat on this pinned version), and actually tested on hardware. libinput must discover ELAN1001 by udev, not hardcoded `event5`.
- Fallback GRUB 57 (boot-verifiable) and 56 retained. The golden branch and `2.03 GiB` Mac archive are preserved.

## Verification as of this session

- Working physical tablet: `/run/current-system` is **generation 57**, and active Flick, sshd, NetworkManager, seatd were checked. `ELAN1001` D0 and touchscreen symlink pointed to `event5`. Generation 58 **does not exist** yet.
- Linux x86_64 builder: all three experimental `config.system.build.toplevel.drvPath` evaluations previously passed.
- For GPU variant: eval confirms `services.flick.enable=false`, `services.seatd.enable=true`, `SLINT_BACKEND=linuxkms-femtovg`, `boot.loader.grub.forcei686=true`.
- The *exact* kernel path is `/nix/store/mifh5p043cma8pbywl2lvlkp1z1bd8i2-linux-6.12.36` and initrd `/nix/store/8hla2afa7n9vgs76l3558wy7gywxv8gv-initrd-linux-6.12.36`, unchanged from generation 57.
- Previous session successfully built **Wayland** Slint package `/nix/store/aly6mbwhgbfx9bbyq8ki25695yr2f1s6-lenovo-slint-dashboard-0.1.0`. That is *not* the GPU KMS package.

### Blocker from attempted real GPU package build

Command (inside MacBook's Linux x86_64 Colima builder; nothing installed on tablet):

```sh
nix --extra-experimental-features 'nix-command flakes' \
  --option sandbox false --option filter-syscalls false \
  --option max-jobs 2 --option cores 2 \
  build 'path:/nextgen#packages.x86_64-linux.native-kms-gpu' --no-link -L
```

It exited **101** at Cargo offline package resolution:

```text
error: no matching package named `i-slint-renderer-femtovg` found
location searched: directory source .../cargo-vendor-dir
required by package `slint v1.7.2`
```

Root cause: `native-kms/Cargo.toml` adds `gpu = [\"slint/renderer-femtovg\"]` to the earlier software Wayland app, but its copied `Cargo.lock` was not regenerated for that additional feature. It cannot be used as a release image.

Updating lockfile through remote execution hit a safety-control block; do not bypass it. An operator can resolve this explicitly on their device by regenerating `experiments/nextgen-images/native-kms/Cargo.lock` with the already installed Rust 1.98 Cargo, reviewing the dependency diff, syncing updated lockfile into the builder, and rerunning the Nix build. The Rust 1.98 build environment is pinned through `rustNixpkgs` (Nixpkgs commit `a7868a727837f3c09cee2ce0ca671c76b1589fed`).

### Mandatory tests before creating 58

1. GPU Slint binary completes offline Nix build and starts in a controlled seat, opens Intel render node and `/dev/dri/cardN`, uses actual Mesa Crocus renderer (not llvmpipe), renders text with no blank screen.
2. ELAN1001 D0, bound `i2c_hid_acpi/hid-multitouch`, udev symlink and actual physical touch click/drag mapped into the Slint dashboard. Direct-KMS backend wasn't physically tested; existing tests apply only to Wayland.
3. No conflict for DRM master/tty1 with Flick/getty; stop old compositor **only** during controlled switch with out-of-band timer rollback and retained SSH.
4. Full NixOS system closure builds on Mac and is imported to tablet via SSH Nix-store export/import. Verify boot.json, kernel/initrd, 32-bit UEFI GRUB, user accounts, Wi-Fi, SSH, and touchscreen options against 57. Ensure disk/boot space.
5. Set generation 58 using `nix-env -p /nix/var/nix/profiles/system --set ...`; `switch-to-configuration boot`; activate with `switch` only after watchdog. Reboot and physically test, or revert using GRUB 57.

**Do not claim generation 58 has been installed** until the closure and hardware pass the gates. Retain 57 untouched.
