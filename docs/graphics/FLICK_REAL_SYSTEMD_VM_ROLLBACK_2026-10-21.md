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

## Additional real-systemd failure-injection and disconnected-controller tests

A third test in the same isolated VM intentionally replaced the dummy experimental unit's command with /usr/bin/false, causing an actual failed service-start result and systemd's failed state. The root systemd rollback timer then removed the explicitly marked override, reloaded the daemon, reset the unit's failure status, and restarted its original healthy command. All failure-injection and recovery checks passed, and the VM's temporary unit files were removed.

Evidence: mvp/native/benchmarks/2026-10-21-systemd-vm-crashed-service-recovery.txt.

A fourth test used **two separate Mac-to-VM remote command sessions**. The first created the temporary root system service and marked experimental override, armed a real 12-second systemd timer, and then exited its control shell BEFORE the timer fired. After 18 seconds, a second independent connection checked that the timer had triggered, removed the override, restored the original state and returned Result=success. The second command removed the entire test unit and state directory. This demonstrates that systemd timer recovery does not require the initiating SSH/shell session to remain alive.

Evidence: mvp/native/benchmarks/2026-10-21-systemd-vm-disconnected-initiator-recovery.txt. Reproduction: tools/test-flick-guard-systemd-detached-vm.sh arm, wait for timer, verify; the script explicitly refuses NixOS, non-Ubuntu or non-systemd hosts.

These tests are VM-only and do not confirm real DRM seat release, hardware recoverability or privileged system-manager commands on the Lenovo tablet. They do establish that the rollback logic and recovery timer survive an experimental unit failure and the initiating remote connection exiting.
