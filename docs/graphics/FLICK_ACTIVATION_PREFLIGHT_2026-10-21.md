# Flick graphics-candidate activation: read-only preflight

**Do not treat this document as permission to restart the active compositor.** The three candidates are built and staged, but no physical recovery procedure has been verified.

## Observed service constraints

- The running service is a **system-level** unit at /etc/systemd/system/flick.service, running as user alex.
- It sets FLICK_BACKEND=drm and starts the original installed wrapper from /nix/store/mff55q54jy9x5jifkzy5fhriqshd90ng-flick-unstable-2026-01-04/bin/flick.
- The unit owns /dev/tty1 with TTYReset=true, TTYVHangup=true and TTYVTDisallocate=true. It conflicts with getty@tty1.service and sxmo.service; Restart=on-failure is enabled.
- A manual restart or a malformed runtime override could therefore disrupt display, Wayland socket and shell clients. Ordinary systemd restart policy is **not** sufficient proof of a safe rollback.
- The NixOS boot/current generation remained identical at preflight, the touchscreen device resolved to event4 and Flick/sshd/NetworkManager/seatd were running.
- Three staged ELF executables have matching known SHA-256 hashes, and / has approximately 19 GiB free.

## Future controlled runtime-test prerequisites

1. Confirm physical access to the tablet and an independent way to recover its display or boot into the known-good generation.
2. Design, review and dry-run an **independent timed rollback** that restores the original /etc/systemd/system/flick.service configuration even if the candidate crashes or SSH disconnects; verify it survives relevant session failures.
3. Record the precise original service file, environment and executable path; ensure any runtime override preserves the proper FLICK_ROOT and Nix library paths.
4. Test only one candidate at a time and immediately check Wayland clients, QML lock/unlock, keyboard, touch, sshd, network and i915 logs. Compare baseline CPU under the same sampling conditions.
5. If failure occurs, restore the original executable/service and state. Do not promote a new NixOS generation until the temporary test has passed.

The current script tools/preflight-flick-graphics-test.sh is **strictly read-only**. From the Mac, run it through SSH as bash -s; it verifies hashes and services but prints activation is NOT authorised. Evidence is saved at mvp/native/benchmarks/2026-10-21-flick-activation-preflight.txt.

Until a physical-recovery arrangement exists, a successful cross-built executable and a successful --help test are the safe stopping point.
