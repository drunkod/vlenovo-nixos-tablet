# Lenovo next-generation Rust / Slint / Asterinas OS drafts

**2026-10-21 — experimental development only.** The immutable boot-verified system is on branch `lenovo-gen57-touch-gpu-golden-2026-10-21`. DO NOT install the draft outputs over generation 57 without building and testing them. Keep GRUB generation 56 too.

## Hardware baseline

Lenovo Miix 2 10 (20359): Intel Atom Z3745 **x86_64** on **IA32/32-bit UEFI**; Intel Bay Trail GPU 8086:0f31 with i915, DRM/KMS DSI-1 1920x1200, Mesa Crocus OpenGL, I2C ELAN1001 touchscreen restored via standard driver, Wi-Fi and battery handled by Linux. Preserve `boot.loader.grub.forcei686 = true`, the exact Linux kernel/initrd as gen57, SSH and NetworkManager, and the touchscreen's by-path udev lookup. Do not mistake a different /dev/input/eventN after reboot for lost touch.

## Proposed images and build-readiness

1. **Slint Wayland, compatible fallback (NixOS draft)**: `nixosConfigurations.slint-wayland`. Packages the **tested** native Rust + Slint 1.7.2 app into a Nix derivation and launches it as a service on top of generation-57 Flick/Wayland. Highest hardware compatibility, but maintains Flick's compositor RAM. The existing `mvp/native` binary and code work in the current environment; the new *Nix-build derivation* must still pass a clean x86_64 build.
2. **Slint LinuxKMS software, preferred low-RAM trial (NixOS draft)**: `nixosConfigurations.slint-kms`. Copies the exact native dashboard source, changes Slint's backend to LinuxKMS software with libseat + libinput, and disables Flick so there is **only one DRM master**. DRM dumb buffers are scanned out by kernel i915; the drawing is **CPU software rendering**, not 3D GPU acceleration. This is not the same binary as the successful Wayland dashboard and has NOT passed physical touch/rotation/console tests.
3. **Slint LinuxKMS accelerated EGL, speculative third image (NixOS draft)**: `nixosConfigurations.slint-kms-gpu`. Same directly controlled DSI panel, but `linuxkms-femtovg` with Mesa EGL/GBM and Crocus/OpenGL ES rather than CPU dumb-buffer drawing. A deliberately risky but measurable hypothesis: a direct Rust UI can keep GPU acceleration while eliminating Flick/QML. Requires proving EGL context creation, DSI modesetting, touch rotation, battery idle, and robust rollback.
4. **Asterinas 0.19.0 NixOS, QEMU-only VM artifact (separate alternative kernel)**: `scripts/asterinas-vm.sh`, pinned source tag SHA `c4b7ed575b7b32773475b194d2ad41fb6d03765b`. Upstream `make nixos` and `make run_nixos` build/test the VM. Its 2026 DRM support currently demos **SimpleDRM/DRM dumb buffers with software OpenGL**, not this tablet's physical Intel Valleyview/DSI pipeline. Asterinas is **not** usable as a drop-in `boot.kernelPackages` replacement. Treat as a new kernel research image, not a switchable tablet generation.

The radical *research-only*, yet smaller, direction beyond #2/#3 is **a Rust first-process / initramfs-only appliance**, replacing most Linux userspace with one networked Slint KMS display process. This would need independent DHCP/WPA, system init, secure SSH recovery, runtime clocks, TLS/agent IPC, power and logging; it is **not** an executable fourth image. See `MINIMAL_RUST_INITRAMFS.md`.

## Reproducibility and evaluation

This Nix flake pins the exact golden commit and Nixpkgs revision. On Mac, evaluate using **path:** so files outside git staging are included during experimentation:

```sh
cd experiments/nextgen-images
nix flake lock 'path:.'
nix eval --raw 'path:.#packages.x86_64-linux.native-wayland.drvPath'
nix eval --raw 'path:.#packages.x86_64-linux.native-kms-software.drvPath'
nix eval --raw 'path:.#nixosConfigurations.slint-wayland.config.system.build.toplevel.drvPath'
nix eval --raw 'path:.#nixosConfigurations.slint-kms.config.system.build.toplevel.drvPath'
nix eval --raw 'path:.#nixosConfigurations.slint-kms-gpu.config.system.build.toplevel.drvPath'
```

The Mac itself is aarch64-darwin and **cannot run x86_64-linux binaries natively**. Build in the already proven `colima-vlenovo-flick-build` Linux x86_64 Rosetta container. Copy this folder into it first; don't use a macOS-darwin Nix output. For actual Nix builds in that isolated container use `--option sandbox false --option filter-syscalls false --option max-jobs 2 --option cores 2` because Rosetta fails at seccomp setup. The 32-bit GRUB stage can also fail with `cannot set 32-bit personality`; transfer identical, prebuilt GRUB Nix store paths from gen56/57 to the builder rather than changing `forcei686`.

Build candidate **only** after derivation evaluation succeeds, Cargo feature/lockfile closure is updated, Nix ABI matches, and the golden system output paths remain unchanged. The direct KMS service is not suitable for `nixos-rebuild test` while Flick still owns the DRM seat unless the test uses controlled shutdown and a watchdog rollback. It must never start concurrently with Flick.

## Acceptance gates

- Source reproducibility: Cargo.lock covers newly enabled LinuxKMS/GBM dependencies; Nix derivation builds x86_64; no remote network in build; correct Fontconfig libs.
- NixOS: kernel and initrd paths match gen57, GRUB IA32 remains enabled, /boot has free space, current/proven gen57 available through GRUB, SSH stays active.
- GPU: identify actual DRM connector and card by probing DSI-1 (not hardcoded card1), verify `i915` kernel KMS, direct DRM master, actual Mesa Crocus GPU rendering for EGL variant, no llvmpipe fallback, no kernel GPU resets.
- Touch: `ELAN1001` ACPI D0, evdev touchscreen by-path, libinput in Rust KMS client, actual tap/drag/unlock visual physical test, adjust calibration only if measured necessary.
- Idle: compare PSS, USS, total MemAvailable, background CPU, battery discharge on **same dashboard scene**, 30-second + 5-minute + 1-hour cold/warm measurements. RSS is not additive for shared libraries. Separate memory used to cache files from truly unreclaimable memory.
- Recoverability: independent rollback timer, physical GRUB menu, saved SSH key service, Wi-Fi, suspend/resume, backlight/rotation tests before promotion.

## Current deployment / what is not yet done

No experimental NixOS generation or Asterinas kernel has been installed. A previously compiled **Wayland Slint dashboard** physically worked and logged taps, while gen57's **Flick compositor** is running successfully. LinuxKMS and Asterinas are proposals until build and real-device tests complete. Read `HARDWARE_ACCELERATION_AND_DRIVER_PORT.md` for upstream evidence, blocker ranking, and cost estimates.
