# Lenovo Generation 58 → animated living interface (design candidates)

**Source:** The MacBook's `Documents/Rust_Browsers_and_Living_Animations_Tablet_Research_2026-10-21.md` (506 lines, 53 KB) and its associated offline `Living_Object_Touch_Demo_2026-10-21.html`. These designs extend the report with remote control and WebMCP, which the original research **does not discuss**. Verified primary sources: WPE 2.54/WPEPlatform, eboard, WebMCP W3C draft, retsurf/SDL. This branch is based on the *user-touch-verified* gen58 commit `8a422fd`, not an installed NixOS generation.

## Current hardware constraints, physically observed

- Lenovo Miix 2 10, Intel Atom Z3745 Bay Trail, Intel GPU `8086:0f31`, kernel 6.12.36, Mesa Crocus, DSI-1 active **1920 × 1200** through **`/dev/dri/card1`**, hardware render node `/dev/dri/renderD128`.
- ELAN1001 I²C HID touchscreen is currently `/dev/input/event4`, but **event number is not stable**; use libinput and udev identity.
- Gen58 binary `lenovo-native-mvp`, Slint 1.7.2 with `linuxkms-femtovg`, `seatd`, PAM tty1. `lenovo-slint-dashboard.service` owns DRM master; no compositor. First-hand confirmation of very responsive physical finger taps.
- Recent gen58 check: **~76,167 KiB Slint process PSS**, **~1,472 MiB MemAvailable** out of **1,866 MiB** total. Full new browser memory must be **sum of helper-process PSS + graphics allocations**, not just one process.
- Boot firmware is **IA32 UEFI** even though CPU/kernel is x86_64. Keep gen58 EFI/GRUB/kernel/initrd, i915, Wi-Fi/SSH and ELAN touch unchanged. Any new user-space image is x86_64-linux and can be built on the Mac's x86_64 Colima Nix builder and copied to the tablet as a Nix-store closure.

## Pick two production experiments, not three kernels

### Candidate A: WPE WebKit 2.54 Direct DRM — the living web kiosk

**Use when:** rich HTML/CSS/JS Canvas, SVG, Web animations and eventually web video matter most.

```text
Phone / Mac voice controller           Tablet x86_64 NixOS 58-derived image
 └─ agent / Web UI ─ HTTPS/Tunnel ─┐
                                   ↓
                             Rust scene-control service
                       strict allowlist + authenticated HTTP
                                   │
                         SSE /api/stream (localhost)
                                   ↓
   WPE 2.54 WebKitWebView → WPE_PLATFORM=drm → GBM/EGL → i915
             ↑                                ↓
      ELAN1001 touchscreen                  DSI-1 1920×1200
```

Use upstream **WPEPlatform** directly; no Cog/WPEBackend-fdo or Wayland required. It implements DRM presentation and input (but test Bay Trail Crocus/Skia/EGL and seatd/VT ownership). WPE is C++/GLib/WebKit, **not 100% Rust**, and compiling/pulling into a 2GiB tablet may add considerable closure/process memory. WPE 2.54 is newer than the tablet's pinned 2025 Nixpkgs; **do not assume the old Nix package provides the new DRM backend**. Build/package on the Mac using a **separate pinned newer nixpkgs overlay** and verify on Mac/container before risking any DRM switch.

**Visual:** a luminous organic character or instrument, fullscreen CSS/SVG/Canvas; remote voice commands turn modes from sleep → listen → pulse → orbit, change hue/intensity and show one short status message. Try 30fps moving and lower idle rate; WebKit may or may not GPU-accelerate every Canvas path. Browser may own only one KMS master; never start concurrently with Slint on the same VT/output.

**WebMCP caveat:** its October-2026 draft API is **`document.modelContext.registerTool`**, not legacy `navigator.modelContext`. Browser support in WPE has **not been verified**. The app must work by standard HTTP/SSE without this API; the WebMCP registration is an optional agent-facing adapter **inside a supporting page**, not a remote network server.

### Candidate B: eboard + egui + EGL — native Rust living cockpit

**Use when:** minimal process RAM, stable touch reaction and native Rust code matter more than arbitrary HTML/JavaScript/video.

```text
Phone ─── same authenticated Rust scene protocol ────┐
                                                      ↓
                                          Tokio channels / Rust state
                                                      ↓
                              egui state + custom OpenGL Glow shader
                                                      ↓
                            eboard KMS/GBM/EGL + libinput → i915
                                                      ↑
                                                 ELAN1001 touch
```

eboard handles an embedded direct-KMS route; inspect its 2026 release source first and test Intel's Mesa Crocus EGL and seatd/VT behavior. A GLSL orbital/particle shader drawing only changed uniforms should keep CPU wakeups low; use egui for small touch controls and text. Optional later art assets: Vello+Velato or dotLottie/Rive, but they don't own DRM themselves. **No WebMCP inside eboard**, because there is no browser; the Rust sidecar can expose equivalent schema-controlled tools over an MCP server endpoint to an authorized agent. We can get functional remote control before introducing any browser.

**Visual:** a planetarium console with a breathing orb, satellite rings for Wi-Fi/battery, expressive creature moods and tactile ripples. Fullscreen animation rendered by i915 without a desktop compositor.

### Wildcard C: Servo/retsurf + SDL2 KMSDRM — pocket science-fiction browser

A handheld-first **Rust browser** with no Wayland, if its SDL2 build includes the KMSDRM backend. Stage **SDL2 KMS DRM + ELAN1001 touch mapping** smoke tests ahead of compiling Servo or building a new NixOS image. SDL issue discussions document KMS touch event routing differences; do not assume gamepad-driven retsurf translates finger events correctly. Larger and riskier than B, likely less web-compatible than A today. If viable, make the tablet a voice-controlled retro handheld portal.

## Creative scenes (same protocol works across A/B/C)

| Scene | Look | Input/remote change |
|---|---|---|
| **Listening nebula** | Slow teal orb, tiny orbiting particles, bright center | Phone voice “listen” → energy 0.7, golden glow; finger tap emits ripple |
| **Dream garden** | Soft breathing Lottie-like creature/flower; background gently drifts | Quiet hours → “sleep”, reduce animation to 12–15 fps |
| **Storm engine** | Electromagnetic rings with GPU fragment shader distortion | “storm” → tide mode, high energy, shifted hue |
| **Ambient cockpit** | Living compass/satellite elements around power/Wi-Fi/weather | Telemetry feeds intensity, user taps to expand details |
| **Story portal** | Touch transitions between local HTML scenes or illustrated chapters | AI on phone says “open ocean”, page changes without a remote-desktop pixel stream |
| **AI expression surface** | Minimal eyes/face that conveys listening/thinking/responding | MCP tool called `set_tablet_animation` switches state, text safely limited to 80 characters |

The prototype uses the three original Canvas states **breathe/orbit/tide** and adds remotely selectable presets, hue, energy, ripple/pulse and caption.

## Remote control is NOT equivalent to WebMCP

```text
[phone agent] ────── authenticated network transport ──┐
[phone browser] ──── authenticated HTTP POST ──────────┼→ scene service
                                                       │      |
                                              /api/state + SSE events
                                                       │      ↓
                                            tablet visual renderer
```

A real MCP server may expose `set_tablet_animation(mode,hue,energy,label,pulse)`, `pulse`, `get_tablet_status` to an authorized remote agent. A page with native WebMCP support can additionally register `document.modelContext.registerTool` actions, but that browser API does **not** provide phone-to-tablet transport or bypass authentication. The **same state reducer** is the integration boundary; frontend choice becomes interchangeable.

**Security:** keep all writes allowlisted: mode `breathe|orbit|tide`, integer hue -180..180, numeric energy 0..2, caption ≤80, boolean pulse; no shell execution, no arbitrary URL, no file writes, no remote browser navigation. Default listener `127.0.0.1`; demo LAN bind requires deliberate opt-in, short-lived token, rate limiting and origin checks, and is *not encrypted*. For real phone control use HTTPS via an authenticated tunnel/proxy (e.g. WireGuard/Tailscale with ACL or local TLS gateway), never expose an HTTP token to the internet. Browser WebMCP tools, if supported, still require authorization.

## Near-term benchmarks and rollback

1. **Completed:** Mac-local HTML demo /viewer + /controller, dependency-free Node control-plane **scaffold** (production target is Rust/axum). This prototype changes zero OS settings and is not running on the tablet.
2. **Read-only** package audit: determine WPE 2.54 Nix availability, eboard current source and KMS/seat ABI, check card1/DSI-1 and actual 1920×1200 scanout.
3. Package **A and B in separate Nix derivations**, cross/build on Mac x86_64 builder; do not swap kernel, graphics or touchscreen drivers.
4. Start each alternative only as **bounded live maintenance test**: independent systemd restore timer first, stop gen58 Slint temporarily to release DRM master, run one candidate on tty1 under existing seatd/user permissions, record 30+ real finger taps, dynamic input device discovery, i915 render allocations, full process-tree PSS and CPU, then **always return** to Slint gen58.
5. Promote only once wakeups, real tap response, GPU acceleration and memory make sense, and failure restoration is proven. Version 58 remains the boot default. Keep generations 57/56 and the golden GitHub branch unchanged.

**Recommended first choice:** A + B, with B as the performance/privacy fallback. Wildcard C is a follow-on curiosity, not the boot default.

## Primary sources consulted

- Local Mac report: `~/Documents/Rust_Browsers_and_Living_Animations_Tablet_Research_2026-10-21.md` — options, source audit, DRM/input cautions, WebKit examples and native Rust alternatives.
- WPE 2.54 release https://wpewebkit.org/blog/2026-09-16-wpewebkit-2.54.html
- WPEPlatform reference https://wpewebkit.org/blog/2026-10-06-wpe-platform.html
- W3C WebMCP draft source https://github.com/webmachinelearning/webmcp/blob/main/index.bs (current `document.modelContext`)
- Rust-native eboard documentation https://docs.rs/eboard/latest/eboard/
- retsurf https://github.com/mxmgorin/retsurf
- SDL touch issue https://github.com/libsdl-org/SDL/issues/14644

No hardware features, WPE support or touchscreen success have been claimed for these replacement engines.
