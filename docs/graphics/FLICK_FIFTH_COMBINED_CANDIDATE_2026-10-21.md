# Fifth independent candidate: native DRM QML and Intel EGL optimisations combined

Dedicated experimental flake attribute: packages.x86_64-linux.flick-qt-egl-qml-experimental.

It adds three opt-in patches to the exact six local integration patches plus the seventh log-demotion patch, in order:
- 0008: Skip rendering/copying a full-screen Slint image when the existing QML LockScreen render branch already owns composition.
- 0009: Advertise native DRM DMA-BUF feedback from the actual GPU EGL formats, validating each client import with the real GLES renderer before acknowledging success.
- 0010: Enable Smithay use_system_lib and bind GlesRenderer EGL to the server Wayland display, advertising wl_drm and allowing EGL Wayland buffer imports.

The earlier independent logging-only, QML-only, DMA-BUF-only and EGL+DMA-BUF packages remain unchanged. The QML skip condition matches Flick's original LockScreen special render branch predicate. Before compilation, all patches were re-applied sequentially to a reconstructed original source tree and checked for all three feature signatures.

**No activation.** This combined build should not be promoted merely because Rust compiles. In particular, skipping obscured Slint drawing and enabling new Wayland buffer transports may interact with the QML fallback. The exact performance and stability of this combined variant must be measured only in a reversible live-service trial with an independently verified system-manager rollback. GRUB generation 55 is available as a physical recovery path, but the connected remote-service restrictions previously prevented such a privileged trial.
