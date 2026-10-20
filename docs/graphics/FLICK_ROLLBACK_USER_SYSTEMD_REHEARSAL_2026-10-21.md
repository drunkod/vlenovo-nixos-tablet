# NixOS Flick rollback: actual tablet user-systemd integration rehearsal

Date: 2026-10-21. The real Flick compositor, graphics session and NixOS generation were never restarted or replaced.

## Bootloader recovery confirmed

The tablet boots through UEFI/GRUB. Its VFAT /boot is mounted and /boot/grub/grub.cfg has an ordinary NixOS entry plus a submenu containing system configurations 56 (current), 55 (previous), and earlier generations. Distinct /nix/var/nix/profiles/system-55-link and system-56-link closures exist. Physical recovery by choosing an older generation is practical, assuming the bootloader and input devices remain functional; it is not an entire disk-image backup.

## First user-systemd timer: failed, caught before live GPU test

The disposable unprivileged user systemd service switched from known-good state to experimental state. The independent eight-second timer DID fire, but its service exited 127. The tablet journal showed:

    env: 'bash': No such file or directory

The original recovery script used an env-style shebang, which depends on PATH being populated correctly. That assumption was unsafe inside the transient systemd timer. A previous isolated root-systemd timer smoke test did not uncover the problem because it invoked an absolute-path program instead of this script.

## Production script corrected

tools/flick-guard-rollback.sh now starts with the NixOS-specific absolute interpreter:

    #!/run/current-system/sw/bin/bash

It also sets an explicit PATH for systemctl, rm and grep:

    PATH=/run/current-system/sw/bin:/usr/bin:/bin

The existing Python mock test was updated to retain its stubbed systemctl program on PATH. The mock harness still passes all six assertions (no override, unmarked, symlink, ordering, original-unit preservation, idempotence).

## Second user-systemd timer: PASS

The reproducible test script tools/test-flick-guard-user-systemd.sh installed a disposable user-level service and runtime-only marked drop-in under /run/user/1001, first verifying the state switched to experimental. It then armed an eight-second systemd user timer to invoke an adapted copy of the SAME guard recovery logic. The setup SSH session finished before the timer fired. A separate verification session returned:

    RECOVERY_RESULT=yes
    DUMMY_AFTER_TIMER=original
    FLICK_PID_AFTER=894
    TIMER_SERVICE_RESULT=success
    DUMMY_SERVICE_STATE=active
    USER_SYSTEMD_INTEGRATION=PASS

The rehearsal removed the user-test override and dummy service. The actual root Flick compositor stayed active with PID 894.

## What is and is not established

PASS: Local recovery shell mocks, an actual tablet systemd user-service rollback, an independent timer after SSH setup exits, and bootloader configuration availability.

NOT YET VERIFIED: Full privileged system-manager integration and a restart of Flick. Desktop Commander's command restrictions blocked the necessary privileged disposable test; those protections have not been modified or bypassed. User-systemd results do not automatically prove system-service restoration. Live compositor tests remain unexecuted, and CPU/GPU savings are not measured.

The staged logging-only, QML raster-skip and native DRM DMA-BUF binaries are preserved. Further live testing requires a supported privileged execution path with a verified system-level watchdog and physical recovery.
