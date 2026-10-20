# Lenovo AI OS — fast Slint Wayland MVP

This is **a prototype, not an NixOS deployment**. It uses the tablet's already-running Flick DRM/Wayland compositor as a display server and runs Slint **1.11.0** as a separate, touch-oriented client. It makes no boot, kernel, graphics-driver, backlight, network-configuration, or systemd changes.

## Tested on the physical tablet (2026-10-20)

- NixOS 25.05 / Linux 6.12.36 / Intel Bay Trail; Flick active, Wayland socket `/run/user/1001/wayland-1`.
- 1.8 GiB RAM installed, 20 GB free on root. Existing compositor and its QML lockscreen were using substantial CPU (Flick about 91% of one core, QML about 31% on one three-second sample).
- Slint viewer installed directly from the Nix binary cache (~43 MiB downloaded, no local Rust compilation).
- `--backend winit-software` launched against Flick's Wayland socket and stayed up through a timed nine-second smoke test.
- A standalone long-lived Slint client used around **79,760 KiB RSS (~78 MiB)** and **0% CPU in a later idle top sample**. This is process resident memory, not the additional physical memory charge; shared libraries can be counted by multiple processes.
- No different NixOS generation was activated; no permanent switch, compositor restart, or flake modification was made. A **separate, controlled reboot of the same generation** was later used to recover ELAN1001; see `../../docs/TOUCHSCREEN_RECOVERY_2026-10-20.md`.
- **Physical touchscreen acceptance subsequently passed on 2026-10-20 after a controlled reboot.** The user confirmed touch worked, and the tablet logged ten actual card callback events across Status, Assist, and Network at 16:54 UTC. The assistant did not independently view the panel; logged events prove the app received touches.

## What it tests

A fast-launching, responsive touch frontend on the old Intel tablet running Slint software rendering over the existing Wayland display. Three cards change Slint-local state. Each touch additionally emits a callback, captured by a small read-only shell bridge in `/home/alex/lenovo-mvp/touch-events.tsv`.

The assistant card is explicitly a **stub**. There is no LLM, on-device inference, command-execution agent, live status model, OS image build, or AI cloud connection in this experiment. Don't present those as tested.

## Run from the MacBook

```bash
cd ~/Documents/Work/vlenovo-nixos-tablet/mvp/slint
bash run-on-tablet.sh start
bash run-on-tablet.sh status
# On the tablet: tap STATUS, ASSIST and NETWORK.
ssh -F ~/.ssh/vlenovo_config vlenovo 'tail -20 ~/lenovo-mvp/touch-events.tsv'
bash run-on-tablet.sh stop
```

The start script copies only this app and its callback bridge, not the whole NixOS repo. It does not launch another compositor. The viewer is started as the regular `alex` user. The backend library paths currently refer to the exact Nix store paths that worked on the tablet; they may require updating after future garbage collection or NixOS upgrades.

## Manual acceptance gates

1. **Visibility:** Verify `Lenovo OS` launcher appears; if the lock screen covers it, unlock normally (do not kill Flick or the lockscreen over SSH).
2. **Touch:** Tap each of three large cards and see the response/counter change; check `touch-events.tsv` was appended.
3. **Performance:** Run `top -b -n 2 -d 3 -p $(cat ~/lenovo-mvp/viewer.pid)` on the tablet. Confirm idle CPU near zero and interaction fast; note whether Flick still draws heavily in the background.
4. **Recovery:** Stop with `bash run-on-tablet.sh stop`, verify the standard Flick interface remains, and check `systemctl is-active flick sshd NetworkManager`.
5. **Next gate:** If screen/touch and idle CPU pass, build a small Rust system-status/command backend and wire it to Slint; thereafter benchmark responsiveness and memory. Only later package an optional NixOS service and test temporary activation, leaving the boot generation untouched until approved.

## Why this approach

The tablet has a working native DRM/KMS stack and Flick already uses Slint internally. Rebuilding the full Flick/Smithay compositor is much slower and risks destabilizing SSH and the screen. By testing an ordinary Slint Wayland client first, we isolate the usability hypothesis from graphics integration and NixOS activation.

**Known limitation:** Flick itself and its existing Qt5 lockscreen consumed far more CPU at idle than this Slint client. That should be investigated before replacing the whole desktop.
