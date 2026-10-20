# Third Flick candidate: native DRM DMA-BUF registration and import verification

**Build date:** 2026-10-21. **Branch:** flick-gpu-optimization. **Status:** compiled and staged only; no graphical activation.

## Verified build and staging

| Check | Verified result |
| --- | --- |
| Source | Flick 729cdecedad05be3192b21f7d4310eb0ff7ae563 |
| Patch sequence | Six NixOS integration + logging reduction + experimental native DMA-BUF import validation |
| Nix attribute | packages.x86_64-linux.flick-dmabuf-experimental |
| Builder | MacBook Colima VZ/Rosetta, Linux x86_64, Nix 2.28.4, 2 concurrent Rust jobs |
| Release compilation | 23 min 29 sec, 134 compiler warnings, exit code 0 |
| Nix store path | /nix/store/3bbhjcb0f678069dn7l112iazk2ak5wn-flick-unstable-2026-01-04 |
| ELF | 64-bit Linux x86-64 |
| SHA-256 | a049d7b41bcd9939831a94a54e764b437d3c879127ba52670a4d943848b12b2c |
| Nix verification | Store path verified |
| Nix closure | 125 paths |
| Runtime references | Exact match with existing unwrapped Flick package on tablet |
| Executable smoke tests | --help successful on Mac-hosted x86_64 Linux and physical tablet |
| Staging path | /home/alex/lenovo-mvp/builds/flick-dmabuf-experimental-x86_64 |
| Tablet SHA-256 | Exact match |
| Services after staging | Flick, SSH, NetworkManager, seatd active |
| System activation | None, known-good Flick and NixOS boot generation preserved |
| Mac build VM after completion | Stopped; cached build retained |

## Scope and limits

This independent variant uses EGL-reported formats and the matching DRM render node to create a Wayland Linux DMA-BUF protocol global. Import requests are queued in Flick state; the real native GLES renderer attempts importing each buffer before the success or failure notification. Existing SHM remains a fallback, and the separate QML Slint raster-skip patch is excluded.

Nix patched and compiled this source successfully. **This does not prove functional Wayland DMA-BUF import, Intel GPU acceleration in Qt 5, absence of llvmpipe, correct screen composition, or reduced CPU.** The current Qt 5 wayland-egl integration may also need wl_drm, which the original compositor did not advertise.

## Next controlled live-test gates

Before activating any candidate, arrange physical access, an independently working SSH side channel, a time-limited automatic rollback, and preservation of the original Flick binary and boot generation. Changing the only compositor may blank the display. Measure one variant at a time: original, logging-only, then native DRM DMA-BUF. Verify Wayland globals, Qt renderer identification, render-node descriptors, llvmpipe threads, QML lock/unlock, onscreen keyboard, touch and kernel i915 errors, then compare CPU and memory with a repeated idle baseline.

Saved private Mac evidence (ignored from Git): .flick-nix-candidate/dmabuf-build-status.txt, build-dmabuf-release.log, verify-dmabuf-staging.log, and flick-dmabuf-experimental-x86_64. The actual source patch is in patches/flick/0003-native-drm-validated-dmabuf-experimental.patch.
