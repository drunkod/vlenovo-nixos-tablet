# Experimental Flick QML Slint-render skip — successful offloaded build

**Date:** 2026-10-21 (local); 2026-10-20 UTC. **Branch:** `flick-gpu-optimization`.

## Result and checksum

An independent x86_64 Linux Flick executable with **eight ordered patches** built successfully using MacBook Colima/VZ, Rosetta and Nix 2.28.4. The eighth patch is `patches/flick/0002-skip-qml-obscured-slint-render-experimental.patch`. It conditionally skips a full-screen Slint render/buffer copy only when the existing Qt/QML lock-screen render branch is selected. It retains the prior 30-site INFO→DEBUG patch.

| Verification | Result |
| --- | --- |
| Nix attribute | `packages.x86_64-linux.flick-qml-experimental` |
| Source revision | Flick `729cdecedad05be3192b21f7d4310eb0ff7ae563` + 6 NixOS patches + 2 isolated experiment patches |
| Patch phase | All 8 patches applied cleanly |
| Build process | `cargo build --offline --profile release --target x86_64-unknown-linux-gnu -j 2` through Nix |
| Release time | **22m 16s** (Nix build phase 22m 5s) |
| Nix build result | **exit 0**; install, RPATH fixup and strip passed |
| Warnings | 135 (existing API deprecations/unused return values; no compilation failure) |
| Store output | `/nix/store/bdy6zzkzjrj404j3gav1911zsjbf6399-flick-unstable-2026-01-04` |
| Nix output closure | 125 store paths |
| Direct runtime references | **Identical** to tablet's known-good unwrapped Flick package |
| Binary format | ELF64 x86-64 GNU/Linux PIE, ~38 MiB |
| SHA-256 | `34cf5fa26b25b88f749522a92692f9896c301d84ace73a92dec8bf96074a6e38` |
| Mac staging path | `.flick-nix-candidate/flick-qml-experimental-x86_64` (ignored from Git) |
| Tablet staging path | `/home/alex/lenovo-mvp/builds/flick-qml-experimental-x86_64` |
| Smoke tests | Nix store verification, Linux ELF format, Mac-container `flick --help`, tablet `--help`, matching SHA-256, active essential services |
| Activation | **NOT ACTIVATED**; tablet's running Flick and NixOS generation unchanged |

Source and build instructions: `experiments/flick-build/README.md`. The comparison candidate (logging-only, seventh patch but **without** QML render skip) is independently preserved at `/home/alex/lenovo-mvp/builds/flick-logging-x86_64` (SHA-256 `ad01f34e4576f0b8d6a8254835884758179df40923cb377564c0fc4c7dc2f7f6`).

## Baseline and runtime limits

Before activation, a 10-second read-only sample on the QML lock screen measured **90.3% Flick CPU of one logical core** and **6,565.8 log bytes/s**. Another 10-second log-delta count found **57 full-screen Slint 1920×1200 renders**, **57 matching QML render passes**, and **57 fresh damage trackers**. Each full frame contains 9,216,000 pixels bytes; the clone and memory-buffer copy together imply approximately **105 MB/s of explicit memory writes**, *assuming those two paths copy the entire buffer* at the observed rate. This is a source-based estimate, **not measured bandwidth or measured optimisation speed-up**.

**No runtime CPU saving has yet been measured.** A functional GUI test requires interrupting the current compositor, so it was deliberately deferred pending explicit physical-access and rollback arrangements. The proposed three-condition guard matches the existing QML branch predicate, and the QML keyboard overlay path and Slint `process_events()` were preserved at source level. Neither source inspection nor `--help` verifies graphical correctness.

## Related, separate acceleration discovery

The active QML `qmlscene` currently has four `llvmpipe` threads and lacks a DRM render-node FD. Its Wayland registry advertises neither `zwp_linux_dmabuf_v1` nor `wl_drm`. The active native Flick DRM backend uses EGL/GBM for its own rendering but does not create the DMA-BUF global, unlike its separate hardware-composer backend. This newly verified integration issue may account for Qt Quick's software rendering; **causality is not yet proven**. See `QML_LLVMPIPE_MISSING_DMABUF_2026-10-21.md`. Do not conflate enabling accelerated *client* buffers with the unrelated Slint-rasterization patch compiled here. Proper DMA-BUF import validation is required before protocol promotion.

## Next test sequence

Only with safe physical access, a local recovery method and an explicit authorisation to interrupt Flick: baseline old Flick, activate logging-only candidate temporarily, then activate QML render-skip candidate temporarily. Record several same-state idle samples of CPU, memory and log throughput, touch, keyboard, PIN/unlock, Wayland window composition and i915 resets, reverting immediately on failure. Avoid comparing render-log event counts across INFO/DEBUG builds: the logging patch intentionally suppresses those messages at INFO.

No compositor restart, driver change, kernel change, GPIO/ALS change or NixOS activation was performed as part of compilation/staging.
