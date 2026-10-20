# Flick native DRM idle-CPU investigation (read-only, 2026-10-20)

## Verified live sample

On the Lenovo Miix 2 10 with NixOS 25.05 (Linux 6.12.36), Flick was using around 90% of a CPU core in repeated samples, with its Qt5/QML lockscreen around 30% (occasionally higher) and the independent Slint 1.11 software-rendered MVP near 0% at idle. The tablet has 1.8 GiB RAM and four Intel Atom Z3745 logical CPU cores. The heavy lockscreen and Flick process CPU are **separate from** the new MVP's cost.

Earlier numeric `ps -o %cpu` values are lifetime averages; rely on `top -b -n 2 -d 3 -p ...` for comparable instantaneous samples after the build finishes.

## Source findings, not a diagnosed root cause

In the archived Flick source `.local/references/Flick/shell/src/backend/udev.rs`:

- Line ~490: `event_loop.dispatch(Some(Duration::from_millis(16)), &mut state)`, a 16ms periodic wake-up; alone this does **not** prove a busy-spin.
- Render code around lines ~1954, 1997, 2101 and 2178 forces `slint_ui.request_redraw()`, calls `slint_ui.render()`, creates `MemoryRenderBuffer`, and copies pixel buffers. Investigate whether each path executes even when the UI is unchanged before modifying it.
- On a native 1920x1200 buffer, one uncompressed 32-bit frame is about 9.2 MB decimal. Redrawing and copying many such frames per second could be expensive on a Bay Trail CPU/GPU; this is a throughput estimate, not a measured copy rate.
- The Qt QML lockscreen in `.local/references/Flick/apps/lockscreen/main.qml` contains polling timers at 1000ms and 500ms; measure their cost separately before attributing lockscreen CPU to them.

## Future safe experiment

1. Establish Flick CPU/memory with the lockscreen idle and native MVP idle (no compilation).
2. Instrument render calls, software-buffer allocations and UI-dirty notifications on an **isolated Git branch**; measure frame rate and memory copies with no visible behaviour change.
3. Add conditional rendering and/or a dirty-flag gate in the native DRM backend only after instrumentation. Ensure responsiveness under touch, lock/unlock and screen rotation.
4. Build/test a temporary NixOS generation with SSH and rollback available. Do not replace the known-good boot generation until touch, compositor restart, power and screen acceptances pass.

No changes were made to running Flick, the QML lockscreen, NixOS or any kernel device during this code audit.
