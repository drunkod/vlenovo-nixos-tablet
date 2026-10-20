# Fourth candidate: Qt 5 Wayland-EGL wl_drm alongside validated DMA-BUF

Date: 2026-10-21. Fourth candidate on flick-gpu-optimization; three built candidates remain unchanged. No activation.

## Evidence

Qt 5.15 Wayland-EGL is likely blocked by missing wl_drm as well as missing Linux DMA-BUF global. Pinned Smithay 0.7 provides ImportEgl::bind_wl_display on GlesRenderer only when the use_system_lib feature is enabled; the same feature changes Smithay ImportAll to accept EGL-based wl_buffer buffers. The original compositor exposes neither protocol and Qt has four llvmpipe threads.

## Independent modifications

Nix attribute: packages.x86_64-linux.flick-qt-egl-experimental

- Adds Smithay Cargo feature use_system_lib to shell/Cargo.toml.
- Imports Smithay ImportEgl trait.
- Calls GlesRenderer::bind_wl_display(&state.display_handle) on the active GPU's EGL renderer before clients can connect.
- Logs binding success/failure without rejecting an otherwise working GPU.
- Includes previous native DMA-BUF advertised feedback and validated imports. Excludes Slint QML render-skip patch to isolate causality.

Smithay source confirms binding advertises wl_drm and ImportAll handles EGL WlBuffer when use_system_lib is enabled. Compilation is necessary but not proof of functional GPU import, CPU improvement or compositor startup safety.

Source:
- https://smithay.github.io/smithay/smithay/backend/egl/display/struct.EGLDisplay.html
- https://smithay.github.io/smithay/smithay/backend/renderer/trait.ImportEgl.html
- https://smithay.github.io/smithay/smithay/backend/renderer/gles/struct.GlesRenderer.html

Build on dedicated x86 Linux Mac VM, verify ELF closure and smoke test, stage without activation. System service rollback and physical recovery must be reliable before live display testing.


## Build and staging confirmation

The isolated fourth Nix build completed successfully with Rust release compilation in 22 min 50 sec and Nix exit code 0. Store output: /nix/store/rr2di3xjbmks5x8cin33wslbxs2n121z-flick-unstable-2026-01-04. Binary SHA-256: 361d97fcda198e202540298a23455496cabbaaf70a825a58ae85747b11a72f04. The full source-signature, ELF, store-path, direct runtime-library reference equality, Mac and tablet --help, upload checksum and essential-service checks passed. The binary was **staged, not activated** at /home/alex/lenovo-mvp/builds/flick-qt-egl-experimental-x86_64. For full reproducibility and limitations see FLICK_QT_EGL_BUILD_RESULT_2026-10-21.md.
