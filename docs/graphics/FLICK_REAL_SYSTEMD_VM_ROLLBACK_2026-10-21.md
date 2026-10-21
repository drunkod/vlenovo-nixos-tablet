# Real system-level systemd rollback timer tested safely in a disposable VM

On 2026-10-21 a root-owned temporary systemd **SYSTEM manager** unit was created **inside the MacBook's Colima Ubuntu Linux VM**. This VM has systemd 255 as PID 1; it is not the Lenovo tablet, and it has no Flick compositor service or DRM/VT control.

The new reproducible test harness tools/test-flick-guard-systemd-vm.sh is fail-closed: it requires EUID 0, a systemd PID 1, Ubuntu /etc/os-release, /run/systemd/system, and REFUSES to execute on any NixOS host with /run/current-system. It uses the same rollback source tools/flick-guard-rollback.sh, substituting only temporary VM-local paths, unit name, Ubuntu shell interpreter and PATH. It does not modify the original script in the repository.

The VM test creates a dummy persistent system-level unit, first running an "original" command, and then testing an opt-in marked experimental drop-in. It verifies:
- No override: script exits safely without restarting the original.
- Unmarked override: script exits 78, leaving the unknown override untouched.
- Symlink override: script exits 78, leaving the unsafe link untouched.
- Valid experimental override: systemd daemon-reload and restart run the distinct experimental command.
- A real SYSTEM-level systemd-run --on-active=8s --timer-property=AccuracySec=1s timer triggers rollback.
- The rollback script removes ONLY its marker-bearing drop-in, reloads systemd, clears failure status, restarts the dummy original unit, and confirms the original state.
- The transient timer service returns Result=success.
- The script's EXIT trap removes all unit, drop-in, temporary scripts and logs; no persistent VM unit remains.

Observed full output: mvp/native/benchmarks/2026-10-21-systemd-vm-rollback-rehearsal.txt. Two repetitions succeeded; the second explicitly verified no temporary files remained. The dedicated Mac test VM was not allowed to influence the tablet's DRM compositor or its live systemd manager.

This is stronger than a mock or user-service systemd test: it exercises a real root/system-service timer and the genuine systemctl command ordering. It is **still not** a privileged test against the Lenovo tablet's actual flick.service, DRM/TTY1 ownership, device failure modes, bootloader recovery or SSH reconnect. Consequently do not claim the tablet can reliably self-restore after a blank-screen compositor failure on the basis of the VM test alone. The tablet's original Flick service and NixOS generation remain unchanged pending a controlled, reversible live A/B.
