# Further native DRM CPU optimisation candidate: avoid unconditional full redraw

Reviewed 2026-10-21 against the pinned native DRM Flick source used by the Nix build. This is **analysis only**, deliberately excluded from the fifth combined candidate.

## Code-level observations

- init_gpu constructs a persistent OutputDamageTracker::from_output(&output) stored in each SurfaceData.damage_tracker (native DRM udev.rs around lines 795–799).
- render_surface obtains the GBM swapchain's buffer age from next_buffer(), then assigns it to _age, discarding it immediately (around line 841).
- Every frame for ShellView::Switcher, Home, LockScreen or QuickSettings, render_surface instantiates a **fresh** OutputDamageTracker::from_output(output) (around line 1372). On QML lock screen frames the code selects this fresh tracker and calls render_output(renderer, ..., 0, ...) (around line 1661).
- Several other render branches use the persistent tracker but still force buffer_age=0 (e.g. Home, QuickSettings, app/keyboard and gesture branches).

This is consistent with the prior runtime log count of 57 fresh damage trackers in 10 seconds. It provides source-level evidence of repeated full redraw requests, not merely an inference from high CPU.

## Why not change it in the current release candidate?

Damage-tracker state and GBM back-buffer ages must be coordinated to avoid leaving unrendered or stale pixels on buffered surfaces. Treating _age as valid without testing buffer swap behavior and invalidation on view transitions, VT changes, Qt client commits or keyboard overlays is risky. Simply removing fresh_tracker may not reduce GPU work when buffer_age=0 still instructs full redraw.

The current fifth candidate therefore retains the conservative, working full-redraw path. It only skips the unnecessary **Slint software raster/clone** for the QML-obscured LockScreen branch, independently adding the validated Wayland GPU-client EGL paths.

## Suggested later isolated experiment

Once the fourth candidate is proven safe in a live compositor trial, instrument next_buffer() buffer ages, output tracker damage rectangles, GPU frame counts and lock/unlock transitions with throttled diagnostic sampling. Then separately test damage-tracker reuse under correct buffer-age semantics and forced invalidation on geometry/VT/view changes. Include checks for stale frames, ghosting, keyboard overlay, touch effects, rapid lock/unlock and screen rotation. Measure with the same 30-minute CPU baseline methodology, keeping a recovery timer armed. Do not promote based on a successful source compilation alone.

No live renderer or system-manager restart occurred during this investigation.
