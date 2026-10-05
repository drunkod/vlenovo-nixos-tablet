# Flick UI Validation

Base generation: 54
Current validated generation: 56
Base checkpoint: 998ec38 (flick-stage2-working)
Branch: flick-ui-validation

## Touch

Device: ELAN1001:00 04F3:032F
Event node: /dev/input/event2
Driver chain: i2c_hid_acpi -> hid-multitouch -> evdev
Raw range: X 0..2880, Y 0..1856, 10 MT slots

### Reproducible observations

1. Flick opens /dev/input/event2.
2. evtest reports the expected touchscreen capabilities.
3. During physical touch, ELAN IRQ 129 increased from 167 to 479.
4. During the same physical interaction:
   - evtest emitted zero Event: records.
   - Flick emitted zero >>>TOUCH>>> DOWN records.
   - HID debugfs events emitted zero reports.
5. HID report descriptor is present and parses as a multitouch touchscreen.
6. No new i2c-hid/hid-multitouch kernel errors were logged during the test.
7. I2C controller 80860F41:05 reports runtime_status=suspended during the touch IRQ activity.

### Corrected current isolation

Later timestamp correlation showed that Flick had already logged seven native `>>>TOUCH>>> DOWN` events at 19:25-19:26 UTC, before the later ELAN rebind experiments. Those records include valid transformed screen coordinates.

Therefore the proven path is:

- physical controller / IRQ: PASS
- i2c_hid_acpi report delivery: PASS
- HID core / hid-multitouch: PASS
- libinput / Smithay: PASS
- Flick native TouchDown handler: PASS
- Flick lock-screen gesture/UI response: PENDING

The earlier empty evtest, HID-debugfs, and hidraw capture windows did not coincide with a separately confirmed physical touch and must not be treated as proof of a lower-level input failure.

Do not change calibration, libinput transforms, Smithay, or Flick touch code based on those empty capture windows.

### ACPI reset/power discovery

DMI identifies the tablet as Lenovo Miix 2 10 (20359).

The live DSDT defines the touchscreen as `\\_SB.I2C6.TCS0` with:
- HID: ELAN1001
- I2C address: 0x10
- interrupt resource: 0x45 (Linux ELAN IRQ 129)
- output GPIO: `\\_SB.GPO0` pin 0x3C (60)

`TCS0._PS0` performs an explicit reset/enable sequence:
1. drive `GPO0.TCD3` low
2. wait 5 ms + 30 ms
3. drive `GPO0.TCD3` high
4. wait 300 ms

The GPO0 ACPI field maps `TCD3` exactly to GPIO pin 60.

Linux GPIO debugfs currently reports that pin as:
`gpio-60 (ACPI:OpRegion) out lo`

This is suspicious because the firmware power-on/reset sequence leaves TCD3 high. The ACPI device reports D0, and the ELAN I2C device itself has runtime PM unsupported/disabled. The parent Bay Trail I2C controller can autosuspend, but forced-awake test windows without simultaneous physical IRQ activity were inconclusive.

A driver unbind/rebind successfully re-enumerated the ELAN device but did not prove a reset fix because those observation windows also had no simultaneous touch IRQ activity.

Do not directly take over GPIO60: it is owned by ACPI:OpRegion. Prefer a firmware-method or driver-level reset diagnostic before considering a kernel quirk.

## Brightness

Backlight: /sys/class/backlight/intel_backlight

Generation 55 activates brightnessctl's packaged udev rule via:
services.udev.packages = [ pkgs.brightnessctl ];

Validated result:
- brightness node: root:video 0664
- alex write access: PASS
- brightness value remained unchanged during permission validation
- Flick remained active with NRestarts=0
- SSH/NetworkManager remained active
- zero failed systemd units

Flick writes sysfs directly and falls back to brightnessctl, so the service now has the required write path.

Physical Flick slider movement is still pending as a separate UI acceptance test.

## Lock screen and unlock

Generation 56 packages the Qt/QML lock-screen runtime into the Flick package and sets:
- `FLICK_ROOT` to the immutable package tree
- `FLICK_STATE_DIR=/home/alex/.local/state/flick`
- `FLICK_USER=alex`

Boot acceptance:
- QML lock-screen child starts automatically: PASS
- Qt Wayland connection and xdg-toplevel mapping: PASS
- Flick remains NRestarts=0: PASS
- slide-to-unlock touch interaction: PASS
- PIN entry UI transition: PASS
- built-in test PIN acceptance: PASS
- QML exits with code 0: PASS
- launcher creates `unlock_signal`: PASS
- Flick consumes the signal and transitions to `view=Home`: PASS
- post-unlock state: `lock_active=false`, `space_count=0`
- SSH, NetworkManager, seatd remain active
- zero failed systemd units

The PIN screen currently uses Flick's upstream hard-coded test credential when no `lock_config.json` exists; this is not yet production authentication.

Qt emitted several `TouchPointPressed without previous release event` warnings during lock-screen interaction. Touch nevertheless completed the slide and PIN flows. Keep this as a follow-up input-sequence quality issue rather than a blocker.

## Home status bar

After unlock, the Home status bar displays a clock at left and `85%` at right.

The `85%` is not the tablet battery value:
- kernel BATC capacity: 100
- kernel BATC status: Full
- Slint `StatusBar` default battery property: 85

Exact generation-56 source verification:
- NixOS current, booted, and system profile all point to `91jbl1irxi6qjx0252s00mlz8ass3yin`.
- Flick ExecStart is `mff55q54jy9x5jifkzy5fhriqshd90ng-flick-unstable-2026-01-04/bin/flick`.
- The Nix package pins upstream Flick commit `729cdecedad05be3192b21f7d4310eb0ff7ae563`.
- The exact pinned source contains `in property <int> battery: 85;` in `StatusBar` and `HomeScreen`, plus `battery-percent: 85` defaults in the root shell and Quick Settings.
- The tablet exposes only one Battery-class power supply: `/sys/class/power_supply/BATC`, reporting `capacity=100` and `status=Full`.
- `BatteryStatus::read()` checks only `battery`, `Battery`, `BAT0`, and `BAT1`; therefore it returns `None` on this tablet.
- The native udev backend has no periodic `system_last_refresh` loop. Its battery setter calls are limited to Quick Settings render paths.
- The udev Home render path has no `set_time()` or `set_battery_percent()` parity with hwcomposer.
- The hwcomposer backend does have the 10-second refresh loop and explicitly pushes both current time and battery into Slint Home.

Therefore the visible `85%` is the Slint default surviving into Home because live battery discovery fails on `BATC` and the native udev Home path does not overwrite the default. This is not a kernel battery-driver failure and no alternate 85%-reporting power-supply object exists.

The Home clock has the analogous native-udev setter gap and must not yet be treated as live telemetry.

Do not change QML packaging, Qt dependencies, `FLICK_ROOT`, DRM selection, the systemd service, or lock-screen code for this issue. Keep generation 56 as the recovery checkpoint and fix status telemetry separately.

## OSK

Flick text-input-v3 and internal Slint keyboard initialize.
The native udev backend has keyboard action handling.
check_keyboard_request() is currently a stub returning None.

Touch delivery into Flick is now proven. OSK acceptance should proceed with the lock-screen bottom-edge gesture first, then a text-input-v3 client if needed.


## ELAN power/reset isolation

Additional runtime testing collected useful ELAN power/reset data, but the later timestamp correlation means it does not establish a failure below evdev/libinput:

- ELAN-only i2c_hid_acpi rebind succeeds.
- Probe-time control transactions succeed: HID descriptor read, hardware reset completion, report descriptor read, feature report reads, and IRQ 129 registration.
- Each rebind creates a fresh hid-multitouch instance and hidraw2.
- Probe produces a few IRQs, but a post-rebind IRQ-only observation stayed flat at 491 for 30 seconds during the requested touch window.
- hidraw capture produced no asynchronous reports.

### ACPI firmware resources

The tablet firmware defines the touchscreen as \\_SB.I2C6.TCS0.

Decoded _CRS:
- I2C bus: \\_SB.I2C6
- 7-bit address: 0x10
- IRQ: ACPI interrupt 69, level-triggered, active-high, exclusive
- GPIO: \\_SB.GPO0 pin 60 (0x3c), output-only

TCS0 _PS0 toggles GPO0.TCD3 low, waits, then high and waits 300 ms.
GPO0.TCD3 maps exactly to pin 60.

I2C6 also defines PowerResource TCPR:
- _ON: TCD3 low -> PMIC TCON high -> TCD3 high
- _OFF: PMIC TCON low
- TCON maps to Crystal Cove PMIC GPIO 11

However, TCS0 does not declare TCPR in _PR0.

### Missing Crystal Cove GPIO autoload

Kernel config: CONFIG_GPIO_CRYSTAL_COVE=m.
The module exists as gpio-crystalcove.ko.xz, but:
- it was not loaded on generation 54
- the platform child MODALIAS is platform:crystal_cove_gpio
- modules.alias contains no matching alias
- therefore udev did not autoload the module

A reversible manual load of gpio_crystalcove succeeded:
- crystal_cove_gpio bound
- PMIC gpiochip registered
- SSH, NetworkManager and Flick remained active

Live state after module load and another ELAN rebind:
- GPO0 pin 60 / TCD3: output low
- Crystal Cove GPIO11 / TCON: output low
- ACPI PowerResource LNXPOWER:04 = \\_SB.I2C6.TCPR
- LNXPOWER:04 status: 0 (off)

This remains a useful suspend/resume and dead-touch investigation lead, but it is not the current root-cause conclusion: Flick received seven valid native TouchDown events before the rebind experiments, proving the sensing/report path can operate through the full Linux input stack.

Do not add raw GPIO writes or an ACPI _PR0 override while ordinary touch delivery into Flick is proven. Revisit the firmware PowerResource path only if a reproducible dead-touch state is captured with simultaneous IRQ/input evidence.
