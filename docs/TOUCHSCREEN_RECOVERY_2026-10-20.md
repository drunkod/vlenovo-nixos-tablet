# Lenovo ELAN1001 touchscreen: historical calibration and failed boot probe (2026-10-20)

## Outcome

On 2026-10-20 the Slint MVP was successfully displayed as a separate Wayland client on running Flick, but no touch events were logged. **The present obstacle is below the graphical compositor: Linux did not register the ELAN1001 touchscreen at boot.** Do not change Slint coordinate transforms or recalibrate until ELAN1001 is registered again.

This report is based on read-only live SSH checks and preserved source/Git-history notes. No driver binds/rebinds, GPIO writes, ACPI method calls, module reloads, restarts or boots were made during this investigation.

## Live tablet state, 2026-10-20

- Tablet: Lenovo Miix 2 10, NixOS 25.05 / Linux 6.12.36 x86_64.
- Flick (native DRM backend), SSH and NetworkManager active; separate Slint MVP viewer running.
- `/proc/bus/input/devices`: eight event devices, `event0` through `event7`, none named ELAN1001. The previous touchscreen's `/dev/input/event2` now belongs to GPIO keys: device numbering is not stable. No `/dev/input/by-path/first-touchscreen`.
- Touch input object `/sys/bus/i2c/devices/i2c-ELAN1001:00` exists, ACPI path `\\_SB_.I2C6.TCS0`, modalias `acpi:ELAN1001:PNP0C50:`.
- ACPI `ELAN1001:00/power_state = D3hot`; `/sys/devices/platform/80860F41:05/power/runtime_status = suspended`. The I²C-HID child has no bound driver or HID/input child. Its own runtime_status `unsupported` is *not* a useful power diagnosis in isolation.
- `i2c_hid_acpi` kernel module is loaded, but the ELAN device is absent from its bound-device list.
- **Boot kernel log, 2026-10-20 15:27:44–15:27:50 UTC:**

```text
i2c_hid_acpi i2c-ELAN1001:00: failed to change power setting.
i2c_hid_acpi i2c-ELAN1001:00: failed to reset device: -110
i2c_hid_acpi i2c-ELAN1001:00: failed to change power setting.
i2c_hid_acpi i2c-ELAN1001:00: failed to change power setting.
i2c_hid_acpi i2c-ELAN1001:00: failed to change power setting.
i2c_hid_acpi i2c-ELAN1001:00: can't add hid device: -110
i2c_hid_acpi i2c-ELAN1001:00: probe with driver i2c_hid_acpi failed with error -110
```

`-110` is a timeout (`ETIMEDOUT`). Since the device failed before evdev was created, touchscreen calibration, Slint, and Flick cannot repair it as currently booted.

## Previously saved touchscreen setups

### 1. SXMO/Sway gestures

- `pkgs/sxmo-wrapper/vlenovo-deviceprofile.sh`: `SXMO_MONITOR=DSI-1`, `SXMO_SWAY_SCALE=2`, `SXMO_LISGD_EXTRA_ARGS="-w 1920 -h 1200"`, `LISGD_EDGE_SIZE=4.0`.
- `tools/macbook/legacy/vlenovo-lisgd-calibrate.sh`: old `lisgd-0.4.0` manual gesture logger with `-w 1920 -h 1200 -s 4.0 -t 0 -T 0 -r 45 -m 3000`. It logged swipe directions to `/tmp/vlenovo-calib.log`. This script measures **gesture recognition/geometry**, not a persisted touchscreen affine calibration matrix.
- Commits `f49acda` (2026-10-02; wait for delayed touchscreen detection) and `2e99591` (2026-10-02; reject stale touchscreen path before lisgd) fixed *user-session gesture startup*. They cannot rescue an ELAN device that has not initialized in the kernel.

### 2. Flick native input and QML lock-screen tests

- `.local/worktrees/vlenovo-flick-integration/docs/testing/flick-ui-validation.md` documents an earlier detected touchscreen `ELAN1001:00 04F3:032F`, then `/dev/input/event2`, with raw multitouch ranges **X 0–2880; Y 0–1856; ten slots**.
- Corrected 2026-10-06 evidence: seven `>>>TOUCH>>> DOWN` events with valid transformed coordinates were logged in Flick **before** rebind experiments.
- The QML lockscreen slide, PIN entry and unlock were subsequently recorded as PASS. Thus HID -> evdev -> libinput/Smithay -> Flick/QML touch could work on the current software stack.
- Historical Flick code already performs input/display coordinate transformation. Earlier empty `evtest` windows did *not* coincide with confirmed touches and were explicitly corrected; don't revert that conclusion.
- Relevant commit/documentation lineage: `e887b5a`, `5ceb45e`, `1908cc0` and the preserved Flick validation file.

## Relevant prior failure and ACPI power hypothesis

`.local/tablet-history/vlenovo-touch-research/elan-reprobe-61236/summary.txt` records a **2026-10-02** incident with `ELAN1001` unbound, `D3hot`, and GPIO60 reported low. That bounded reprobe returned `-121` (no device at I²C address); it did **not** restore the touchscreen. The current boot is similar but reports `-110` during reset/power.

The firmware's `\\_SB.I2C6.TCS0._PS0` performs a GPIO60 reset/enable sequence. The I²C6 `TCPR` PowerResource also touches Crystal Cove PMIC GPIO11, but the notes state `TCS0` does not declare `TCPR` in `_PR0`. The `gpio_crystalcove` module was historically not autoloaded despite being available; this is a research clue, **not proof** of the present failure.

Do **not** directly write GPIO60, manually call guessed ACPI methods, force runtime PM on the shared I²C bus, or replay prior driver rebind steps without agreeing on a bounded, recoverable test. Reboot/cold power cycle can interrupt SSH and the current MVP; obtain user confirmation and a physical recovery route first.

## Read-only verification commands

```bash
ssh -F ~/.ssh/vlenovo_config vlenovo
cat /proc/bus/input/devices
ls -l /dev/input/by-path/
cat /sys/bus/acpi/devices/ELAN1001:00/power_state
readlink /sys/bus/i2c/devices/i2c-ELAN1001:00/driver || echo unbound
cat /sys/devices/platform/80860F41:05/power/runtime_status
sudo dmesg --ctime | grep -Ei 'ELAN1001|i2c_hid|hid-multitouch'
systemctl is-active flick sshd NetworkManager
```

The next controlled gate is to establish a recovery plan and capture boot/probe/power observations around a user-approved targeted ELAN-only action or a deliberate reboot. Once `ELAN1001` binds and an input event node returns, test confirmed physical touches with `evtest` and inspect Flick input logs, then retry Slint's action-counter/event log. No calibration changes are justified until lower-level input is functioning.

## Controlled recovery session, 2026-10-20 16:46–16:51 UTC

**Result: ELAN kernel driver successfully restored by a normal reboot.** The user explicitly authorized a controlled recovery attempt while physically able to access the tablet.

### Before reboot

- Saved diagnostic snapshots to tablet `/home/alex/lenovo-mvp/touch-recovery-20261020/` including input devices, kernel messages, services, generation paths and boot ID.
- Initial boot ID: `d02a21a9-3c0b-4201-a64a-6c941afcd3ec`.
- Tried an **ELAN-only** `i2c_hid_acpi` sysfs driver bind while ELAN was unbound: failed, `ENXIO` (`No such device or address`).
- Verified only ELAN1001 resides on I²C controller `80860F41:05` (adapter `i2c-4`); its PM state was `suspended` and its original `power/control` setting `auto`.
- Found new kernel errors `i2c_designware 80860F41:05: timeout waiting for bus ready` and `timeout in disabling adapter`.
- Loaded `gpio_crystalcove` via `modprobe`, following prior documented module discovery. It registered successfully; Flick, SSH, NetworkManager and seatd remained active. The ELAN driver still failed to bind when retried.
- Attempted to perform a temporary controller PM test with guaranteed restoration of `auto`, but **remote command execution controls blocked it**. No controller PM values or GPIO levels were modified.
- Did **not** touch GPIO60, force ACPI power methods, rebind the I²C controller or reset the SMO91D0 sensor hub.
- Retained generation `/nix/store/91jbl1irxi6qjx0252s00mlz8ass3yin-nixos-system-vlenovo-25.05.20250708.88983d4`.

### Controlled reboot and after

Issued one normal `systemctl reboot --no-block` after saving snapshot. SSH automatically reconnected through `~/.ssh/vlenovo_config` to `10.106.128.139` after roughly 28 seconds.

- New boot ID: `dabf2a44-c4c4-48ca-9ba8-bfcbd3e05374`.
- `ELAN1001:00 04F3:032F` bound via `i2c_hid_acpi` and `hid-multitouch`; ACPI power **D0**.
- Actual touchscreen: **`/dev/input/event4`** (not the historical event2); `/dev/input/by-path/first-touchscreen` points correctly to event4; udev reports `ID_INPUT_TOUCHSCREEN=1`.
- Flick main PID 894 has **`/dev/input/event4` open**. This establishes that its input device path is connected, not just present in sysfs.
- Touch IRQ: Linux IRQ 130; initial IRQ count 3 shortly after boot. This is *not* proof of physical finger touches.
- Slint prototype `mvp/slint/TabletMvp.slint` relaunched via `run-on-tablet.sh start`, PID **1112**, RSS around 79 MiB, without system activation. Its event log still contained 0 confirmed taps at final check.
- Flick, SSH, NetworkManager and seatd **all active**; 0 failed systemd units; Wayland socket `/run/user/1001/wayland-1` present; Wi-Fi IP unchanged.
- Current and booted generations **identical** to before the reboot. No NixOS config changes and no permanent startup changes made.

### Outstanding acceptance and recurrence prevention

1. The user must physically verify that touch now moves the Flick lock screen/Slint card and enter PIN as needed. Check `ssh -F ~/.ssh/vlenovo_config vlenovo 'tail -20 ~/lenovo-mvp/touch-events.tsv'` after touching Slint cards; log is created on first callback.
2. Current recovery is **runtime restoration**, not a proven root-cause fix. Another boot can fail. Do not autoload GPIO or patch I²C controller solely on this evidence, because the reboot worked without the module and the module-only attempt did not fix the failure.
3. Investigate intermittent firmware power and Bay Trail DesignWare I²C timing with boot-to-boot diagnostics. The kernel's `i2c_dw_wait_bus_not_busy` has bus recovery, but this boot had persistent `timeout waiting for bus ready` after the failed ELAN probe. See Linux `drivers/i2c/busses/i2c-designware-common.c` and upstream discussion `[PATCH v10] i2c: designware: fix controller is holding SCL low while ENABLE bit is disabled` (September 2024); **no conclusion yet** about whether this exact patch is absent from the running 6.12.36 kernel.
4. Avoid masking the hardware problem through UI/Slint calibration; keep the 1920×1200 geometry/earlier transforms until physical touch testing proves a coordinate discrepancy.
