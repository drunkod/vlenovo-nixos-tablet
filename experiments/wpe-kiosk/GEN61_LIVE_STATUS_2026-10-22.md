# Lenovo WPE Living Nebula — generation 61 live test

**UTC 2026-10-22 01:13**, physical Lenovo Miix 2 10. This is the **third** experimental profile in the generation-59 WPE design series: the active NixOS profile is **61**. Profiles 59 and 60 were unsuccessful experiments; physical generation 58 is the protected Slint golden baseline.

## Exact reproducible candidate

- NixOS profile 61, booted gen58 then live switched to `/nix/store/379vcgigrgc22968zavm0aihhsyr9mhp-nixos-system-vlenovo-25.05.20250708.88983d4` on 2026-10-21 at 22:28 UTC.
- WPE WebKit 2.54.1 (sandboxed): `/nix/store/zg995gz73dn5jqf4zfzdg6giipja9f9l-wpewebkit-2.54.1`, originally compiled natively on GitHub Actions run `39644717396` from WPE patch `d7dc855`.
- Launcher: `/nix/store/35f4lxzr04sn123vg9jlxj2bn273skfa-lenovo-wpe-kiosk-0.1.0`.
- Same exact kernel `/nix/store/mifh5p043cma8pbywl2lvlkp1z1bd8i2-linux-6.12.36/bzImage`, initrd `/nix/store/8hla2afa7n9vgs76l3558wy7gywxv8gv-initrd-linux-6.12.36/initrd`, i915, Crocus and IA32 GRUB as physical generation 58.
- Launcher mounts `/nix/store` and `/run/opengl-driver` read-only in the WebProcess Bubblewrap sandbox, allowing host Mesa Crocus DRI entry points within the isolated compositor.
- Candidate safeguards: `systemd.coredump.extraConfig` sets `Storage=none`, `ProcessSizeMax=0`; kiosk has `LimitCORE=0`, `MemoryHigh=800M`, `MemoryMax=950M`. These prevent the **5.3 GiB per-crash** temporary eMMC I/O that previously delayed a recovery switch. No kernel/initrd changes.

## Verified during live operation

At 01:10-01:13 UTC on October 22 (over 2h40m since activation):
- `/run/current-system` AND `/nix/var/nix/profiles/system` still point to the exact candidate path, and the physical NixOS generation list labels it `61 (current)`.
- `lenovo-wpe-kiosk.service`, `lenovo-wpe-scene.service`, `sshd`, `NetworkManager` and `seatd` are active; WPE service `NRestarts=0`, `Result=success`.
- `GET http://127.0.0.1:17858/health` returns `{"ok":true,"clientCount":1}` repeatedly, meaning the on-tablet WebProcess has an active server-sent-events animation subscriber. This proves browser-side script execution, **not independently verified physical pixels or finger-tap accuracy**.
- Main kiosk held /dev/dri/card1 and /dev/input/event4; sandboxed WPEWebProcess held /dev/dri/renderD128. DSI-1 connector connected at **1920x1200**. No i915 GPU hang/reset messages.
- `free -m`: approximately **1.25 GiB available** system RAM, total 1.866 GiB. WPEWebProcess average CPU around **36% of one logical processor** over its first 2h43; significant continuous animation power cost compared with Slint. Do not mistake this for whole-system CPU percentage.
- No new WPE coredumps reported during the stable run. No failed application units; one failed rollback *timer service* arose because of missing PATH.

## Rollback failure and repair

The original `gen59-rollback.timer` expired at 2026-10-21 22:36:33 UTC, but the service exited status 1:
`/run/lenovo-gen59-restore.sh: line 8: readlink: command not found`.
A systemd transient service does not have the interactive SSH shell's `PATH`. The script printed a misleading `gen58 path changed` message because command substitution failed.

**Patched `restore-gen58.sh`** explicitly sets `PATH=/run/current-system/sw/bin:/nix/var/nix/profiles/system-58-link/sw/bin:/usr/bin:/bin`, provides a zero-impact `check` mode and limits WPE systemctl stop to 30 seconds. Copied to `/run/lenovo-gen59-restore.sh` on tablet. The two safe preflight checks passed:
1. `sudo env -i /run/lenovo-gen59-restore.sh check` returned `GEN58_ROLLBACK_PREFLIGHT_OK`.
2. `sudo systemd-run --unit=gen61-rollback-preflight --wait --collect --property=Type=oneshot /run/lenovo-gen59-restore.sh check` exited 0/SUCCESS, consuming 56 ms.

The old failed service was reset, yielding zero failed systemd units. A **new** `gen61-rollback.timer` was armed at 2026-10-22 01:13:37 UTC to trigger the corrected script at **01:43:37 UTC**. This exact rollback *switch* has not yet been exercised after the PATH fix (only its systemd preflight); it is designed to restore profile 58. Never claim a full rollback occurred until its final current-system path is checked.

## Physical acceptance outstanding

Despite the working WebProcess, remote tools do not prove visible on-screen pixels, tablet rotation, accurate finger touches, GPU animation smoothness, or battery draw. User must confirm orb is visible and touch-responsive. Until confirmed, retain the time-bound generation-58 rollback and do not call generation 61 a permanent golden.

### Next optimization after display acceptance

- WPE WebProcess continuously consumes around 36% of one core while animation runs. Measure frametime and battery load, add capped frame rate / reduced activity at idle, compare Slint gen58 memory and responsiveness. Avoid optimizing by disabling GPU or security sandbox.
- Phone control remains loopback-only for security; WebMCP feature-detection is not proof WPE supports `document.modelContext`.
