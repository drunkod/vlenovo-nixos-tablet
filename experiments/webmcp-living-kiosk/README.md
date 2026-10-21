# Living tablet WebMCP-style remote animation lab

**Forked from the touch/GPU-verified Generation 58 golden branch.** Everything here runs on the MacBook and is user-space research only. Nothing changes the tablet's running NixOS generation, service, DRM master, i915, ELAN1001 driver or IA32 bootloader.

This is a functional **control-transport and HTML animation prototype**, *not* yet a physical WPE/eBoard direct-KMS build.

## Run now on the connected MacBook

```sh
cd ~/Documents/Work/vlenovo-nixos-tablet/.local/worktrees/vlenovo-webmcp-living/experiments/webmcp-living-kiosk
node server.mjs
```

The server prints a temporary token to your **local terminal**, then visit:

- `http://127.0.0.1:17858/viewer` — the user-provided Living Object Canvas demo with remote scene subscription and feature-detected WebMCP page-local tools.
- `http://127.0.0.1:17858/controller` — the control deck with six expressive scene presets, energy, hue and caption. Paste the temporary token when first using its controls.

Run `node smoke-test.mjs` in another terminal for a separate randomly authenticated loopback instance; verifies authorization, invalid-fields rejection, cross-origin checks, state API and **live SSE push**, and static frontend routes.

The server is **dependency-free Node** for rapid prototyping; the eventual tablet daemon should be Rust (axum/Tokio/serde), reusing the wire protocol. No shell commands, dynamic URL loads or system controls are exposed remotely.

### Scene wire format (intentionally small)

```http
POST /api/scene
Content-Type: application/json
X-Scene-Token: <ephemeral token>

{"mode":"orbit","hue":60,"energy":1.2,"label":"Hello, tablet","pulse":true}
```

`GET /api/stream` sends SSE revisioned state with `seq`; `GET /api/state` returns current state; `GET /health` checks service status. The fields are strictly allowlisted/validated. No control token is persisted in the browser; read-only SSE carries only public animation state.

**Phone/network safety:** By default port 17858 is **bound only to localhost**, so the phone cannot access it yet. If we decide to test LAN control later, explicitly use a secure tunnel/TLS reverse proxy with a separate agent credential and tight ACL. `SCENE_ALLOW_LAN=yes SCENE_BIND=0.0.0.0` is allowed for an **isolated trusted lab only**; it carries a token over **unencrypted HTTP**, so do not use on open/shared Wi-Fi or expose to the internet. Mac OS firewall may also block the port. Production tablet startup should use loopback only and a private authenticated ingress.

### WebMCP distinction

As of the October 2026 draft, pages may register `document.modelContext.registerTool(...)` in supporting secure-context browsers. `viewer.html` and `controller.html` both **feature-detect** this and fall back transparently when absent. Browser WebMCP is an *agent-facing page API*, **not** a network protocol and **not** an MCP stdio/HTTP server. WPE 2.54 support has **not** been verified. The phone-to-display path works with ordinary SSE and authenticated HTTP regardless.

### Source/provenance

- `web/viewer.html` is based on the user's Mac `Documents/Living_Object_Touch_Demo_2026-10-21.html` research artifact, keeping breathe/orbit/tide/touch animation and adding remote state, hue/energy control, captions and optional WebMCP tools.
- `web/controller.html` and `server.mjs` are new demonstration components.
- `DESIGN_OPTIONS.md` compares two serious future OS-image concepts—**WPE WebKit 2.54 DRM** and **eboard Rust egui KMS**—plus the Servo/retsurf wildcard.
- Do not assume a browser passing the localhost demo is already hardware accelerated. Physical GPU/touch acceptance must be performed only under a rollback-protected KMS test and assessed against original Slint gen58.

## Reproducible next hardware build

The tablet's pinned nixpkgs (commit `88983d4`) was checked and has **no top-level `wpewebkit` package**; WebKitGTK is a different backend and does not satisfy direct DRM. The third-party `eval-exec/nix-wpe-webkit` flake has an old **2.52.3** package as of this audit, not the WPE **2.54.1** required for the new stable WPEPlatform/DRM stack; do **not** silently use it as if it proves direct-DRM behavior. To test WPE use a separately pinned, audited **2.54.x package overlay**, build on the Mac's x86_64 Colima Nix builder, then transfer only a new closure to the tablet. Boot system gen58 remains unchanged.

eBoard can be independently packaged and tested with a small egui GPU/text/touch demonstration. The source report's eboard 2026/KMS claims are a **promising lead, not proof on our Atom Z3745**.

See `DESIGN_OPTIONS.md` for safety and acceptance checks.
