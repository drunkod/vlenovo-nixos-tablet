# Lenovo Miix 2 10: Qt Quick lock screen uses llvmpipe, missing Linux DMA-BUF Wayland global

**Research date:** 2026-10-21. **Tablet state:** read-only inspection; no service restart, NixOS activation, GPU reset, sensor change or environment override.

## Confirmed live observations

- Current QML process is `qmlscene` PID **1026**, Qt **5.15.17**, lock-screen `main.qml`, and used about **32.3% of one logical Atom CPU core**, ~108 MiB RSS in process samples.
- `/proc/1026/task/*/comm` contains **four threads named `llvmpipe-0` through `llvmpipe-3`**, plus `QSGRenderThread`, two `WaylandEventThr` threads and normal Qt worker threads. This is strong direct evidence Qt Quick is **software-rasterizing through llvmpipe**, not Intel Crocus.
- The running `qmlscene` process maps `libQt5Quick.so.5.15.17`, `libEGL_mesa.so`, `libgallium-25.0.7.so` and `libgbm.so`. The presence of EGL/Gallium libraries **alone does not prove hardware acceleration**. `/proc/1026/fd` shows `/memfd:lp_dma_buf` and `/memfd:allocation fd`, but **no open `/dev/dri/renderD128`**. The name `lp_dma_buf` originates in Mesa's llvmpipe source at `src/gallium/drivers/llvmpipe/lp_texture.c`.
- QML environment selects `QT_QPA_PLATFORM=wayland` and `QT_WAYLAND_CLIENT_BUFFER_INTEGRATION=wayland-egl`; no `LIBGL_ALWAYS_SOFTWARE`, `MESA_LOADER_DRIVER_OVERRIDE` or `QT_QUICK_BACKEND=software` override was seen.
- `/dev/dri/renderD128` exists and is **crw-rw-rw-** (render node), and independent `eglinfo` from SSH successfully reported `Mesa Intel(R) HD Graphics (BYT)`. A lack of ordinary user render-node permissions is unlikely to explain this result.
- The live Wayland registry was queried with `wayland-info` on `WAYLAND_DISPLAY=wayland-1`. It advertises **ten globals**:
  `wl_compositor`, `wl_subcompositor`, `xdg_wm_base`, `wl_shm`, `zxdg_output_manager_v1`, `wl_data_device_manager`, `zwp_text_input_manager_v3`, `android_wlegl`, `wl_seat`, `wl_output`. **Neither `zwp_linux_dmabuf_v1` nor `wl_drm` was advertised.**
- The running compositor's `i915`/Mesa Crocus/EGL + GBM DRM backend itself already works with Intel hardware acceleration. **The missing Wayland client buffer path is a distinct problem from server-side GPU rendering.**

## Source-level explanation and missing integration

The exact deployed Flick source revision `729cdecedad05be3192b21f7d4310eb0ff7ae563`, after six NixOS integration patches, has `Flick.dmabuf_state: DmabufState` and `Flick.dmabuf_global: Option<DmabufGlobal>`. The state constructor sets `dmabuf_global: None`.

In `shell/src/backend/udev.rs::init_gpu`, the active **native DRM backend** creates `GbmDevice`, `EGLDisplay`, `EGLContext` and `GlesRenderer`, and obtains **`egl_context.dmabuf_render_formats()`**. Those formats currently feed `GbmBufferedSurface::new` for Flick's own scanout. The native backend **never calls `DmabufState::create_global_with_default_feedback`**, so Qt Wayland clients do not see a Linux DMA-BUF protocol even though the compositor uses GBM/EGL internally.

The *different* `shell/src/backend/hwcomposer.rs` backend does build `DmabufFeedbackBuilder` from a render node, then calls `state.dmabuf_state.create_global_with_default_feedback::<Flick>` and stores the global. That code is **not executed** by the native DRM backend on this tablet. The HWC code also uses a few hardcoded formats; the Intel version should advertise **only the formats/modifiers really reported by the active EGL renderer**, not copy the HWC list blindly.

A further safety caveat: `shell/src/state.rs::DmabufHandler::dmabuf_imported` currently calls `notifier.successful::<Flick>()` without an immediate GPU import check, relying on deferred import while rendering. Before advertising DMA-BUF broadly, audit supported format/modifier feedback and error handling for rejected buffers. This is **not** yet a ready-to-install fix.

## Separate engineering experiment (not activated)

1. In a **third independent Nix build variant**, add native DRM `DmabufFeedbackBuilder` setup using `egl_context.dmabuf_render_formats()` and the correct render node device ID. Register `zwp_linux_dmabuf_v1` only when feedback creation succeeds; preserve the existing SHM fallback. Do not duplicate the global on additional outputs.
2. Review Smithay 0.7 `DmabufHandler::dmabuf_imported` semantics and renderer error handling before making GPU imports reachable from Qt. Do not enable questionable formats or unvalidated modifiers.
3. Build x86_64 Linux on the MacBook Colima/Rosetta setup; verify ELF/closure and stage without activation. The first two independent builds stay available: logging-only, and logging + QML full-screen Slint skip.
4. For a later **controlled live test requiring a rollback and physical access**, verify `wayland-info` now advertises `zwp_linux_dmabuf_v1`, Qt `QSG_INFO=1` startup reports Intel vs llvmpipe, Qt opens the Intel render node, and `llvmpipe-*` worker threads disappear. Confirm GPU render usage and stable buffer import; then compare lock-screen CPU, compositor CPU, touch/keyboard and unlock behavior.
5. Keep the system's known-good boot and GUI service unchanged until that test is approved. The additional DMA-BUF global changes client/server buffer transport; it can cause black screens if formats/imports are wrong.

**Assessment:** llvmpipe usage and missing protocol are verified, and the native code omission is verified. **Causality and the performance improvement of registering DMA-BUF are not yet demonstrated**. GPU client fallback could have additional causes (Qt's Wayland-EGL integration and EGL device selection). No system-level driver replacement is justified.

## Sources and reproduction

- Current source: `shell/src/backend/udev.rs` (~lines 680–755); `shell/src/backend/hwcomposer.rs` (~2554–2625); `shell/src/state.rs` (~1793–1820).
- Read-only shell: `wayland-info` with `XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-1`, `sudo cat /proc/1026/task/*/comm`, and `sudo ls /proc/1026/fd`.
- [Qt 5 scene graph adaptations](https://qthub.com/static/doc/qt5/qtquick/qtquick-visualcanvas-adaptations.html), and [Qt Quick scene graph diagnostics](https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph.html), specifically `QSG_INFO=1` for renderer identification.
- [Mesa llvmpipe source for `lp_dma_buf`](https://chromium.googlesource.com/external/gitlab.freedesktop.org/mesa/mesa/+/aef497d66998e760f2fa5af9351051e1ee9443fc/src/gallium/drivers/llvmpipe/lp_texture.c).

## Smithay 0.7 import validation architecture (follow-up)

The Smithay 0.7 API explicitly instructs the compositor to **test DMA-BUF imports in its renderer** before calling the import notifier success; `ImportDma::import_dmabuf(&dmabuf, None)` on `GlesRenderer` can make that test. Smithay Anvil's implementation performs the import and calls `notifier.failed()` when the renderer rejects it.

In this Flick revision, `GlesRenderer` is owned by `GpuData` in `backend/udev.rs`, while `DmabufHandler for Flick` is implemented in `state.rs`. The renderer is **not directly reachable** in the Wayland callback. A safe patch therefore needs a controlled renderer access/design (or a validated deferred-import mechanism); just transplanting the HWC `create_global_with_default_feedback` call is insufficient.

- [Smithay 0.7 DmabufState and globals](https://smithay.github.io/smithay/smithay/wayland/dmabuf/struct.DmabufState.html)
- [Smithay 0.7 DMA-BUF integration guidance](https://smithay.github.io/smithay/smithay/wayland/dmabuf/index.html)
- [Smithay 0.7 ImportDma trait](https://smithay.github.io/smithay/smithay/backend/renderer/trait.ImportDma.html)
- [Smithay Anvil import example](https://github.com/Smithay/smithay/blob/master/anvil/src/udev.rs)

A repeatable read-only baseline command is `ssh -F ~/.ssh/vlenovo_config vlenovo 'bash -s' < tools/check-qt-wayland-gpu.sh`; expected results before any activation: `linux_dmabuf_wayland_global=ABSENT`, `wl_drm_wayland_global=ABSENT`, `qmlscene_llvmpipe_threads=4`, `qmlscene_render_node_fds=0`. The exact live sample was preserved at `mvp/native/benchmarks/2026-10-21-qml-llvmpipe-wayland-registry.txt`.
