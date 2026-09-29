# Bluetooth keyboard

Bluetooth is enabled declaratively in `nixos/common-configuration.nix`:

```nix
hardware.bluetooth = {
  enable = true;
  powerOnBoot = true;
};
```

The tested keyboard was discovered as `Bluetooth Keyboard` and paired successfully as a Bluetooth HID device.

## Pair manually with bluetoothctl

Put the keyboard into pairing mode, then run:

```bash
bluetoothctl
```

Inside `bluetoothctl`:

```text
power on
pairable on
agent KeyboardOnly
default-agent
scan on
```

Wait for a line such as:

```text
Device 90:7F:61:8E:C9:8C Bluetooth Keyboard
```

Then pair it:

```text
pair 90:7F:61:8E:C9:8C
```

When BlueZ prints a PIN, type that PIN on the Bluetooth keyboard itself and press Enter on the Bluetooth keyboard.

After `Pairing successful`:

```text
trust 90:7F:61:8E:C9:8C
connect 90:7F:61:8E:C9:8C
scan off
info 90:7F:61:8E:C9:8C
```

The final state should show:

```text
Paired: yes
Bonded: yes
Trusted: yes
Connected: yes
```

Useful recovery commands:

```bash
bluetoothctl devices Paired
bluetoothctl connect 90:7F:61:8E:C9:8C
bluetoothctl disconnect 90:7F:61:8E:C9:8C
bluetoothctl remove 90:7F:61:8E:C9:8C
rfkill list bluetooth
systemctl status bluetooth
journalctl -u bluetooth -b
```

Pairing data is state stored by BlueZ on the tablet; it is not stored in this Git repository. The Nix configuration only ensures that Bluetooth support is available after boot.
