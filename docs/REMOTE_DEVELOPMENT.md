# Remote development from a laptop

This workflow keeps editing on your laptop and performs the NixOS build on the Lenovo tablet over Wi-Fi. It is the safest path from an Apple Silicon Mac because the target is `x86_64-linux`.

## 1. Prerequisites on the laptop

You need `git`, `ssh`, and `rsync`. macOS already includes SSH and rsync; Git can come from Xcode Command Line Tools, Homebrew, or Nix.

Clone the repository:

```bash
git clone https://github.com/drunkod/vlenovo-nixos-tablet.git
cd vlenovo-nixos-tablet
```

Set the tablet address for the current Wi-Fi network:

```bash
export VLENOVO_HOST=10.230.221.139
```

The address can change after DHCP renewal. On the tablet, use `ip -4 addr show wlan0` or `nmcli device show wlan0` to find it.

## 2. Passwordless SSH

The NixOS configuration is key-only: password SSH is disabled and root SSH login is disabled.

The current laptop public key is declared in `nixos/common-configuration.nix`. Test it with:

```bash
./bin/vlenovo ssh
```

If moving to a different laptop, replace the public key in `users.users.alex.openssh.authorizedKeys.keys`, then bootstrap that key once from the tablet console or an already-authorized machine.

A convenient one-time bootstrap from the tablet is:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
curl -fsSL https://github.com/drunkod.keys > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Do not copy a private SSH key to the tablet. Only public keys belong in the Nix configuration.

## 3. Development loop

Edit files locally in this repository. Then use the helper:

```bash
./bin/vlenovo build
```

This rsyncs the repository to `/home/alex/vlenovo-dev` and runs a build without activating it.

For a temporary live activation:

```bash
./bin/vlenovo test
```

This is the preferred debugging mode. It changes the running system but not the boot default.

After testing SSH, Wi-Fi, Sxmo, input devices, and any changed services:

```bash
./bin/vlenovo switch
```

`switch` activates the system and makes it the normal boot configuration.

## 4. Rollback and recovery

If a `test` activation is bad but SSH still works:

```bash
./bin/vlenovo rollback
```

That activates `/run/booted-system` again for the current session. A reboot also returns from a test-only activation to the previous boot default.

Before a risky networking or SSH change, keep a physical keyboard available and prefer `test` before `switch`.

Useful checks after every test activation:

```bash
./bin/vlenovo status
./bin/vlenovo logs sxmo
./bin/vlenovo logs sshd
./bin/vlenovo logs NetworkManager
./bin/vlenovo logs bluetooth
```

The status command also shows failed systemd units, current/booted NixOS generations, Wi-Fi, SSH, Bluetooth, and Sxmo state.

## 5. Direct debugging commands

Open a shell on the tablet:

```bash
./bin/vlenovo ssh
```

Then useful commands include:

```bash
systemctl --failed
journalctl -b -p warning
journalctl -u sxmo -b
journalctl -u sshd -b
journalctl -u NetworkManager -b
journalctl -u bluetooth -b
nmcli device status
rfkill list
bluetoothctl show
swaymsg -t get_inputs
```

For a failed build, run the same rebuild directly on the tablet so all Nix diagnostics are visible:

```bash
cd ~/vlenovo-dev
sudo nixos-rebuild build --flake .#vlenovo --show-trace
```
