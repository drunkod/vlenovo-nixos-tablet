# Generation 59 WPE Living Nebula — active build and physical staging

Recorded 2026-10-21 ~14:17 UTC. Branch `lenovo-gen59-wpe-living-nebula`. **Do not state that Gen59 has been installed until its entire NixOS closure builds and a new tablet profile is activated.** The physical tablet **still boots Gen58**.

## Diagnosed and fixed

Initial WPE WebKit 2.54.1 derivation `/nix/store/zivy8n5zfmixy8z411dfbdla8pszzvs5-wpewebkit-2.54.1.drv` failed during CMake configuration with:

```text
CMake Error at Source/cmake/OptionsWPE.cmake:405 (message):
  Enchant is needed for ENABLE_SPELLCHECK
```

The 2026 Nix package overlay inherited spellcheck defaults without Enchant. The correct intentional feature choice for a fullscreen canvas kiosk was to append `(cmakeBool "ENABLE_SPELLCHECK" false)` to the WPE override. This fix is committed to the experimental Git branch (`5b26fe3`). The new derivation `/nix/store/8bdld3a4bdnkzm934n1j4n2p13jlwici-wpewebkit-2.54.1.drv` **successfully passed CMake configuration and began compiling 8,883 Ninja tasks**. Last read-only check ~14:16 UTC: **2,369/8,883 steps**, still compiling, no fatal error detected, Nix Linux builder 6.7GiB disk free / 4.2GiB MemAvailable. Rosetta x86_64 C++ compilation takes considerable time. `--max-jobs 2 --cores 2` retains RAM headroom.

## Build location

- MacBook worktree: `~/Documents/Work/vlenovo-nixos-tablet/.local/worktrees/vlenovo-gen59-wpe`.
- Nix source: `experiments/wpe-kiosk/flake.nix` and pinned `flake.lock`.
- Linux Docker context: `colima-vlenovo-flick-build`.
- Running container: `vlenovo-flick-nixbuild`, synced flake at `/nextgen59-wpe`.
- **CURRENT WPE build log:** `/tmp/wpe59-build-retry.log` inside the container; **result when finished:** `/tmp/wpe59-build-retry.rc`. The *older* `/tmp/wpe59-build.rc=1` is the **fixed spellcheck error**, not current build outcome.
- WPE 2.54.1 source from `wpewebkit.org/releases/wpewebkit-2.54.1.tar.xz`, SHA256 `0de8bdfba011f9cd63ba9a9171fa6038dd2c08237894f4082abbb821f29d3fe9`.
- Source-level review of WPEPlatform DRM confirmed `WPEDisplayDRM.cpp` enumerates DRM card devices, acquires DRM master, supports atomic modesets and chooses connectors; `WPEDRMSeat.cpp` discovers touch input via libinput/udev. `WPEDRMSessionLogind.cpp` can call systemd-logind's TakeDevice. **These are potential compatibility paths, not proven tablet behavior.** The actual tablet's `systemd-logind`, `seat0` and `alex` tty1 login session were independently confirmed active.

## Successful physical staging (without display change)

1. Nix package `packages.x86_64-linux.webAssets` built **exit 0** on the Mac, store `/nix/store/wn58bfazs29ygd79hr7zmmd1ccmh7wgn-lenovo-living-nebula-web`. Imported to physical Lenovo and `nix-store --verify-path` succeeded. Contains local `web/viewer.html`, `web/controller.html`, `server.mjs`. Viewer SHA256 `21fc8b6f749cdcadea6ed48cb34053e71988b98c3aa840275c0f357976a57c90`.
2. Pinned Node 22.16.0 built/obtained from binary cache at `/nix/store/a1kxazxkgw7mjbjgisvah95p1r3n5ykl-nodejs-22.16.0`, only eight additional Nix-store paths vs running gen58. Imported and verified on tablet; `node --version` returned `v22.16.0`.
3. Temporarily launched Node scene service on tablet via `systemd-run --unit=gen59-nebula-preview` with `SCENE_BIND=127.0.0.1`, without changing NixOS profile or display/seat. Physical tablet's `GET /health` returned 200 JSON `{"ok":true,"clientCount":0}`, `GET /viewer` returned **HTTP 200**, unauthorized `POST /api/scene` returned **HTTP 401** as designed. The transient preview service was then **stopped**, freeing TCP port 17858 for gen59 activation.
4. Tablet remains exact gen58 at `/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4`, Slint/SSH/seatd/NetworkManager active, touchscreen at current `/dev/input/event4`. Profile gen58, GRUB 57/56 recoveries unaffected.
5. `activate-gen59.sh` read-only `check` mode tested against current golden system on the tablet and **PREFLIGHT_OK**. This exercises 32-bit UEFI / 64-bit OS, DRM nodes, touch symlink, seatd, SSH and profile-58-link safety, without activating or creating a new generation.

## Required next steps

1. Monitor `/tmp/wpe59-build-retry.rc`. If nonzero, inspect `/tmp/wpe59-build-retry.log` for the **new** failure; fix only the real problem, resync flake then retry. If success, build the kiosk `#packages.x86_64-linux.kiosk` and test it in headless mode in the Linux builder using `WPE_PLATFORM=headless`, confirming a WebKit process and page-load success for local scene. Check dynamic library closure.
2. Build the entire `#nixosConfigurations.gen59-wpe.config.system.build.toplevel` in the Mac Linux builder, `--max-jobs 2 --cores 2 --option sandbox false --option filter-syscalls false`. It has **already successfully evaluated**, with exact same gen58 kernel `/nix/store/mifh5p043cma8pbywl2lvlkp1z1bd8i2-linux-6.12.36` and initrd `/nix/store/8hla2afa7n9vgs76l3558wy7gywxv8gv-initrd-linux-6.12.36`. Check IA32 GRUB module before building, as Colima/Rosetta cannot execute 32-bit personality. If matching GRUB paths are absent, import exact existing gen58/57 GRUB outputs rather than changing the Lenovo boot mode.
3. Compare gen59 closure requisites against tablet gen58, export **only missing immutable Nix store paths** over SSH, verify exact system `nix-store --verify-path` and display service executable.
4. Copy `restore-gen58.sh` to root-protected `/run/lenovo-gen59-restore.sh` on tablet. The optional `activate-gen59.sh` script requires root, verifies physical device/service state and arms independent 8-minute systemd rollback before registering gen59 in the profile and switching live. Monitor SSH and WPE logs; manual physical touch, visible pixels and screen orientation still need confirmation before disabling recovery timer. **Do not reboot blindly into an untested display.**
5. When Gen59 physically works, note exact system/store paths, gen59 profile generation, PSS/i915 memory, touchscreen taps, URL animation and authentication; then push a separate golden branch. Until then the candidate is **not installed**.

Reference files: `README.md`, `flake.nix`, `kiosk.c`, `restore-gen58.sh`, `activate-gen59.sh`, `verify-gen59.sh`. The existing hourly automated readiness watch is configured to check the current retry and build the full image after WPE succeeds; it **must not** activate or reboot the physical tablet unattended.

## Update: native build and actual tablet service smoke test (~14:30 UTC)

- Inspected a later packaging pitfall: the third-party WPE recipe has outputs `out, dev, devdoc` and a `postFixup` for moving documentation, but our minimized WPE build explicitly disables documentation. The derived package was corrected to **`outputs = [ "out" "dev" ]; postFixup = "";`** before wasting a full C++ compile on a missing output. The corrected WPE derivation path is `/nix/store/r4khvx48p35fl9jsfl1xlr110zvg8nm8-wpewebkit-2.54.1.drv`.
- Started independent native x86_64 GitHub Actions workflow on the experimental branch, run **39616428062**, URL `https://github.com/drunkod/vlenovo-nixos-tablet/actions/runs/39616428062`. The runner completed Nix installation and **began the WPE 2.54.1 build**. Workflow exports and checksums its `out` and `dev` Nix binary outputs, instead of uploading an entire disk. It has **not yet finished** as of this update.
- The old Mac Rosetta derivation `8bdld3a4...` was stopped after ~2,802/8,883 Ninja tasks because it had the superseded 3-output recipe. The older `/tmp/wpe59-build-retry.rc = 1` is **an intentional interruption**, not evidence the corrected GitHub build failed. No other NixOS profile or tablet process was touched.
- Added `continue-gen59-from-actions.sh`: `fetch` downloads and verifies the native artifact and imports the WPE outputs into the Mac Linux Nix builder; `build` builds WPE kiosk + complete NixOS system and asserts kernel/initrd exactly unchanged; `stage` transfers only missing immutable Nix-store paths to Lenovo via SSH, verifies system path, and asserts the tablet **remains on Gen58**. The `all` mode does all three **without activating or rebooting**. Shell syntax checked.
- The physical tablet now has the static Nebula web Nix package **and Node.js 22.16.0** imported in its Nix store, not in the active system profile. Temporarily ran an isolated `gen59-nebula-preview` scene service via systemd-run on loopback TCP 17858: `GET /health` returned OK, `GET /viewer` gave HTTP **200**, unauthenticated `POST /api/scene` gave HTTP **401**. **Stopped** this transient service afterwards. Slint Gen58 stayed active the entire time, so no KMS display was modified.
- Nix WPEPlatform 2.54 direct DRM source-level check found udev card selection, DRM-master acquisition, atomic modesetting, libinput seat handling and optional systemd-logind TakeDevice. Verified systemd-logind, seat0 and alex's tty1 session are active on the Lenovo. **Not yet proof of WPE display/touch working on the real panel.**
- Verified the recovery script, `activate-gen59.sh` and `verify-gen59.sh` syntax; the read-only activation preflight on Gen58 passed. `activate-gen59.sh` now refuses to register Gen58 itself as a bogus Gen59. **No physical Gen59 has been activated or rebooted.**
