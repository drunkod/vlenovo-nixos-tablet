# Lenovo Miix 2 10 graphics baseline

This document records the known-good graphics state before any i915 or Mesa experiments.

## Hardware identity

- Machine: Lenovo Miix 2 10, DMI product 20359.
- CPU: Intel Atom Z3745 (Bay Trail).
- GPU: Intel Atom Z36xxx/Z37xxx Series Graphics & Display.
- PCI ID: `8086:0f31`, revision `0d`.
- PCI subsystem: Lenovo `17aa:3901`.
- Linux i915 platform name: `VALLEYVIEW`.
- Graphics/display generation: 7.
- Internal panel connector: `DSI-1`.
- Native panel mode: 1920x1200 at 60 Hz.
- Panel physical size reported by i915: 216x135 mm.

## Current kernel/display driver

- Kernel at baseline: Linux 6.12.36.
- Kernel driver: `i915`.
- `CONFIG_DRM_I915=m`.
- The device does not require `force_probe`.
- Runtime power management is enabled.
- RC6 and RPS are reported supported.
- Baseline i915 GPU reset count: 0.
- Baseline `i915_error_state`: empty.

## Current Mesa userspace

A live `glxinfo -B` probe reported:

- Mesa 25.0.7.
- DRI driver selected for PCI `8086:0f31`: `crocus`.
- Direct rendering: yes.
- Accelerated: yes.
- Renderer: `Mesa Intel(R) HD Graphics (BYT)`.
- OpenGL core profile: 4.2.
- OpenGL ES: 3.0.
- Unified graphics memory reported: 1536 MB.

This proves the tablet is not using llvmpipe or a generic framebuffer for 3D.
The existing project goal is therefore to improve the upstream i915/Crocus path,
not to replace it with a port of Lenovo's Windows WDDM driver.

At this baseline, the system graphics-driver path did not contain Intel's
`i965_drv_video.so`, so VA-API auto-detection failed even though 3D acceleration
was already healthy. Media acceleration is tracked separately in
`MEDIA-ACCELERATION.md`.

The live DRM client table also shows Sway opening both the i915 card node and
`renderD128`; Xwayland also uses the render node. The compositor is therefore
using the real DRM/GPU stack rather than software-only composition.

## Live GPU frequency baseline

- Idle frequency: 200 MHz.
- Efficient/RPe frequency: 578 MHz.
- Maximum frequency: 778 MHz.
- GPU was idle when sampled.
- Runtime PM usage count was 0.

## Short accelerated-load smoke test

Non-vsynced `glxgears` runs were used only as smoke tests, not as a
meaningful comparative benchmark. Repeated five-second samples produced
roughly 1800-2000 FPS. In a six-sample `intel_gpu_top` run the Render/3D
engine averaged 86.3% busy and peaked at 90.5%; another run reached about
97.5% busy. Requested GPU frequency averaged about 461 MHz under that load.

At idle, six `intel_gpu_top` samples reported essentially 100% RC6 residency
and 0% Render/3D busy. Polling `i915_frequency_info` during load also showed
the GPU leaving the 200 MHz idle clock and dynamically operating between
roughly 422 and 556 MHz in the sampled interval. After the tests:

- i915 reset count remained 0;
- `ERROR` remained `0x00000000`;
- `i915_error_state` remained empty;
- systemd had no failed units.

This confirms command submission and RPS scaling are functional. It does
not prove that every graphics workload is optimal.

## Important i915 debug interfaces

The kernel exposes the device under
`/sys/kernel/debug/dri/0000:00:02.0/`.

Useful files include:

- `i915_vbt` — raw Video BIOS Table used for board/panel configuration.
- `i915_display_info` — active CRTCs/connectors/modes.
- `i915_gpu_info` — platform, PCI identity, feature flags and reset state.
- `i915_error_state` — captured GPU hang/error state.
- `i915_frequency_info` — RPS clocks and limits.
- `i915_runtime_pm_status` — runtime power-management state.
- `i915_engine_info` — engine state.
- `i915_power_domain_info` — display/GPU power domains.
- `i915_wa_registers` — programmed workarounds.
- `i915_capabilities` — driver/platform capabilities.

## Reproducible research environment

The flake's `graphics` dev shell has been validated on the tablet. It provides
`drm_info`, `modetest`, `intel_gpu_top`, `intel_vbt_decode`, `glxinfo`,
`vainfo`, `ffmpeg`, `acpidump`, `iasl`, and `apitrace` without making those tools part
of the permanent system profile.

A full capture produced by `tools/collect-gpu-state` includes DRM/KMS state,
i915 debugfs data, the raw and decoded VBT, ACPI tables with MSDM/SLIC removed,
Mesa/VA-API information, and checksums. The VBT hash remains
`ac43644603f1e519ce83c594e1ef75f8c779533fdd51864d293876893c519312`
across the before/after VA-API captures.

## Safety rule

Never start by replacing i915. First capture a reproducible symptom, determine
whether it belongs to kernel display/GT code, Mesa Crocus, media/VA-API, or the
compositor, and then test the smallest possible upstream/backport/quirk change.

All kernel experiments must use a separate NixOS generation and
`nixos-rebuild test` before any permanent switch.
