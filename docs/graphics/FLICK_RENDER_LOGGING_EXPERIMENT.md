# Flick render-log profiling experiment (isolated branch)

## Goal and scope

Baseline branch: `flick-gpu-optimization` in the NixOS repository, derived from `2e99591`. The separate archived Flick source is at `.local/references/Flick` (revision `ffb8422`, `baseline/flick-jan-2026`). **The reference source may not be byte-for-byte identical to the already-running tablet binary.** Match actual package source before attempting integration.

The first patch is intentionally **log-level-only**: `patches/flick/0001-throttle-render-info-logs.patch` changes 30 informational `info!` messages inside `render_surface` to `debug!`. Warnings and errors, render branches, frame submission, redraw frequency and touch event handling are untouched. At Flick's existing default filter `warn,flick=info`, those repetitive messages would stop being written; they remain available when logging is explicitly set to DEBUG. This reduces log work and may lower CPU and storage writes, but **no runtime benefit has been measured**.

## Live baseline before patch (2026-10-20)

Read-only 5-second samples of the currently running Flick PID 894:

- First sample: file grew **34,348 bytes** in five seconds.
- Repeat with the committed sampler: about **7.1 KB/s**, and **90% of one logical CPU core**. Additional raw evidence in `mvp/native/benchmarks/2026-10-20-flick-render-log-baseline.txt`.
- Current log path: `/home/alex/.local/state/flick/compositor.log.2026-10-20`.
- The dated log was already ~63 MB at inspection. Historical files from Oct 5/6 were ~149/520 MB; do not delete or truncate them as part of this experiment.
- Repeated INFO events include `render_surface`, `Slint render result`, `LockScreen: creating fresh damage tracker for full redraw`, `RENDER BRANCH DEBUG`, and `Lock screen QML app`.
- The older Flick source has an unconditional ~16ms event-loop wake and rendering attempt for each ready surface. It also constructs a fresh damage tracker on lock-screen rendering and copies software-rendered Slint pixel buffers into DRM/GLES render elements. **These are candidate costs**, not yet instrumented with their exact counts/bytes.

## Reproduce measurements safely

From the MacBook, without installing anything on NixOS:

```bash
cd ~/Documents/Work/vlenovo-nixos-tablet/.local/worktrees/vlenovo-flick-gpu-opt
ssh -F ~/.ssh/vlenovo_config vlenovo 'bash -s -- 5' < tools/measure-flick-runtime.sh
```

The sampler reads Flick's PID, CPU jiffies, file size and recent log lines; it does not alter brightness, GPU, services or sensor settings. On a multi-core system 100% is one logical CPU core. It validates the 1–60-second window and reports log rotation as an invalid sample.

## Patch preparation/verification — **not deployed**

```bash
cd ~/Documents/Work/vlenovo-nixos-tablet/.local/references/Flick
git apply --unidiff-zero --check ../../worktrees/vlenovo-flick-gpu-opt/patches/flick/0001-throttle-render-info-logs.patch
```

The initial patch passed Git's check against reconstructed sources but one context-heavy hunk failed in Nix's GNU `patch` phase. The corrected seventh patch uses **30 uniquely targeted, zero-context replacements**, validated with `git apply --unidiff-zero --check` and `patch --dry-run -p1` on the pinned upstream source plus six integration patches. The actual Nix patch phase then applied all 30 hunks and started Cargo release compilation. Do not apply it directly to the shared archived reference tree or overwrite a running binary. For actual testing, make a **separate Flick source worktree** pinned to the current package revision, apply there, compile the candidate separately, and save the binary hash. Before any restart, ensure local access, known-good boot generation, SSH rollback and explicit approval for interrupting the session.

## Next engineering steps

1. Confirm the exact source used for the currently installed Flick Nix store executable. Match the candidate patch to the deployed revision, not merely the archived source.
2. Measure baseline **render_surface call count**, actual `MemoryRenderBuffer::new` count, pixel-copy bytes and page-flip FPS (vsync) with an optional aggregated telemetry counter, disabled by default. Avoid high-frequency logs in instrumentation.
3. Test the log-only patch independently. Compare `log_bytes_per_second` and Flick CPU with several alternating A/B idle and touch workloads; use `intel_gpu_top` to separate Render/3D hardware activity from CPU work. Watch for lost warnings/errors.
4. Only then prototype conditional redraw/damage-driven frame scheduling. Preserve the QML lock screen, touch feedback, keyboard, animations, current DSI 1920×1200 scanout and unlock gestures; do not introduce a generic sleep without damage semantics.
5. Make an explicit decision on storage cleanup only after preservation/consent; old compositor logs are useful debugging evidence. No log rotation changes are in this patch.

**Safety:** no GPIO/ACPI operations, no NixOS activation, no compositor restart, no OS boot changes. The native touchscreen dashboard should remain operational.
