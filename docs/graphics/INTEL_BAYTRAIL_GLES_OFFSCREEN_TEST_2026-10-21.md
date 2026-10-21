# Real Intel Bay Trail OpenGL ES2 offscreen draw/readback verified

On 2026-10-21, while the original working Flick compositor and Qt5 QML lock screen remained active, a small separate user-owned process created a GBM/EGL display from the existing /dev/dri/renderD128 Intel DRM render node, initialized an EGL OpenGL ES 2.0 context, allocated a 64x64 GL_RGBA texture and attached it to a GLES framebuffer object.

The test invoked glClear with alternating magenta and green colors, glFinish, and glReadPixels on each of eight frames. Every pixel sample matched the expected RGBA color to within a single unit, with no GL error. The actual queried GPU renderer was **Mesa Intel(R) HD Graphics (BYT)**, vendor Intel, **OpenGL ES 3.0 Mesa 25.0.7**, EGL 1.5. Total wall time for all eight offscreen frames was approximately 45.07 ms on a cold start; this is a correctness test, NOT a reliable performance or power benchmark.

The first attempt requested a PBUFFER-capable EGL configuration on the GBM device and returned "No GLES2 RGBA8 configuration". This is not a GPU rendering failure: the GBM platform did not meet that unnecessarily strict pbuffer requirement. The test was corrected to allow a GLES2 RGBA8 context without PBUFFER_BIT, using EGL_KHR_surfaceless_context and an independently allocated GL framebuffer. The corrected test passed on the real tablet.

All testing used EGL_PLATFORM_GBM_MESA through the existing Intel GBM render node and did NOT grab DRM master, VT, KMS scanout, input, the original Wayland socket, a screen or sensor. No permanent NixOS system or service changes were made. The original Flick PID remained 894 with no systemd drop-ins, and the booted/current NixOS generations stayed equal.

Source: tools/test-intel-byt-gles-offscreen.py. Direct tablet output: mvp/native/benchmarks/2026-10-21-intel-render-node-gles2-draw-readback.txt.

**Scope:** This independently establishes that the existing upstream Linux i915 kernel driver and Mesa Crocus userspace can execute actual GLES draw commands and return pixels correctly through Intel hardware, concurrently with Flick. A Windows graphics-driver port is not needed for basic Intel rendering. It DOES NOT prove that the combined Flick candidate has been activated, that QML switched away from llvmpipe, or that the Smithay Wayland EGL buffer path correctly imports client frames. Those are separate compositor integration tests.
