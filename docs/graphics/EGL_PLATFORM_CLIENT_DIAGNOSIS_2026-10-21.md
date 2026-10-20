# Lenovo Miix 2 10: independently reproduced Wayland EGL software fallback

Research and read-only testing: 2026-10-21. Active NixOS generation 56, running Flick PID 894, graphics card Intel Bay Trail (PCI vendor 8086, device 0f31), Mesa 25.0.7. No compositor restart or display-service override.

## Isolated platform test on physical tablet

Ran the cached Mesa 9.0.0 eglinfo executable on the physical Intel Atom tablet, with the running Wayland socket at XDG_RUNTIME_DIR=/run/user/1001, WAYLAND_DISPLAY=wayland-1 and EGL_PLATFORM=wayland. No Qt code was involved in this experiment.

| Mesa EGL platform (same eglinfo process) | OpenGL renderer |
|---|---|
| GBM | Mesa Intel(R) HD Graphics (BYT) |
| Wayland | llvmpipe (LLVM 19.1.7, 128 bits) |
| Surfaceless | Mesa Intel(R) HD Graphics (BYT) |
| EGL device platform device 0 | Intel HD Graphics (BYT) |
| EGL device platform device 1 | llvmpipe |

The full textual output is preserved in mvp/native/benchmarks/2026-10-21-egl-platform-comparison.txt.

An explicit MESA_LOADER_DRIVER_OVERRIDE=crocus with EGL_PLATFORM=wayland **still selected llvmpipe on the Wayland platform**. This is strong evidence that changing only the client driver-selection environment does not address the missing transport negotiation. Raw output: mvp/native/benchmarks/2026-10-21-egl-forced-crocus.txt.

Separately, eglinfo (without -B) on the GBM platform confirms EGL_WL_bind_wayland_display as well as EGL_EXT_image_dma_buf_import, EGL_EXT_image_dma_buf_import_modifiers and EGL_MESA_image_dma_buf_export. This is an advertised capability; it does not prove the EGL binding succeeds after starting Flick.

## Wayland registry and current QML

A new wayland-info query against the original compositor returned exactly ten registry globals, including wl_shm and android_wlegl, but **neither zwp_linux_dmabuf_v1 nor wl_drm**. Evidence: mvp/native/benchmarks/2026-10-21-wayland-registry-recheck.txt. The live Qt 5.15.17 qmlscene process continues to expose four llvmpipe worker threads.

One plausible explanation is that Mesa lacks a protocol to negotiate the server GPU/allocate hardware buffers when connected to Flick's Wayland display, so it selects software. This contrasts with GBM and surfaceless, which can choose the Intel DRM render node directly. The EGL comparison does not on its own prove the missing protocol is the only cause. The fourth candidate will allow a controlled test of that hypothesis.

## Source-level route to fixing it

Smithay 0.7's backend documentation describes wl_drm initialization for Wayland EGL clients. At the exact pinned revision (1ca641f5bef0b09d36cec757bbb31b255c6b7b7f), GlesRenderer implements ImportEgl::bind_wl_display only under its use_system_lib feature. The ImportAll implementation accepts EGL buffers when this feature is enabled.

The fourth Nix candidate, packages.x86_64-linux.flick-qt-egl-experimental, adds use_system_lib and renderer.bind_wl_display(&state.display_handle) alongside the third candidate's previously built native DMA-BUF feedback and import validation. This feature is separate from logging-only and QML raster-skip variants.

References:
- https://smithay.github.io/smithay/smithay/backend/egl/display/struct.EGLDisplay.html
- https://smithay.github.io/smithay/smithay/backend/renderer/gles/struct.GlesRenderer.html
- https://smithay.github.io/smithay/smithay/backend/renderer/trait.ImportEgl.html
- https://github.com/qt/qtwayland

## Further isolated test

The source of tools/private-wl-drm-egl-probe.py and tools/run-private-egl-client-comparison.sh creates a short-lived, **non-root, private Wayland socket** under /run/user/1001, with an optional EGL_WL_bind_wayland_display registration from the Intel DRM render node. It creates no outputs, does not seize /dev/tty1, and never changes the existing Flick service. The control socket omits the bind; the treatment socket enables wl_drm. Comparing both using wayland-info and EGL_PLATFORM=wayland eglinfo is a direct causal test of protocol-based GPU discovery independent of QML. Do not execute during the uncontaminated 30-minute live baseline.

**Pending:** private socket A/B outcome, fourth package compile and exact runtime-closure verification, supervised live compositor measurements. Runtime GPU acceleration cannot be claimed from these source and offline tests alone.
