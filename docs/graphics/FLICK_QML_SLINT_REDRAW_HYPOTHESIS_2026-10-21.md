# Flick lock screen: potentially unused full-screen Slint rasterization (2026-10-21)

## Evidence, not yet a performance result

The deployed Flick source is pinned to `ruapotato/Flick` commit `729cdece...` plus the six NixOS integration patches. In `shell/src/backend/udev.rs`:

- Inside `render_surface()`, the general Slint path sets `view = "lock"` for `ShellView::LockScreen`, processes Slint events and then calls `request_redraw()` followed by `render()` regardless of whether the QML lock screen is present (around post-patch source lines 935–1135).
- It constructs a new `MemoryRenderBuffer` and clones/copies the full Slint RGBA pixel array to a GPU-importable render element. A 1920×1200 4-byte-per-pixel image contains **9,216,000 bytes (~8.79 MiB)**, exclusive of additional copies.
- Later, when `shell_view == ShellView::LockScreen && state.shell.lock_screen_active && state.space.elements().count() > 0`, Flick selects the **QML-only** render branch, which says it uses only QML window elements and does **not** include the previously created full-screen Slint element (approximately lines 1545–1600).
- When the QML lock screen needs the on-screen keyboard, that branch separately sets Slint to `"app"`, processes events and renders/crops the keyboard overlay. This keyboard path must remain functional.
- The live log earlier recorded repeated `Slint render result: Some((1920, 1200))` during `LockScreen`, alongside fresh output damage tracking; Flick used around 89–90% of a CPU core. The observation supports repeated work but **does not prove all 90% CPU originates from Slint**.

## Narrow experimental patch — NOT in the build package

`patches/flick/0002-skip-qml-obscured-slint-render-experimental.patch` is an **unactivated research candidate** for application *after* the 30-site logging patch. It adds a QML-cover guard around only the general full-screen `request_redraw` / `render` / buffer-create-copy-import block:

```rust
let qml_lock_covers_slint = shell_view == ShellView::LockScreen
    && state.shell.lock_screen_active
    && state.space.elements().count() > 0;
if !qml_lock_covers_slint {
    // Existing full-screen Slint request_redraw/render and texture upload.
}
```

The general `slint_ui.process_events()` call **still runs**, and the QML branch's separate keyboard renderer is left untouched. The normal Slint fallback remains available if there is no QML window or `lock_screen_active` is false; other shell views are unaffected by the guard. This eliminates work that appears unused in the QML lock-screen branch, but the condition requires runtime verification: `space.elements()` could contain windows not belonging to the QML lock screen.

## Verification and acceptance gates

- Checked source transformation against the exact upstream source reconstructed with six NixOS patches and the previous logging changes; `git apply --check` passed for the experimental second patch. **Rust compilation, visual behaviour and CPU benefit are not yet verified.**
- Do **not** apply patch 0002 to the first logging-only Nix candidate: changing two concerns at once would prevent attribution.
- For a separate follow-up candidate, add patch 0002 as an eighth patch after the log patch, compile it, and test the QML lock screen, PIN entry, unlock, keyboard appearance/dismissal, no-QML Slint fallback, notifications, touch feedback and VT switching.
- Compare idle Flick CPU/PSS, logs, GPU frequency, actual Slint full-screen buffer allocations/copies, frame callbacks, and touch latency. Test for regressions in QML lock screen coverage and video composition.
- Never restart the compositor over SSH without an explicit rollback gate and physical access. The active tablet compositor and NixOS boot generation remain unchanged.

## Independent experimental packaging and updated live baseline

A new standalone flake target `experiments/flick-build#flick-qml-experimental` was added without changing the proven `flick.unwrapped` logging-only output. It appends `experiments/flick-build/patches/flick/0008-skip-qml-obscured-slint-render.patch` to the six integration patches and seventh logging patch. The Nix derivation evaluated and the **actual Nix patchPhase applied all eight patches** before Cargo release compilation began.

A fresh **read-only 10-second baseline** was captured at `2026-10-20T19:57:16Z`: Flick CPU **90.3% of one core**, log throughput **6,565.8 bytes/s**, RSS **130,076 KiB**. The active log specifically showed `render_surface: view=LockScreen`, `Slint render result: Some((1920, 1200))`, and an external QML lock-screen branch. Evidence: `mvp/native/benchmarks/2026-10-21-flick-pre-qml-opt.txt`. These are *pre-activation* measurements; they do not establish a patch improvement.

## Log-derived render count (follow-up; 2026-10-20 UTC)

A second read-only 10-second measurement collected exactly the newly appended log bytes from the existing Flick logfile. It counted **57** `Slint render result: Some((1920, 1200))` events, **57** `render_surface: view=LockScreen` events, **57** fresh damage-tracker creations, and **57** QML lock-screen branch executions. The segment contained 69,865 bytes of logs.

At **5.7 frames/s**, the two explicit full-frame `pixels.clone()` and `buffer.copy_from_slice(...)` operations *would* together write around **105 MB/s** (57 × 2 × 9,216,000 bytes ÷ 10 s), ignoring allocations, Slint rasterization and GPU uploads. This is a **source-based traffic estimate**, not memory-bandwidth instrumentation or a measured speed-up. Full dataset: `mvp/native/benchmarks/2026-10-21-flick-qml-idle-render-counts.txt`.

The evidence also shows 5.7 newly constructed output damage trackers per second, even though a dedicated one is retained per surface. Reusing a damage tracker requires a **separate** careful correctness investigation of buffer ages, output transitions, keyboard overlays and damage propagation; do not mix it into the current QML render-skip candidate.
