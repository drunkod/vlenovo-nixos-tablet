# Flick UI Validation

Generation: 54
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

### Current isolation

Physical controller / IRQ: PASS
i2c_hid_acpi input report delivery: FAIL / no reports observed
HID core: no reports observed
hid-multitouch / evdev: not reached
libinput / Smithay / Flick: not reached

Do not change calibration, libinput transforms, Smithay, or Flick touch code yet.

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

## OSK

Flick text-input-v3 and internal Slint keyboard initialize.
The native udev backend has keyboard action handling.
check_keyboard_request() is currently a stub returning None.

OSK acceptance remains blocked on either working touch or a text-input-v3 client.

