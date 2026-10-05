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

## Brightness

Backlight: /sys/class/backlight/intel_backlight
Current permissions: root:root 0644
Flick runs as alex, who is in video but cannot write the brightness node.

Flick writes sysfs directly and falls back to brightnessctl.
brightnessctl ships 90-brightnessctl.rules to chgrp video + chmod g+w, but that rule is not active in the current NixOS udev rules.

Likely fix (separate commit):
services.udev.packages = [ pkgs.brightnessctl ];

## OSK

Flick text-input-v3 and internal Slint keyboard initialize.
The native udev backend has keyboard action handling.
check_keyboard_request() is currently a stub returning None.

OSK acceptance remains blocked on either working touch or a text-input-v3 client.

