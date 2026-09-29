
# NixOS Remote Deployment and Debugging Manual

This guide provides step-by-step instructions for setting up and using remote NixOS deployments from your main PC to a target device (e.g., a tablet named `lenovo`).

## Table of Contents

1.  [Introduction](#1-introduction)
2.  [Prerequisites](#2-prerequisites)
3.  [Step 1: Preparing the Target Device (Your Tablet)](#3-step-1-preparing-the-target-device-your-tablet)
4.  [Step 2: Preparing the Host PC (Your Workstation)](#4-step-2-preparing-the-host-pc-your-workstation)
5.  [Step 3: Performing the Remote Deployment](#5-step-3-performing-the-remote-deployment)
6.  [Troubleshooting and Common Issues](#6-troubleshooting-and-common-issues)

## 1. Introduction

This setup allows you to manage your tablet's entire configuration from your main PC. You will edit your NixOS configuration files on your PC, and then use a single command to build the new system and push it to the tablet over the network. This is incredibly powerful for devices that are inconvenient to work on directly.

We will use Nix's built-in SSH capabilities and `nixos-rebuild`.

## 2. Prerequisites

*   **Host PC**: A machine with your Nix configuration flakes.
*   **Target Tablet**: A device running NixOS. It can be a minimal installation; we will deploy the full configuration to it.
*   **Network**: Both devices must be on the same network and able to reach each other. Make note of your tablet's IP address.
*   **SSH Keys**: You should have an SSH key pair on your host PC. If you don't, create one with `ssh-keygen -t ed25519`.

## 3. Step 1: Preparing the Target Device (Your Tablet)

The tablet needs to be prepared to accept remote connections and allow your user to perform administrative tasks without a password.

### 3.1. Initial Installation (If not already done)

If NixOS is not yet on the tablet, perform a minimal installation. The key parts are:
*   Setting a root password.
*   Creating your user (e.g., `alex`).
*   Enabling the SSH service.

### 3.2. Configuration for Remote Access

On the tablet itself, you need to edit its local `/etc/nixos/configuration.nix` to include the following settings. You only need to do this **once**. After the first successful remote deployment, these settings will be managed by your flake.

```nix
# /etc/nixos/configuration.nix on the tablet
{ config, pkgs, ... }:

{
  imports = [
    # Include the hardware scan from the initial installation
    ./hardware-configuration.nix
  ];

  # ... other initial settings like bootloader, filesystems, etc.

  # 1. Enable the SSH Server
  services.openssh.enable = true;

  # 2. Add your SSH public key for passwordless login
  #    Replace the key with the content of `~/.ssh/id_ed25519.pub` from your PC.
  users.users.alex = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Make sure your user is in the 'wheel' group
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDV45EkSp+b5fraVf5vDDUbuu2O7kVGxDn+8O6y/xcxh alex@gmail.com"
    ];
  };

  # 3. Allow passwordless sudo for the 'wheel' group
  #    This is required for `nixos-rebuild --use-remote-sudo` to work.
  security.sudo.wheelNeedsPassword = false;

  # 4. Ensure a known state version
  system.stateVersion = "25.05"; # Or whatever version you are installing
}
```

After adding these settings, run `sudo nixos-rebuild switch` on the tablet one last time.

### 3.3. Get the Tablet's IP Address

Find your tablet's IP address. You will need it for the next steps.
```bash
# On the tablet
ip addr
```
Look for an address like `192.168.1.123` under your `wlan0` or `eth0` interface. Let's assume it's `192.168.1.123`.

## 4. Step 2: Preparing the Host PC (Your Workstation)

Your PC needs to know how to connect to the tablet. We do this by adding an entry to your SSH configuration file.

### 4.1. Configure SSH Alias

Edit the file `~/.ssh/config` on your **PC** and add the following entry. If the file doesn't exist, create it.

```
# ~/.ssh/config on your PC

Host lenovo
  HostName 192.168.1.123  # <-- Replace with your tablet's actual IP address
  User alex              # <-- Replace with your username on the tablet
  Port 22
```

*   `Host lenovo`: This is a shortcut name. When you `ssh lenovo`, SSH will use these settings. It's the same name you will use with `--target-host`.
*   `HostName`: The IP address of the tablet.
*   `User`: The user you will log in as.

### 4.2. Test the SSH Connection

From your PC, test that you can connect to the tablet without a password:
```bash
ssh lenovo
```
If this works, you should be logged into your tablet's shell without typing a password. Type `exit` to return to your PC.

## 5. Step 3: Performing the Remote Deployment

Now you are ready to deploy your flake's configuration to the tablet.

### 5.1. The Deployment Command

From your flake's directory on your **PC**, run the following command:

```bash
nixos-rebuild switch --flake .#vlenovo --target-host lenovo --use-remote-sudo
```

### 5.2. How it Works

Let's break down this command:
*   `nixos-rebuild switch`: The standard command to build and activate a new configuration.
*   `--flake .#vlenovo`: Specifies which flake output to build. It uses the flake in the current directory (`.`) and the `nixosConfigurations.vlenovo` output.
*   `--target-host lenovo`: This is the magic part. It tells `nixos-rebuild` **not** to build for the local machine. Instead, it will connect to the `lenovo` host (defined in your `~/.ssh/config`) to perform the build and activation.
*   `--use-remote-sudo`: This tells `nixos-rebuild` that after connecting via SSH as your user (`alex`), it should use `sudo` to perform the administrative tasks (like copying files to the Nix store and activating the new system). This is why `security.sudo.wheelNeedsPassword = false` was necessary.

Nix will now:
1.  Evaluate your flake configuration on your PC.
2.  Connect to the tablet (`lenovo`) via SSH.
3.  Copy all necessary packages and configurations from your PC's Nix store (or build them on the tablet if needed) to the tablet's Nix store.
4.  On the tablet, run the activation script to switch to the new system.

Your tablet is now running the configuration defined entirely in your flake!

## 6. Troubleshooting and Common Issues

*   **Permission Denied / Password Prompt**:
    *   Verify your SSH public key is correctly listed in the tablet's configuration.
    *   Check file permissions on the tablet: `~/.ssh` should be `700` and `~/.ssh/authorized_keys` should be `600`.
    *   Ensure the `Host` alias in `~/.ssh/config` on your PC is correct.

*   **`sudo: a password is required`**:
    *   The `security.sudo.wheelNeedsPassword = false;` setting is missing or incorrect on the tablet.
    *   Ensure your user on the tablet is in the `wheel` group.

*   **"Host key verification failed"**:
    *   This happens the first time you connect. Just delete the old entry for the tablet's IP from `~/.ssh/known_hosts` on your PC and try connecting again, accepting the new key.

*   **Build Fails on Target**:
    *   If your tablet has a different architecture (e.g., `aarch64-linux`) than your PC (`x86_64-linux`), Nix may need to build some packages from source on the tablet itself. This can be slow. You can set up a remote builder or a binary cache like Cachix to speed this up.

*   **`--target-host` vs. `--build-host`**:
    *   `--target-host`: The build happens *on the target machine*. Nix copies source code and derivations, and the tablet does the building.
    *   `--build-host`: The build happens *on the specified build machine* (which can be your local PC), and only the final result (the store paths) are copied to the target. This is much faster if your PC is more powerful than your tablet. For this to work, you need to configure the tablet to trust your PC as a substituter.

For starting out, `--target-host` is simpler and perfectly fine.




## 6. Step 4: Testing Locally with a Virtual Machine

Before deploying to your physical tablet, you should always test your configuration in a local VM. NixOS has first-class support for building a QEMU virtual machine that runs your exact system configuration.

This is the fastest and safest way to:
- See if a new configuration boots.
- Test if services start correctly.
- Experiment with new UI settings or packages.

### 6.1. The Build Command

From your flake directory on your PC, run the following command:

```bash
nix build .#nixosConfigurations.vlenovo.config.system.build.vm --show-trace
```

Let's break this down:
*   `nix build`: The standard command to build a derivation.
*   `.#nixosConfigurations.vlenovo`: This targets the `vlenovo` machine definition inside your flake's `nixosConfigurations`.
*   `.config.system.build.vm`: This is the crucial part. Every NixOS configuration has a special attribute, `.config.system.build.vm`, which is a derivation that builds a script to run the system in a QEMU VM.
*   `--show-trace`: A helpful flag that provides a full error log if the build fails.

This command will evaluate your entire configuration and build all the necessary packages. It will **not** start the VM automatically. When it finishes, it will create a `./result` symlink in your current directory.

### 6.2. The Run Command

After the build completes, you can run the VM using the script that was just built:

```bash
./result/bin/run-vlenovo-vm
```

This command will open a QEMU window, and you will see your NixOS system booting up, just as it would on real hardware. You will see the `sxmo` service start and the graphical interface appear.

### 6.3. Interacting with the VM

*   **SSH Access**: Your `configuration.nix` includes a port forward for SSH on port 2222. While the VM is running, you can open a new terminal on your host PC and SSH into the guest VM:
    ```bash
    ssh -p 2222 alex@localhost
    ```
    This is extremely useful for checking logs (`journalctl -u sxmo.service`), inspecting files, and debugging services from a familiar terminal environment.

*   **Closing the VM**: You can close the QEMU window or press `Ctrl+C` in the terminal where you launched `./result/bin/run-vlenovo-vm`.

### 6.4. The Development Workflow

Your typical workflow for making a change should be:

1.  Edit your `.nix` files.
2.  Run `nix flake check -L` to run your automated tests (`sxmo-vm-test`, `sxmo-ui-test`, etc.).
3.  If checks pass, run `nix build .#...vm` to build the VM.
4.  Run `./result/bin/run-vlenovo-vm` to visually inspect the changes.
5.  Once you are happy, deploy to your real tablet with `nixos-rebuild switch --target-host ...`.

---

## 7. Troubleshooting and Common Issues

*   **Permission Denied (SSH)**: Verify your SSH public key is correct on the tablet and that file permissions (`~/.ssh`, `~/.ssh/authorized_keys`) are correct.
*   **`sudo: a password is required` (Remote Deploy)**: Ensure `security.sudo.wheelNeedsPassword = false;` is active on the target device.
*   **VM Fails to Build**: Use the `--show-trace` flag to get a detailed error. The issue is in your NixOS configuration itself.
*   **VM Boots to a Black Screen**: SSH into the running VM (`ssh -p 2222 ...`) and check the systemd journal for the failing service (e.g., `journalctl -u sxmo.service -b`).
*   **Architecture Mismatches**: If your PC is `x86_64` and your tablet is `aarch64`, remote deployment will trigger a native build on the tablet, which can be very slow. Consider setting up a more advanced remote builder for cross-compilation.