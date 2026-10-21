# Generation 59: WPE 2.54 Bubblewrap sandbox compatibility retest

Recorded 2026-10-21. This document supersedes any older status stating the WPE fullscreen kiosk was never installed: **NixOS generation 59 was physically installed for a controlled live test, then intentionally rolled back to generation 58**. Preserve both generations and the production-proven gen58 golden branch.

## Evidence from physical Lenovo test

- Native x86_64 GitHub Actions WPE 2.54.1 run `39616428062` succeeded. The 66 MB compressed artifact passed SHA-256 verification; imported WPE Nix outputs to the Mac Linux builder and built kiosk and full NixOS image.
- Exact first Gen59 system: `/nix/store/niipnm5sbdylwwhw4msj6r28xcv5y6h6-nixos-system-vlenovo-25.05.20250708.88983d4`, **installed as profile generation 59**, using the exact same kernel, initrd and IA32 GRUB setup as touch-proven gen58.
- New immutable Nix closure staged onto physical tablet (167 paths), `nix-store --verify-path` succeeded. Full system `/nix/store` contains the WPE 2.54.1 engine.
- Initial WPE sandbox startup: Bubblewrap failed `Unexpected capabilities but not setuid`. The PAM login session was found to confer `CAP_WAKE_ALARM`. Verified with a transient systemd probe that `CapabilityBoundingSet=~CAP_WAKE_ALARM` and `NoNewPrivileges=yes` result in zero inherited/permitted/effective/ambient caps. **These lines are now committed as NixOS service properties, not a temporary bypass.**
- After clearing these caps, WPE progressed to spawning `xdg-dbus-proxy` but aborted: `bwrap: execvp /nix/store/ssdr6278b43lcd2zx8y9r6p2bw62yn8l-xdg-dbus-proxy-0.1.9/bin/xdg-dbus-proxy: No such file or directory`. That executable **exists** on the host and runs (`xdg-dbus-proxy 0.1.9`); failure is that WPE's bubblewrap mount namespace omits Nix store paths. The WebKit process aborted (ABRT core dump). The Slint OnFailure service restored screen ownership successfully.
- **Diagnostic, NOT acceptable for permanent boot:** `WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1` allowed WPE's DRM kiosk to run, open `/dev/dri/card1`, and establish an SSE listener to the local scene service (`clientCount=1`). Available system memory was ~1.31 GiB. This confirms the basic browser/Canvas/DRM control path but does not independently prove visible pixels, GPU frame pacing, finger mapping or WebMCP native support.
- A first attempt adding `webkit_web_context_add_path_to_sandbox(..., "/nix/store", TRUE)` in `kiosk.c` did not affect the separate D-Bus proxy process. It is retained as defense-in-depth for WebProcess; a patch to WebKit's **global** bubblewrap launcher is required.
- After the failed secure test, `restore-gen58.sh` manually restored exact gen58 system/profile: `/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4`. Slint, SSH, NetworkManager and seatd all active, zero failed units. Temporary overrides and the rollback timer were stopped. **Never assume Gen59 is active from the profile number alone**; inspect `/run/current-system`.

## Proposed upstream-compatible fix

- Add `--ro-bind-try /nix/store /nix/store` to `Source/WebKit/UIProcess/Launcher/glib/BubblewrapLauncher.cpp` in WPE 2.54.1 before `--dev /dev`, included as `patch-nix-store-in-bubblewrap.patch` in the Nix overlay.
- **Verified on the physical Lenovo**, as user `alex` outside the graphical session: Bubblewrap `0.12.0` running `xdg-dbus-proxy --version` fails exactly as above without the read-only `/nix/store` mount and exits successfully with the mount. This directly exercises the missing runtime loader/dependency root without disabling sandboxing.
- The mount exposes host `/nix/store` read-only, not as a writable filesystem. It remains a broader read-only view than ideal; a future optimization would bind only the WebKit process closure. It is safer than disabling the sandbox.

## Controlled retest plan

1. Build **patched WPE engine** in a NEW native x86_64 GitHub Actions job, not the old 2.54.1 unpatched output; verify output hashes and build's exact derivation reference the patch.
2. Transfer patched outputs to Mac Colima Nix builder, build matching kiosk + full NixOS system with no changed Linux kernel/initrd, and stage **only immutable store paths** on tablet.
3. Put confirmed `/run/lenovo-gen59-restore.sh` and `activate-gen59.sh` on tablet, run preflight, arm the independent eight-minute rollback timer **before** switching display/profile.
4. Ensure **WebKit sandbox remains enabled**: never set `WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS`. Confirm WPE no longer crashes in XDG proxy. Check page-load callback, `clientCount>=1`, browser subprocesses, DRM card1 and GPU render node, all process PSS/CPU and ELAN1001 event data.
5. If stable, ask user to confirm actual rendered pixels, 1920x1200 display, orientation, tap response. Until verified, manually revert to gen58 before the rollback timer expires. Do not reboot into an unverified display.

**Warning:** The existing NixOS profile number 59 refers to the *first*, unsuccessful experimental live activation. NixOS may assign a higher generation number to the corrected configuration. Do not overwrite/delete 58 or silently call a new Nix-store path the original generation 59.
