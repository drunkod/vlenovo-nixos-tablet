# Qt Quick lock-screen renderer: verified effective runtime environment

Verified read-only on 2026-10-21 against the **running** qmlscene PID 1026, rather than only against source code. The exact selected non-sensitive entries of its effective process environment are preserved at mvp/native/benchmarks/2026-10-21-qml-effective-renderer-env.txt.

- WAYLAND_DISPLAY=wayland-1
- QT_QPA_PLATFORM=wayland
- QT_WAYLAND_CLIENT_BUFFER_INTEGRATION=wayland-egl

No QT_QUICK_BACKEND=software override was found in the selected environment entries. The process still had four llvmpipe worker threads in the baseline.

## Why this matters for the fifth candidate

The upstream shell/src/shell/mod.rs launch_lock_screen_app function sets QT_WAYLAND_CLIENT_BUFFER_INTEGRATION=shm on the intermediate spawned shell command. However, the actual package launches apps/lockscreen/run_lockscreen.sh via a Nix Qt wrapper. That script itself exports QT_WAYLAND_CLIENT_BUFFER_INTEGRATION=wayland-egl, overriding the inherited shm value.

The live process environment therefore confirms that **the Qt5 lock-screen client is already requesting the EGL integration**. The compositor's missing wl_drm/Linux DMA-BUF globals remain the primary known transport obstacle; a sixth patch to change the parent process environment is unnecessary and could introduce unrelated startup differences.

Proof is limited to the requested Qt integration setting; a Qt client with this environment may still fall back to Mesa llvmpipe when its Wayland server does not expose GPU buffer transport. We previously reproduced that fallback independently using Mesa eglinfo. The fifth combined package adds server-side wl_drm binding and validated DMA-BUF in addition to the QML software raster skip. No live compositor activation took place during this check.

## Startup ordering confirmed in pinned native DRM source

Flick starts the QML wrapper process before native GPU initialization, but the main event loop dispatches Wayland client requests only **after** the initial udev GPU scan and init_gpu have completed. The fifth candidate's EGL wl_drm registration is inside init_gpu. Thus a client may connect to the socket early but its registry requests should not be dispatched before the renderer's EGL binding is in place. This source ordering was added to the repeatable combined-patch static test; it has not been demonstrated by observing a live candidate's registry or Qt startup.

This does not exclude a failure if the GPU initialization or EGL binding fails; those failures must be checked during the supervised runtime trial.
