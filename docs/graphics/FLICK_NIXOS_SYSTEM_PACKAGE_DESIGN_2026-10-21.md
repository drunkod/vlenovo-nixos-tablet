# Reproducible Flick candidate for future NixOS generation

The live Qt/Intel GPU and QML raster-skip trial proved that the fifth x86_64 native compositor drastically reduced measured CPU while the Qt client used wl_drm/Linux DMA-BUF. The temporary trial launcher was a hash-pinned file under /home/alex; that is unsuitable as a permanent system package.

The experiment flake now exposes packages.x86_64-linux.flick-qt-egl-qml-system as an independent NixOS-ready symlinkJoin package. It is composed of exactly the fifth candidate's tested patches, unchanged pinned upstream Flick source and the original NixOS Qt5 lockscreen assets. Its Nix-generated wrapper sets FLICK_ROOT and the same Mesa/Wayland library ABI search path as the previous working package. The original default flick and independent four candidates are unchanged.

This new attribute is intended to become services.flick.package through the existing actual tablet module /home/alex/vlenovo-flick-dev/modules/nixos/flick/default.nix. That module defines a package option and uses it for both ExecStart and FLICK_ROOT in the NixOS-generated systemd service. The current /etc/systemd/system/flick.service was verified to be a symlink to an immutable /nix/store/...-unit-flick.service/flick.service file, not a standalone unmanaged file.

No new NixOS generation is activated by building this package. Before attempting a declarative system switch, resolve the authoritative deployed tablet flake and explicitly compare the new generation with the known-good booted generation; package closure must contain the Qt5 QML assets and maintain the existing system-service ownership and PAM/seatd settings. Actual physical screen, touch/unlock, suspend and rotation are still unverified.

All live trial state was rolled back three times with root systemd timers returning Result=success. Original NixOS service remains active.
