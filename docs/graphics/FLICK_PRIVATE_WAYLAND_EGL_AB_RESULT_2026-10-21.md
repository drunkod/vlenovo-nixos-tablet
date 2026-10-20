# Independent EGL Wayland protocol A/B: wl_drm unlocks Intel hardware GPU

**Test date:** 2026-10-21. Device: Lenovo Miix 2 10, NixOS 25.05, Intel Atom Z3745 / Bay Trail Valleyview GPU PCI 8086:0f31, Mesa 25.0.7.

## Experimental procedure

Using a Python/ctypes test harness, started short-lived user-owned Wayland servers on unique private sockets under /run/user/1001. Each server created a GBM device from the existing Intel render node (/dev/dri/renderD128), a Mesa EGL 1.5 display, and an independent Wayland server display. **No DRM master ownership, KMS mode setting, VT switch, systemd override, NixOS generation change, compositor restart or touchscreen change was involved.**

Control: initialized EGL/GBM and Wayland but did **not** call eglBindWaylandDisplayWL.

Treatment: same implementation and device, with eglBindWaylandDisplayWL enabled on the server display; eglUnbindWaylandDisplayWL was called on teardown.

For each, used wayland-info against its private socket and Mesa eglinfo with EGL_PLATFORM=wayland to query a client EGL renderer. Each server was run for 22 seconds, then disposed of. The test was run once and then **repeated independently with the complete console transcript retained**; both produced the same meaningful outcome.

## Observed control and treatment

| Property | Control: unbound EGL server | Treatment: EGL bound to Wayland |
|---|---|---|
| Private Wayland socket | Created | Created |
| eglBindWaylandDisplayWL | Not called | Called successfully |
| wl_drm global | Absent | **Present, version 2** |
| EGL version | 1.5 | 1.5 |
| Client EGL Wayland result | **eglInitialize failed** | **eglInitialize succeeded** |
| OpenGL core renderer | Unavailable | **Mesa Intel(R) HD Graphics (BYT)** |
| OpenGL ES renderer | Unavailable | **Mesa Intel(R) HD Graphics (BYT)** |
| Server event loop/clean exit | Passed | Passed |
| Active original Flick after test | PID 894; active | PID 894; active |

Evidence: mvp/native/benchmarks/2026-10-21-private-wayland-wldrm-ab.txt. The original production Wayland socket, in contrast, exposes neither wl_drm nor Linux DMA-BUF and its Mesa Wayland EGL client selects llvmpipe (see EGL_PLATFORM_CLIENT_DIAGNOSIS_2026-10-21.md).

## Interpretation

The private A/B directly demonstrates that **binding the Intel EGL display into a Wayland server exposes wl_drm and enables a Wayland EGL client to initialize with the actual Intel GPU**. This strongly supports the fourth Flick candidate's native DRM ImportEgl::bind_wl_display implementation as a meaningful fix, independently of the Qt lock-screen process.

It is still **not a production compositor trial**: this private server has no wl_compositor/surface protocol, window shell, Slint UI, QML process or active display. The unbound control could not initialize EGL at all, rather than successfully choosing llvmpipe as with the original Flick socket, because the tiny probe advertises no other buffer protocols. Thus it isolates the practical value of wl_drm initialization but does not prove that wl_drm is the ONLY cause of llvmpipe use in the complete Flick system. Screen composition, client-buffer import, touch and Qt render performance still need a guarded real-session A/B test.

The fourth x86_64 Linux Nix release binary has independently been compiled, hash-verified, smoke-tested and staged at /home/alex/lenovo-mvp/builds/flick-qt-egl-experimental-x86_64, SHA-256 361d97fcda198e202540298a23455496cabbaaf70a825a58ae85747b11a72f04. It is NOT activated. The privileged system-service manager integration test is restricted by the remote connector's safety policy; the policy was neither altered nor bypassed. The bootloader's NixOS 55 and 56 generation entries and old kernel/initrd are available for physical recovery, but automatic compositor rollback has not been validated under the privileged service manager.

The original tablet baseline was a separate complete 30.1-minute read-only 120-sample trace collected BEFORE this private EGL test: Flick 91.8% CPU, QML 33.7%, native dashboard 8.9% of one logical core on average; Qt retained four llvmpipe threads at every sample.
