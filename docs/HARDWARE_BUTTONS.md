# Tablet hardware buttons

The button below the display with the Windows logo is exposed by the Linux input stack as:

```text
device: gpio-keys
event:  KEY_LEFTMETA
code:   125
```

On this tablet Sway identifies the built-in GPIO keyboard device as `1:1:gpio-keys`.

Sxmo selects its generic `desktop` device profile on this x86 tablet. That profile sets `SXMO_NO_VIRTUAL_KEYBOARD=1` and `SXMO_DISABLE_KEYBINDS=1`, so the normal Sxmo virtual-keyboard action is disabled.

The local Sxmo wrapper solves this in two parts:

1. `vlenovo-osk-toggle` directly starts/stops `wvkbd-mobintl`.
2. `sxmo_swayinitconf.sh` installs a device-specific Sway binding before the desktop profile exits its normal hardware-key setup.

```text
Super_L on 1:1:gpio-keys -> vlenovo-osk-toggle
```

This scopes the action to the tablet GPIO device. Super/Windows keys on USB or Bluetooth keyboards keep their normal Sway `Mod4` behavior.

For live debugging:

```bash
sudo nix shell nixpkgs#evtest -c evtest /dev/input/event4
cat /run/user/1001/vlenovo-osk.log
pgrep -a wvkbd-mobintl
```

Expected raw event for one press:

```text
EV_KEY code 125 (KEY_LEFTMETA), value 1
EV_KEY code 125 (KEY_LEFTMETA), value 0
```
