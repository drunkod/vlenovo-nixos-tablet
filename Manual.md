Of course. Here is a competent user manual for your NixOS tablet project, including a detailed guide on how to run and debug it remotely.

***

# VLenovo NixOS Tablet Project: User Manual

## 1. Overview

Welcome to your VLenovo tablet configuration! This project uses the power of [NixOS](https://nixos.org/) and [Nix Flakes](https://nixos.wiki/wiki/Flakes) to create a fully declarative, reproducible, and customizable operating system for your tablet.

The core of this setup is **[Sxmo (Simple X Mobile)](https://sxmo.org/)**, a minimalist, hackable, and touch-friendly user interface designed for mobile Linux devices. Your entire system, from the kernel to the applications and user dotfiles, is managed by the code in this repository.

**Key Features:**
*   **Declarative:** The entire system state is defined in `.nix` files. No more manual configuration drift.
*   **Reproducible:** You can rebuild the exact same system on any compatible machine.
*   **Powered by Flakes:** Uses the modern Nix Flakes feature for clean dependency management and project structure.
*   **Mobile-First UI:** Leverages a custom-built `sxmo-utils` package to provide a touch-and-gesture-based interface.
*   **User Management:** System configuration (`nixos`) and user environment (`home-manager`) are managed separately but work together seamlessly.

## 2. Project Structure

Understanding the file layout is key to managing your system.

*   `flake.nix`: The heart of the project. It defines all inputs (like `nixpkgs` and `home-manager`), outputs (packages, modules, and system configurations), and orchestrates how everything fits together.
*   `nixos/`: Contains system-wide configuration.
    *   `configuration.nix`: The main configuration file for the `vlenovo` host. This is where you configure system services, users, networking, the bootloader, etc.
    *   `hardware-configuration.nix`: Auto-generated file defining the hardware specifics (filesystems, kernel modules). You generally don't edit this.
*   `home-manager/`: Contains user-specific configurations.
    *   `home.nix`: Defines the environment for the user `alex`. This includes user-level packages, dotfiles, and user services.
*   `modules/`: Reusable configurations (NixOS modules) that can be shared or upstreamed.
    *   `nixos/sxmo-utils/`: A custom module you've created to cleanly integrate Sxmo into NixOS. It defines the `systemd` service and related system settings.
*   `pkgs/`: Custom Nix package definitions (derivations).
    *   `sxmo-1.17.1/`: The Nix expression to build your specific version of `sxmo-utils`, complete with patches and dependencies.
    *   `codemadness-frontends/`: A dependency for `sxmo-utils`, packaged for Nix.
*   `overlays/`: A mechanism to add your custom packages (`pkgs/`) or modify existing ones from `nixpkgs`.

## 3. Prerequisites

To manage your tablet from a development machine, you will need:

1.  **A Workstation:** A separate computer (e.g., your laptop) where you will edit the configuration.
2.  **Nix Installation:** [Nix must be installed](https://nixos.org/download.html) on your workstation with Flakes enabled. If you haven't enabled flakes, run:
    ```bash
    # Edit or create ~/.config/nix/nix.conf or /etc/nix/nix.conf
    # Add these lines:
    experimental-features = nix-command flakes
    ```
3.  **Git:** To manage your configuration versions.
4.  **Initial NixOS on Tablet:** The tablet (`vlenovo`) must have a **base NixOS installation** already running. During the installation, ensure you:
    *   Set a root password.
    *   Enable the OpenSSH service (`services.openssh.enable = true;`).
    *   Connect it to your local network.

## 4. How to Run & Deploy Remotely

This workflow allows you to edit files on your workstation and deploy them directly to the tablet over the network. The build process happens on the tablet itself (or on a more powerful builder if configured).

### Step 1: Configure SSH Access

For a seamless experience, set up SSH key-based authentication and a host alias on your **workstation**.

1.  **Copy your SSH Key:** If you haven't already, copy your public SSH key to the tablet.
    ```bash
    # On your workstation
    ssh-copy-id root@<tablet-ip-address>
    ```

2.  **Create an SSH Alias (Recommended):** Edit the `~/.ssh/config` file on your workstation to add an entry for your tablet. This saves you from typing the IP address and user every time.

    ```
    # ~/.ssh/config on your workstation
    Host vlenovo
      HostName <tablet-ip-address>
      User root
      Port 22
    ```
    Now you can simply use `ssh vlenovo` to connect as root.

### Step 2: Deploy the Configuration

With SSH configured, you can now build and deploy your flake from your workstation to the tablet with a single command.

Navigate to your project directory (`vlenovo/`) on your **workstation** and run:

```bash
nixos-rebuild switch --flake .#vlenovo --target-host vlenovo --use-remote-sudo
```

Let's break down this command:
*   `nixos-rebuild switch`: The standard command to build a new configuration and make it the currently running one.
*   `--flake .#vlenovo`: Tells `nixos-rebuild` to use the current directory's flake and build the NixOS configuration named `vlenovo` (as defined in your `flake.nix`).
*   `--target-host vlenovo`: This is the magic flag. It specifies that the build and deployment should happen on the remote machine aliased as `vlenovo` in your SSH config.
*   `--use-remote-sudo`: Since you're connecting as `root`, this ensures all build and activation commands are run with the correct privileges.

After this command completes, your tablet will be running the new configuration. The `alex` user will be created, and Sxmo will be started as the graphical session.

## 5. How to Debug Remotely

"Run and debug at once" means having a tight feedback loop. While you deploy changes, you should be monitoring the tablet to see what's happening. The best way to do this is with two terminal windows.

### The "At Once" Workflow

Open two terminals on your workstation.

**Terminal 1: The Command Center**
This is where you will edit your code and run the deployment command.
```bash
# In your project directory
# 1. Make a change, e.g., edit nixos/configuration.nix
# 2. Save the file
# 3. Deploy the change
nixos-rebuild switch --flake .#vlenovo --target-host vlenovo --use-remote-sudo
```

**Terminal 2: The Log Viewer**
This terminal will have a live SSH session to the tablet, tailing the logs. This gives you **immediate feedback** as the new configuration is activated.

1.  **SSH into the tablet as the `alex` user:**
    ```bash
    # You may need to adjust your ~/.ssh/config to connect as alex
    # or just run:
    ssh alex@<tablet-ip-address>
    ```

2.  **Monitor the Sxmo Service Logs:** The most important log for debugging the UI is the `sxmo.service` log.
    ```bash
    # On the tablet, via SSH
    journalctl -u sxmo.service -f
    ```
    *   `journalctl`: The tool for querying the systemd journal (logs).
    *   `-u sxmo.service`: Filters logs for *only* the `sxmo` service unit.
    *   `-f`: "Follow" the log, showing new entries in real-time.

3.  **Monitor All System Logs:** If the problem is not in Sxmo itself (e.g., a networking or kernel issue), you can follow the entire system log.
    ```bash
    # On the tablet, via SSH
    journalctl -f
    ```

### Common Debugging Scenarios

*   **Scenario: The screen is black after a rebuild.**
    *   **Action:** Look at your `journalctl -u sxmo.service -f` window. It will likely show an error message from `sxmo_winit.sh` or one of its child scripts. A common cause is a syntax error in a shell script or a missing dependency. The custom `sxmo-1.13.0/default.nix` package hardcodes the `PATH`, so if a new dependency is needed by a script, it must be added there.

*   **Scenario: The system fails to boot after a rebuild.**
    *   **Action:** If the tablet reboots and gets stuck, you can reboot and select an older generation from the GRUB boot menu. Once logged in, check the logs from the failed boot:
        ```bash
        # On the tablet, via SSH
        journalctl -b -1 -p 3
        ```
        *   `-b -1`: Shows logs from the previous boot.
        *   `-p 3`: Filters for messages with priority "error" and higher.

*   **Scenario: A script or application isn't working as expected.**
    *   **Action:** SSH into the tablet as `alex`. You are now in the live environment. You can run the scripts manually to see their output and errors.
        ```bash
        # On the tablet, via SSH
        # Example: Test the brightness script
        /nix/store/...-sxmo-utils-1.13.0/bin/sxmo_brightness.sh up
        ```
        (Find the exact path with `which sxmo_brightness.sh`). This allows for interactive testing.

## 6. Customizing Your Setup

*   **To Add a System-Wide Package:**
    *   Edit `vlenovo/nixos/configuration.nix`.
    *   Add the package name to `environment.systemPackages`.
    *   Re-run the `nixos-rebuild` command.

*   **To Add a User Package for `alex`:**
    *   Edit `vlenovo/home-manager/home.nix`.
    *   Add the package name to `home.packages`.
    *   Re-run the `nixos-rebuild` command.

*   **To Modify Sxmo:**
    *   Most changes will be in `vlenovo/pkgs/sxmo-1.13.0/default.nix`.
    *   For example, to add `htop` to the PATH available in all Sxmo scripts, you would add `htop` to the `lib.makeBinPath` list inside the `postPatch` phase.
    *   After changing the package definition, `nixos-rebuild` will automatically rebuild it and deploy the new version. This is the power of Nix
