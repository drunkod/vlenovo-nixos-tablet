# Gen60 physical test — WPE WebProcess graphics initialization failure

**2026-10-21 (UTC), physical Lenovo Miix 2 10**. The NixOS candidate called “Gen59 WPE” in source was registered by the system as **profile generation 60**, because profile 59 already held the earlier sandbox test. **Gen60 was intentionally rolled back to profile 58; never call Gen60 successfully accepted.**

## What worked

- Exact running candidate during test: `/nix/store/kvh60glznvcj64mwpy58fgx9g8dqfd8y-nixos-system-vlenovo-25.05.20250708.88983d4`.
- WPE 2.54.1 `/nix/store/zg995gz73dn5jqf4zfzdg6giipja9f9l-wpewebkit-2.54.1` launched with its Bubblewrap security sandbox **enabled**.
- Unlike earlier Gen59 test, D-Bus proxy, network process and isolated WPEWebProcess started and stayed alive until crashing. Bubblewrap included read-only `/nix/store` and WPE no longer failed `execvp xdg-dbus-proxy`.
- Kiosk opened `/dev/dri/card1`, WPEWebProcess opened `/dev/dri/renderD128`, and kiosk opened ELAN input `/dev/input/event4` via libinput. No new i915 GPU hang/reset was logged.
- Main process instantiated `WebKitWebView` and called `webkit_web_view_load_uri(..., http://127.0.0.1:17858/viewer)`; debug stderr captured these milestones.

## Precise failure, from on-device core dumps

- `WPEWebProcess` (example PIDs 6024, 6648) received **SIGABRT**, stack:
  `WebCore::PlatformDisplay::sharedDisplay().cold` → `WebKit::AcceleratedSurface::SwapChain` → `ThreadedCompositor` → `WebPage`.
- Source `Source/WebCore/platform/graphics/PlatformDisplay.cpp` line ~66 has `RELEASE_ASSERT(s_sharedDisplay)`: the renderer failed to establish its shared EGL platform display before the compositor was initialized.
- A plain `GET /viewer` works, but the browser's `load-finished` callback did **not** occur, and the Node scene service reported `clientCount: 0`. **No visible animation or touch reaction can be claimed**.
- Each WebProcess core dump made systemd-coredump temporarily read/write ~**5.3 GiB** on the tablet's eMMC, causing huge I/O pressure, stalled service shutdown, and a temporarily delayed manual restore. Stored compressed dumps were ~2.8 MiB each. Do not repeat this test without protecting disk I/O.
- At ~22:14 UTC, manual restore completed **successfully**: `/run/current-system` and profile returned exactly to `/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4`, Slint/SSH/NetworkManager/seatd active, no failed units. Temporary service overrides and rollback timer removed, memory available ~1.44 GiB, root storage free ~18 GiB. Keep gen58 untouched as golden.

## Next suspected blocker and new candidate

- `Source/WebKit/UIProcess/Launcher/glib/BubblewrapLauncher.cpp` **already bind-mounts `/dev/dri`**. Therefore missing GPU node is NOT the explanation.
- NixOS exposes Mesa's Intel Crocus and GBM runtime driver links at **`/run/opengl-driver/lib/dri`**, which is NOT automatically present in WebKit's isolated WebProcess mount namespace. Its linker/module code needs these paths and the Nix store both.
- Tested an ordinary-user Bubblewrap instance on the real tablet, with read-only `/nix/store` and `/run/opengl-driver` plus DRM device bind: both `/dev/dri/renderD128` and `crocus_dri.so` were readable: **SANDBOX_GPU_ACCESS_OK**.
- Small-kiosk-only change: `webkit_web_context_add_path_to_sandbox(webkit_web_context_get_default(), "/run/opengl-driver", TRUE)` before creating WebView. Existing read-only Nix store mount remains.
- To avoid repeat I/O lockup, **candidate-only** `systemd.coredump.extraConfig` sets `Storage=none`, `ProcessSizeMax=0` and WPE service `LimitCORE=0`. Verify these in generated `etc/systemd/coredump.conf` and service unit. This suppresses debug core files *only while candidate OS active*; does not alter gen58.
- New full NixOS candidate build completed **successfully** at `/nix/store/379vcgigrgc22968zavm0aihhsyr9mhp-nixos-system-vlenovo-25.05.20250708.88983d4`; same exact kernel and initrd as gen58. As of this note, immutable closure transfer was underway; **not yet installed/activated**. Next assigned profile will likely be **61**, not “59”.
- Proposed test: re-run guarded physical activation only after complete store import verification and rollback script preflight, monitor `WebKitWebView load-finished`, SSE `clientCount >=1`, WebProcess survival/CPU/PSS, DRM KMS, GPU render node and hardware taps. Restore gen58 if no page load or any unit/kernel issue.

## Source research

In upstream `WebProcessGLib.cpp`, the renderer attempts to set a `PlatformDisplay` using a GBM render node or surfaceless EGL; when neither works, `sharedDisplay()`'s guard aborts. This makes the missing Mesa runtime path a **testable hypothesis**, not a confirmed ultimate fix.

Upstream recent report https://github.com/microsoft/playwright/issues/43394 describes a *different* `sharedDisplay` abort during **exit** via `BitmapTexturePool` timer; our stacks are at **WebPage accelerated surface initialization**, so that report must not be used as proof these failures share a cause.
