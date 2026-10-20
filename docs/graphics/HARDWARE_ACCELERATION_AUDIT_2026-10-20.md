# Lenovo Miix 2 10 — hardware acceleration audit (2026-10-20)

## Decision

**Keep Linux `i915` + Mesa Crocus + legacy Intel i965 VA-API.** The hardware paths already exist and work on the currently booted tablet. Do **not** port the Windows WDDM driver or globally switch Slint to OpenGL just because a GPU is present. The highest-value next engineering work is to reduce Flick's unconditional/duplicate rendering and temporary full-screen CPU buffers, then validate VA-API in actual playback with direct GPU surfaces.

Research and all tests here were non-destructive. No NixOS activation, kernel replacement, driver bind, GPU reset, compositor restart, backlight or sensor-hub action was performed. The existing Rust/Slint dashboard (PID 5302 at inspection) remained running, and touch, SSH, Wi-Fi and Flick remained active.

## Hardware and actual boot

| Check | 2026-10-20 live result |
| --- | --- |
| Machine | Lenovo Miix 2 10 model 20359; Intel Atom Z3745 / Valleyview Gen7 |
| PCI | `8086:0f31`, Lenovo subsystem `17aa:3901` |
| Kernel | Linux 6.12.36, PCI driver `i915` |
| DRM | `/dev/dri/card1` and `/dev/dri/renderD128` |
| Mesa | 25.0.7, `/run/opengl-driver/lib/dri/crocus_dri.so` points into pinned Nix store |
| Live EGL | Mesa Project, EGL 1.5; `Mesa Intel(R) HD Graphics (BYT)` |
| Live OpenGL | 4.2 core and compatibility profiles |
| Live OpenGL ES | 3.0 |
| Fixed-function media | `/run/opengl-driver/lib/dri/i965_drv_video.so` present and working |
| Slint native MVP | `SLINT_BACKEND=winit-software`, ~43,560 KiB RSS, no EGL/Gallium loaded |
| Flick | Actual DRM compositor PID 894 used `/dev/dri/card1` FDs and loaded Mesa EGL 25.0.7 + GBM lib 25.0.1; native DRM source creates EGL/GBM/GLES renderer |
| Boot image | `/nix/store/91jbl1irxi6qjx0252s00mlz8ass3yin-nixos-system-vlenovo-25.05.20250708.88983d4` for both booted and current |

`nix shell nixpkgs#mesa-demos -c eglinfo -B` returned the real Intel GL/ES renderer, not llvmpipe. Some EGL platform initializations are not usable from a headless SSH terminal; usable Intel EGL configurations also appeared. A normal user process is allowed to open render node `renderD128`.

Flick's `shell/src/backend/udev.rs` creates `GbmDevice`, `EGLDisplay`, `EGLContext`, then `GlesRenderer` and `GbmBufferedSurface`. Direct inspection of the running Flick process showed mapped `libEGL_mesa.so` and `libgbm.so` and five open `card1` descriptors. Therefore GPU-capable compositing is **already enabled**; this does not establish how many individual elements still get rasterized and copied on CPU.

## VA-API tested live without overrides

Run from a shell with no `LIBVA_DRIVER_NAME` or `LIBVA_DRIVERS_PATH` overrides:

```sh
nix shell nixpkgs#libva-utils --command \
  vainfo --display drm --device /dev/dri/renderD128
```

Result on this boot: libva 2.22.0, VA-API 1.22, tried `iHD` first (unavailable) and **successfully loaded** `/run/opengl-driver/lib/dri/i965_drv_video.so` automatically. Driver reported: `Intel i965 driver for Intel(R) Bay Trail - 2.4.0.pre1`. It exposed:

- MPEG-2 Simple/Main decode plus encode;
- H.264 Constrained Baseline/Main/High decode plus encode, Stereo High decode;
- VC-1 Simple/Main/Advanced decode;
- JPEG Baseline decode;
- `VAProfileNone : VAEntrypointVideoProc`.

No VP8, VP9, HEVC, or AV1 hardware profile was advertised. Codec mode and profile matter; H.264 10-bit is not H.264 High 8-bit.

**Correction to older project notes:** `docs/graphics/MEDIA-ACCELERATION.md` documented a prior boot/profile in which the i965 driver was missing. That historical observation was valid for that generation. The **currently booted** generation `91jbl1i…` *does* have i965, matching the current source declaration in `nixos/common-configuration.nix`. Do not conflate dates/booted/current/profile. This live check shows driver availability, not that a browser or mpv actually chooses it.

Earlier project benchmarks (`MEDIA-ACCELERATION.md`) showed for a synthetic H.264 1080p30 decode-only workload that direct VA-API averaged 16.0× real time vs 5.5× software (~2.9× throughput), and consumed 1.03 vs 7.44 CPU-seconds (~86% fewer CPU seconds). The Video hardware engine was independently active. Those historical results do **not** guarantee a corresponding FPS, battery-life or browser improvement. Copying decoded frames back to CPU lost much of the gain.

## Native GPU-renderer experiment

The currently running native dashboard is compiled using Slint 1.7.2 with the Winit Wayland software renderer only. The `winit-femtovg` Slint renderer uses OpenGL, whereas `winit-software` uses CPU rendering. An existing Nix binary `slint-viewer 1.11.0` already has both renderers, allowing a safe paired comparison of **the same** static preview file without rebuilding the tablet's compositor.

Tested successively on the current Flick Wayland socket with `timeout 13`, 5-second warmup, `ps`, `smaps_rollup`, and a later 3-second `top` sample. Both stayed open until timeout; no renderer crash. Both logs showed only a short XDG Settings Portal colour-scheme timeout warning.

| Slint 1.11 preview mode | RSS from smaps_rollup | PSS | Private dirty | Second sampled idle CPU |
| --- | ---: | ---: | ---: | ---: |
| `winit-software` | 82,896 KiB | 66,807 KiB | 21,292 KiB | 0.0% |
| `winit-femtovg` (OpenGL) | 218,464 KiB | 200,349 KiB | 92,464 KiB | 0.0% |

The OpenGL viewer loaded Mesa `libEGL_mesa.so` and `libgallium-25.0.7.so`; the software viewer loaded neither. The GPU route worked, but had **~134 MiB more PSS** during this particular comparison, and **no measurable idle-CPU advantage in the last sample**. Startup lifetime CPU was higher for GL; do not equate startup shader allocation to steady-state performance. A short single trial is not a frame-pacing or animation throughput benchmark.

The paired test compared two modes of the **Slint 1.11 viewer**, not the native Slint 1.7 dashboard binary (which remains at ~43–44 MiB RSS). Memory, reuse and behaviour across those versions are not directly equivalent. Do not overgeneralize: GPU rendering may still help animated/scaling/complex content.

Reproducible evidence on Mac:
- `mvp/native/benchmarks/2026-10-20-slint-software-vs-gpu.txt`;
- `mvp/native/benchmarks/2026-10-20-slint-software-top.txt`;
- `mvp/native/benchmarks/2026-10-20-slint-femtovg-top.txt`.

**Recommendation for today's UI:** retain `winit-software` while the dashboard is mostly static. Prototype `renderer-femtovg` as an isolated opt-in Cargo feature/launch mode only after introducing representative animations and repeatable frame-time measurements. Keep a software-only executable and tested startup fallback.

## The likely Flick CPU bottleneck is ABOVE the GPU driver

The archived Flick source `.local/references/Flick/shell/src/backend/udev.rs` already calls Smithay `GlesRenderer` through the Intel EGL/GBM path. At the same time the existing UI compositing helpers around lines 1086, 1611, 1954, 1997, 2101 and 2178 call Slint `request_redraw()`, `render()`, construct fresh `MemoryRenderBuffer` allocations and copy full pixel slices. Its main event loop dispatches with a 16 ms timeout (around 60 potential wakeups/s). This is **a code-level candidate**, not proof every path runs every frame; the preserved reference code must be matched to the binary/source revision before patches are proposed.

At 1920×1200×4 bytes/pixel, one full-screen RGBA buffer is **9,216,000 bytes (~8.79 MiB)**. One full-frame copy at 60 Hz implies ~553 MB/s of memory traffic before other processing, allocation overhead and GPU upload; repeated intermediate copies add more. This is a conditional throughput estimate, **not a measured rate**. GPU-driven final composition does not eliminate unnecessary CPU rasterization of Slint elements or buffer copies.

Live process samples from this project show Flick around 89% of one Atom core and its separate QML lockscreen often around 30% (sometimes higher). The newer native dashboard consumes around 0–10% in sampled intervals. Do not claim that an updated GPU driver will eliminate CPU used by QML or a compositor's event loop.

### Suggested engineering order

1. **Profile, do not switch.** Preserve booted/current/profile generation IDs, record `top`, Flick logs, `intel_gpu_top` GPU Render/3D occupancy, and `perf stat`/flamegraph data if permitted. Instrument counts of Slint redraw calls, frame commits, pixel-buffer allocations and copied bytes, idle vs a controlled swipe. Watch GPU reset/errors and input latency.
2. **Dirty/damage-driven redraw.** Only call `request_redraw` and `render` when data changes, animations require a frame, or the actual UI is dirty. Use Smithay damage helpers and existing DRM damage/compositor flow where supported; preserve correct touch redraws, shell overview and lockscreens.
3. **Cache/reuse buffers.** Rather than `MemoryRenderBuffer::new` and `pixels.clone()` in steady-state loops, investigate persistent buffer ownership/texture uploads, reduced allocation frequency and partial updates. Only introduce DMA-BUF/EGL-image import where it is actually supported and matches the format/modifier constraints of Bay Trail; do not assume a zero-copy path without tracing.
4. **Keep system functional while testing.** Modify an isolated Flick Git branch and build from MacBook where reproducible cross-build support exists. Deploy as a **temporary candidate**, with rollback and physical tablet access. No compositor restart from this research task.
5. **Measure A/B.** Compare idle CPU, RSS/PSS, redraw count, frame delivery, touch latency, glitches, suspend/resume and 1920×1200 DSI panel behaviour. Compare with the same Mesa userspace first; do not confound a compositor redraw fix with a Mesa upgrade.

## Media playback activation without reinstalling drivers

The Intel i965 VA-API driver is already in the active system, so no new graphics-driver NixOS change is required before a **player-level** experiment. For a known H.264 8-bit 4:2:0 test file (start 720p30, then 1080p30), follow the existing `docs/graphics/MEDIA-ACCELERATION.md` workflow and run mpv with direct VA-API and an EGL/Wayland GPU video output, for example:

```bash
mpv --no-config --vo=gpu --gpu-api=opengl --gpu-context=wayland \
  --hwdec=vaapi --hwdec-codecs=h264 --log-file=/tmp/lenovo-h264-vaapi.log \
  -v SAMPLE_H264_8BIT.mp4
```

This is an **example for a user-selected test video**, not a playback run performed in this audit. Confirm `Using hardware decoding (vaapi)` and runtime `hwdec-current=vaapi` and separately watch the Intel Video engine. Do NOT interpret the presence of an i965 library, an OpenGL video renderer or a `--hwdec` option alone as evidence the player decoded on hardware. Compare against `--hwdec=no` with otherwise identical settings, then `vaapi-copy` only as a fallback where zero-copy import is impossible. A software download of every frame can wipe out the benefit.

The i965 VA-API driver is **legacy and archived** by Intel, which stopped maintaining it (including security fixes). It is still the compatible backend for Bay Trail. Do not try to replace it with `iHD` merely because a newer Intel GPU uses that driver. Keep the browser sandbox intact and avoid untrusted codec/stream risk where possible.

## Upstream Mesa/Crocus work

The prior research and archived Mac patches identify Mesa commit `686266d2f1aae3027fd039386c166ce3fadfce7f`: “crocus: Fix shader precompilation on Gen6 and higher”. The patch fixes incorrect precompile-key prediction; it is **not** a general accelerated-video patch or a demonstrated fix for Flick's high CPU. Official Mesa release notes show it in 26.0.6, 26.1.0 and 26.2.0. The present system is Mesa 25.0.7 and may lack the change. The exact source/patches of any candidate build must be verified before deciding whether to backport.

Do a clean paired Mesa25.0.7 base vs Mesa25.0.7 + targeted patch trial with shader caches isolated, then a maintained-version comparison separately if relevant. An app launched under a local `meson devenv` validates **only that app**, not an already-running Flick compositor. A Flick test must confirm the compositor loaded the intended Mesa libraries following a *controlled* restart.

### Separate graphics/panel warning

At 2026-10-20 boot, the i915 kernel log showed `cannot find GPIO chip gpio_crystalcove, deferring` and `Failed to own gpio for panel control`. Nonetheless i915 initialized Valleyview, the screen and touch are functioning, and Mesa OpenGL works. Preserve this as a **distinct DSI/Crystal-Cove power/firmware investigation**, not proof of a GPU acceleration defect. Do not modify PMIC GPIO, ACPI methods or the shared I²C sensor hub during graphics work. The 2026-10-20 touchscreen recovery and older ALS test both show why those devices deserve separate risk controls.

## Project sources / evidence

- `docs/graphics/GPU-BASELINE.md` — historical 3D/DRM baseline; hardware test confirmed 1800–2000 non-vsynced glxgears FPS only as smoke test, GPU engine busy under load, 0 resets.
- `docs/graphics/MEDIA-ACCELERATION.md` — previously successful i965 synthetic H.264 measurements and warnings about downloads/VA-API player verification.
- `docs/graphics/RESEARCH-REVIEW.md` and `PORTING-PLAN.md` — June-2025-author/April-2026-commit Crocus patch chronology, boot-generation safety and Nix store build artifacts.
- `docs/graphics/FLICK_IDLE_CPU_RESEARCH.md`, `.local/references/Flick/shell/src/backend/udev.rs` — source hot-path candidates and measurement gaps.
- `mvp/native/Cargo.toml`, `src/main.rs`, `run-on-tablet.sh` — known-good Slint 1.7 Winit software dashboard, not OpenGL.
- `mvp/native/benchmarks/2026-10-20-slint-*.txt` — raw contemporaneous software/OpenGL viewer snapshots.
- [Slint Winit renderers](https://docs.slint.dev/latest/docs/slint/guide/backends-and-renderers/backend_winit/); [Smithay rendering/damage](https://smithay.github.io/smithay/smithay/backend/renderer/index.html).
- [Mesa 26.0.6 Crocus fix release notes](https://docs.mesa3d.org/relnotes/26.0.6.html), [Mesa 26.1.0](https://docs.mesa3d.org/relnotes/26.1.0.html), [Mesa 26.2.0](https://docs.mesa3d.org/relnotes/26.2.0.html).
- [Intel i965 VA-API driver retirement](https://github.com/intel/intel-vaapi-driver); [mpv current manual](https://mpv.io/manual/stable/).

**Open acceptance:** assess practical hardware video playback and a representative animated dashboard workload; profile and fix unnecessary compositor pixel-buffer work. No OS image or driver replacement is justified by these results.
