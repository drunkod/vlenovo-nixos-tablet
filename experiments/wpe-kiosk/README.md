# Generation 59 candidate — Living Nebula on WPE WebKit 2.54 DRM

**Work in progress: the WPE build and NixOS image must pass checks before installation.** The physical Lenovo tablet continues to boot its physically touch-verified **NixOS generation 58**. This branch starts from golden git commit `8a422fd`, not the Asterinas VM branch. The requested number **59** will be assigned by NixOS only when a *successful new physical system profile* is registered; do not call this draft an installed generation.

## What changes and what is deliberately unchanged

- New WPE WebKit **2.54.1** HTML/CSS/JS process, official WPEPlatform `WPE_PLATFORM=drm` (no Wayland/GTK/Cog). WPE's DRM backend is the native KMS display owner. Minimal C launcher in `kiosk.c`.
- A tiny **loopback-only** Node scene service serves `web/viewer.html` and subscribable SSE state. It reuses the Mac-tested Living Object animation and phone control API from Git branch `lenovo-gen58-webmcp-living-kiosk` (commit `c05c050`). Tablet page URL: `http://127.0.0.1:17858/viewer`.
- Configured `lenovo-wpe-kiosk.service` with user `alex`, seat/input/video/render groups, tty1 and `seatd`, the existing Mesa Crocus driver environment and GLVND/GBM search path. `lenovo-slint-dashboard.service` retains its binary and can be explicitly started, but is no longer wanted by multi-user boot.
- On repeated WPE service failure, `lenovo-wpe-fallback.service` starts the retained Slint service. Resource controls: browser cgroup `MemoryHigh=800M`, `MemoryMax=950M`; local Node controller `MemoryMax=200M`. These are **proposed recovery guardrails**, not a substitute for an independent live-deployment watchdog.
- The kernel **6.12.36**, initrd, Intel `i915`/Mesa Crocus graphics, ELAN1001 I²C HID touch, Wi-Fi, SSH, 32-bit UEFI/IA32 GRUB `forcei686` and gen58 system module base are preserved from the pinned `golden58` input.
- `web/viewer.html` supports live remote scene changes (modes: breathe/orbit/tide, hue, energy and ripple). `document.modelContext` is feature-detected for browsers implementing the proposed WebMCP draft; this is **not evidence that WPE 2.54 implements WebMCP**.

## Source pins

- Gen58 golden git: `drunkod/vlenovo-nixos-tablet/8a422fd?dir=experiments/nextgen-images`.
- 2026-10-20 Nixpkgs for WPE: `NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe`.
- Nix packaging recipe: `eval-exec/nix-wpe-webkit/f00a6fa7b7fe678bba8588edc21e233ac1eedce8`, adapted from **2.52.3** to **2.54.1**.
- Official 2.54.1 tarball SHA-256: `0de8bdfba011f9cd63ba9a9171fa6038dd2c08237894f4082abbb821f29d3fe9` (`sha256-Dei9+6AR+c1jupqRcfpgON0sCCN4lPQIKru4IfKdP+k=`).
- `flake.lock` pins all transitive inputs. The package overrides are explicit: WPEPlatform DRM+headless ON, legacy libwpe API OFF, Wayland platform OFF, docs/introspection/minibrowser disabled.

## MacBook Linux builder

The authorized Mac has a Colima/Rosetta x86_64 Nix container `vlenovo-flick-nixbuild` using Docker context `colima-vlenovo-flick-build`. Apple Silicon cannot directly build x86_64 Linux programs. The container has ~6 GiB RAM and ~10 GiB initial free disk, so WPE is a **high-risk multi-hour native C++ build**. Nix's dry-run reported **462 cached dependency paths** (~728 MiB download, 2.46 GiB unpacked) and two builds (WPE tarball + WPE itself).

```sh
# In the Mac worktree, sync source into the Linux builder:
docker --context colima-vlenovo-flick-build cp \
  experiments/wpe-kiosk/. vlenovo-flick-nixbuild:/nextgen59-wpe

docker --context colima-vlenovo-flick-build exec vlenovo-flick-nixbuild \
  nix --extra-experimental-features 'nix-command flakes' \
    --option sandbox false --option filter-syscalls false \
    --option max-jobs 2 --option cores 2 \
    build 'path:/nextgen59-wpe#packages.x86_64-linux.wpe' \
    --no-link --print-out-paths -L

# Once the engine builds, separately build the complete system:
docker --context colima-vlenovo-flick-build exec vlenovo-flick-nixbuild \
  nix --extra-experimental-features 'nix-command flakes' \
    --option sandbox false --option filter-syscalls false \
    --option max-jobs 2 --option cores 2 \
    build 'path:/nextgen59-wpe#nixosConfigurations.gen59-wpe.config.system.build.toplevel' \
    --no-link --print-out-paths -L
```

Always check build logs, source integrity, closure size and exact kernel+initrd identity before copying a system closure to the physical tablet. **Do not install a failed or incomplete WPE build.**

## Deployment and acceptance (not automatic)

1. Read-only SSH: assert gen58 is active at `/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4`. Confirm SSH/seatd/NetworkManager/ELAN touch and pre-flight disk free.
2. Build and verify full gen59 Nix store closure **on the Mac**, import only missing immutable paths over SSH and run `nix-store --verify-path` on the tablet.
3. Keep existing GRUB 58/57/56. Prepare **independent 8-minute systemd rollback timer** to restore gen58, *before* any service activation. Test that it can start gen58's Slint service. Add live WPE failure detection/OnFailure fallback.
4. Register the new NixOS profile as generation 59, switch boot menu (no reboot), and run a **watchdog-protected live switch**. Inspect `journalctl -u lenovo-wpe-kiosk`, DRM `card1`, WPE process-tree memory, i915 GPU usage, touch events, 1920×1200 pixels and controller state streaming.
5. If anything fails, restore gen58 and leave 59 unselected; do not reboot into an untested blank screen. If WPE draws correctly and user confirms finger taps/animations, then cold/warm reboot test and potentially accept gen59.
6. After successful hardware acceptance, commit hashes, exact gen59 store paths, runtime benchmarks and rollback instructions to a separate golden branch. **Never delete gen58** before full acceptance.

## Important limitations

- WPE 2.54 direct KMS is supported upstream in general, **not yet on this specific Intel Bay Trail device**. WPE does not promise a low-RAM footprint; unlike Slint, it uses multiple processes.
- Node control is loopback-only. Phone control will require a securely authenticated tunnel or HTTPS proxy; do not place an unencrypted bearer token on an open wireless network.
- The existing Mac-hosted Node demo is *not* the NixOS browser. The NixOS generation is ready **only after building and physical verification**.
- Source code and reproducible configuration in Git are not a byte-for-byte raw partition image; the NixOS system closure is the deployable artifact.
