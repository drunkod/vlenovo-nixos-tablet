# Flick compositor: timed recovery guard — prototype and test evidence

**Scope: 2026-10-21.** Separate Git branch: flick-gpu-optimization. **No live Flick candidate was activated, restarted or installed into the active NixOS generation.**

## Why this recovery path

The tablet's active system service is /etc/systemd/system/flick.service. It owns /dev/tty1 and is configured with terminal reset, hangup and VT deallocation. Testing a new DRM compositor can blank the sole local session and disturb QML/Wayland clients, even when SSH remains active.

The proposed non-persistent trial will retain that NixOS-managed permanent unit and use a marked runtime-only systemd drop-in at:

/run/systemd/system/flick.service.d/90-vlenovo-gpu-trial.conf

A separate systemd timer, armed BEFORE any compositor restart, will execute a root-owned recovery program stored outside the user-writable home directory. The recovery program removes ONLY the correctly marked runtime drop-in, reloads systemd and restarts the original NixOS Flick service. An unmarked/symlinked override is rejected rather than removed.

No trial activation or watchdog arming occurred in this work.

## Source implementation

- tools/flick-guard-rollback.sh: root-only, guarded, narrowly scoped restoration of the original service. If the temporary override is absent, it returns without restarting Flick. Its required marker is the exact first-party trial marker; it refuses unmarked and symlinked files. It never writes the permanent unit and never switches NixOS generations.
- tools/test-flick-guard-rollback.py: local mock tests with an isolated temporary filesystem and a stub systemctl, without invoking the tablet's actual unit manager.

## Independently verified tests

The local test harness passed six assertions:
1. Absent override does not call systemctl.
2. Unmarked override is refused.
3. Symlinked override is refused.
4. Marked override is removed; daemon-reload happens before restart.
5. The original (mock) permanent service remains byte-for-byte unchanged.
6. Repeated rollback causes no extra restart.

A separate, harmless **real systemd-run system timer** was tested on the Lenovo tablet. The root-owned transient systemd timer was scheduled for four seconds and wrote only a marker file under /run. That marker appeared, indicating the timer/service mechanism executed. The marker was removed afterward. Flick remained active with the SAME PID 894 before and after, and SSH remained active.

**Important limitation:** this timer test did not deliberately disconnect SSH or restart a compositor. An attempted end-to-end rehearsal on a disposable system-level demo service was blocked by the remote command policy. No attempt was made to bypass that restriction. The actual timer plus actual restore script together have therefore NOT yet been tested through the tablet's real systemd unit manager. Do not claim production rollback readiness.

## Mandatory further gates before on-device GPU activation

- Arrange physical access and an independently tested rescue path, for example a locally accessible fallback VT or recovery boot entry.
- Review the effective service environment and preserve the known-good Flick system wrapper, FLICK_ROOT, Nix dynamic libraries, seatd permissions, TTYPath and supplementary groups.
- Obtain authorisation for an end-to-end disposable-unit integration rehearsal; separately demonstrate a timer still fires if the controlling SSH session disconnects.
- Only after those rehearsals pass: stage the rollback shell script as a root-owned, executable file in a private /run directory, record a complete service/override backup and unit hash, and arm a transient root systemd timer. Check that it actually appears and is active BEFORE applying any trial runtime override.
- For one candidate at a time, verify the SHA-256 of the staged binary, install a marked override only under /run, daemon-reload, restart the trial and check graphics/Wayland/input for a short window. Leave the watchdog ARMED unless the physical recovery, application behaviour and original-unit restoration are all verified.
- Keep original system service and boot generation untouched. Do not run experiments when the person at the tablet cannot recover a blank screen.

Three existing staged candidates: logging-only; logging with QML full-screen raster skip; logging with native DRM validated DMA-BUF protocol. Compilation and --help alone do not establish GPU or touch-session correctness.

**Current status: source-level rollback logic and isolated timer mechanism tested separately. Real compositor activation remains blocked pending physical access and end-to-end recovery verification.**
