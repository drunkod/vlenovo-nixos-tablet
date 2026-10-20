# Fourth Flick candidate: Wayland EGL wl_drm + validated DMA-BUF

**Built on 2026-10-21 using MacBook Colima/Rosetta, isolated Linux x86_64 Nix builder.** Source branch: flick-gpu-optimization. This is a separate fourth candidate, NOT the default package and NOT an activated NixOS generation.

## Build and staging results

| Check | Verified outcome |
|---|---|
| Pinned Flick base | 729cdecedad05be3192b21f7d4310eb0ff7ae563 |
| Independent Nix attribute | packages.x86_64-linux.flick-qt-egl-experimental |
| Ordered patches | Six NixOS integration + logging patch 0007 + native DRM validated DMA-BUF 0009 + Wayland EGL wl_drm 0010 |
| Compiler | Successful x86_64 Rust release, 22 min 50 sec, 134 nonfatal warnings |
| Nix build | Exit 0; patch, install and fixup phases succeeded |
| Nix output | /nix/store/rr2di3xjbmks5x8cin33wslbxs2n121z-flick-unstable-2026-01-04 |
| Binary SHA-256 | 361d97fcda198e202540298a23455496cabbaaf70a825a58ae85747b11a72f04 |
| ELF format | Linux x86-64 executable |
| Feature signature | String Registered wl_drm through renderer EGL Wayland binding present |
| Nix store validity | Verified by the dedicated build verifier |
| Direct runtime Nix store references | MATCH_KNOWN_GOOD on tablet |
| Mac Linux --help | Passed |
| Tablet --help | Passed |
| Tablet checksum | Identical SHA-256 |
| Tablet stage path | /home/alex/lenovo-mvp/builds/flick-qt-egl-experimental-x86_64 |
| Essential tablet services after stage | flick, sshd, NetworkManager, seatd all active |
| Compositor activation/restart | NONE; original Flick still running |
| Mac Linux build VM | Stopped automatically; cache retained |

The private, ignored build logs and verification records live on the MacBook under .flick-nix-candidate/build-qt-egl-release.log, qt-egl-build-status.txt and verify-qt-egl-staging.log. The final executable is copied there as flick-qt-egl-experimental-x86_64.

## Behavior of the new candidate

The native DRM GlesRenderer binds its EGL display to the Wayland display using ImportEgl::bind_wl_display, which enables wl_drm registration if supported. The Rust Smithay use_system_lib feature enables EGL wl_buffer imports in its ImportAll implementation. The earlier validated native DMA-BUF import path remains present, with client import acknowledgements issued only after renderer import succeeds. Logging reduction is included; QML Slint raster skipping is excluded.

Compilation and executable smoke tests show correct Rust API usage, linking and packaging only. **They do not prove that the new Wayland global appears under a running Flick service, that Qt switches to Intel Crocus, that all buffers render, or that CPU use drops.** The tablet's active compositor remains the known-good version while independent client-side tests are carried out.

A controlled live-service trial needs full system-manager rollback validation. User-level systemd rollback simulation has passed, but the remote connector's enforced privileged command restrictions prevent activation of the real system service; these restrictions were not changed.

A separate 30-minute CPU baseline and an unprivileged private EGL Wayland A/B protocol test are being run to provide causal evidence without disturbing the active DRM compositor.
