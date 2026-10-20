# Fifth Flick build: Qt EGL + DMA-BUF + QML Slint skip

Build on 2026-10-21 from dedicated MacBook Git worktree branch flick-gpu-optimization. The native x86_64 Linux Nix package is a fifth independent candidate, not the active system.

## Verified release result

| Property | Measured / verified |
|---|---|
| Pinned upstream Flick | 729cdecedad05be3192b21f7d4310eb0ff7ae563 |
| Nix attribute | packages.x86_64-linux.flick-qt-egl-qml-experimental |
| Patch stack | Original six integration patches + logging 0007 + QML Slint guard 0008 + validated native DMA-BUF 0009 + wl_drm EGL 0010 |
| Build machine | MacBook Colima VZ Linux x86_64 with Rosetta, Nix 2.28.4 |
| Parallelism | max-jobs=2, cores=2, CARGO_BUILD_JOBS=2, 3 GiB VM swap margin |
| Rust optimised release compile | **20 min 51 sec** |
| Rust warnings | 134 nonfatal warnings |
| Nix build exit code | **0**; patch, Rust build, packaging and fixup succeeded |
| Nix store output | /nix/store/hkkkfh38gpmwk2s2cfbq062ni2xx10jx-flick-unstable-2026-01-04 |
| ELF | Linux x86-64 |
| New package SHA-256 | 4c0d8a75d70f727092522cc82941f12d6421b1b0c44b26e0f7a1a4cbe054006d |
| ELF feature signature | wl_drm EGL binding string found |
| Binary differs from separate Qt EGL-only build | **PASS**; archived comparator hash 361d97fcda198e202540298a23455496cabbaaf70a825a58ae85747b11a72f04 checked |
| Nix integrity | Store path verification passed |
| Runtime direct Nix store references | **Identical** to known-good Flick on tablet |
| Mac Linux --help | Passed |
| Tablet --help | Passed |
| Tablet SHA-256 | Exact match |
| Staged tablet path | /home/alex/lenovo-mvp/builds/flick-qt-egl-qml-experimental-x86_64 |
| Nix-equivalent user-owned launcher | /home/alex/lenovo-mvp/builds/.launch-flick-qt-egl-qml-experimental |
| Launcher smoke test | Passed bash syntax, inherited original FLICK_ROOT/library paths, --help |
| Launcher SHA-256 | 03c4d9c73be4475648feae827d53a31f55d7893c399dd0e99be661448c430e22 |
| Original tablet graphics session | Still running Flick PID 894 |
| Core tablet services | Flick, SSH, NetworkManager and seatd active |
| Boot/NixOS generation changes | None |
| Mac build VM | Stopped after successful staging; build cache retained |

The four prior Nix outputs were re-evaluated and verified to have their exact original store paths. This fifth package is independent and opt-in.

## Source and integration checks

The combined-source regression harness verified all ordered patches apply to the reconstructed pinned native DRM source and that QML Slint suppression has the same predicate as the existing QML-only LockScreen render branch. Slint timer event processing and keyboard overlay remain outside the skipped full-frame Slint raster. It verified Smithay use_system_lib, the GPU-bound wl_drm bind call, actual GPU DMA-BUF importer notification queue and that initial native GPU initialization precedes the first Wayland client request dispatch. The real Qt5 qmlscene process was read-only inspected and DOES use QT_WAYLAND_CLIENT_BUFFER_INTEGRATION=wayland-egl, despite the parent Rust launcher initially setting shm; the shell wrapper overrides this.

All five staged binaries were verified by tools/preflight-flick-graphics-test.sh. See mvp/native/benchmarks/2026-10-21-five-flick-candidate-preflight.txt.

## What remains untested

**No candidate was activated in Flick's real system-level DRM/TTY1 service.** The binary's GPU-import success, availability of wl_drm/zwp_linux_dmabuf_v1 in a real restarted compositor, QML Intel rendering, touch/keyboard/lockscreen, stable buffer handling and actual CPU/power improvements have NOT yet been demonstrated by this package. The private Wayland EGL A/B independently proved wl_drm allowed Intel acceleration, but it had no real compositor window/surface.

Remote Desktop Commander previously blocked the privileged system-manager rehearsal/activation operations. No security command restrictions were relaxed or bypassed. The user-level systemd timer rollback rehearsal passed, but system-level automatic recovery remains unverified. Preserved GRUB generation 55 and its kernel/initrd provide a physical recovery fallback. The active generation and DRM service were left untouched.

Private logs remain ignored in .flick-nix-candidate/build-fifth-combined-release.log, fifth-combined-build-status.txt, verify-fifth-combined-staging.log. Their content and the reproducible Nix attribute are recorded in this project. Later tests should compare against the full 30.1-minute original CPU baseline rather than source-level estimated savings.
