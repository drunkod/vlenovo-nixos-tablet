{
  description = "NixOS + Sxmo configuration for the vlenovo tablet";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable"; # Changed to actual unstable
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # TODO: Add any other flake you might need
    # hardware.url = "github:nixos/nixos-hardware";

    # Shameless plug: looking for a way to nixify your themes and make
    # everything match nicely? Try nix-colors!
    # nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;
    # Supported systems for your flake packages, shell, etc.
    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;
    linuxSystems = [ "aarch64-linux" "i686-linux" "x86_64-linux" ];
    forLinuxSystems = nixpkgs.lib.genAttrs linuxSystems;
  in {
    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    packages = forLinuxSystems (system:
      import ./pkgs {
        pkgs = nixpkgs.legacyPackages.${system};
        pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${system};
      });

    # Native graphics-driver research shell for the x86_64 Bay Trail tablet.
    devShells.x86_64-linux.graphics =
      let pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in pkgs.mkShell {
        packages = with pkgs; [
          acpica-tools
          apitrace
          drm_info
          gdb
          git
          intel-gpu-tools
          jq
          libdrm
          mesa-demos
          pciutils
          strace
        ];
        shellHook = ''
          echo "vlenovo graphics shell: i915/DRM/Mesa diagnostic tools available"
        '';
      };

    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;
    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./modules/home-manager;

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      vlenovo = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          # > Our main nixos configuration file <
          ./nixos/configuration.nix
        ];
      };
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      "alex@vlenovo" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/home.nix
        ];
      };
    };

        checks = forLinuxSystems (system:
      let
        # 1. Create a `pkgs` instance specifically for the tests.
        #    This makes the test self-contained.
        pkgs = import nixpkgs {
          inherit system;
          # 2. Apply the SAME overlays here that your main configuration uses.
          #    This ensures that `pkgs.sxmo-utils` inside the test resolves
          #    to your custom wrapped version.
          overlays = [
            outputs.overlays.additions
            outputs.overlays.modifications
            outputs.overlays.unstable-packages
          ];
        };
      in
      {
        # --- YOUR EXISTING, WORKING SERVICE TEST ---
        sxmo-vm-test = pkgs.nixosTest {
          name = "sxmo-vm-test";
          nodes.machine = {
            imports = [
              ./nixos/common-configuration.nix
              outputs.nixosModules.sxmo-utils
            ];
            # Overlays are now applied to the top-level `pkgs` for the test.
          };
          testScript = ''
                  machine.start()
                  machine.wait_for_unit("multi-user.target")
                  machine.wait_for_unit("sxmo.service")

                  # Give it a moment to settle.
                  machine.sleep(5)

                  # Final state check: it must be active.
                  machine.succeed("systemctl is-active --quiet sxmo.service")

                  # Log check: it must not have failed during startup.
                  machine.succeed("! journalctl -u sxmo.service | grep 'Failed with result'")
          '';
        };

        # --- THE NEW, CORRECTED UI TEST ---
        sxmo-ui-test = pkgs.nixosTest {
          name = "sxmo-ui-test";

          nodes.machine = {
            # 3. The node configuration is now much simpler.
            #    It inherits the correctly configured `pkgs` from the `let` block above.
            imports = [
              ./nixos/common-configuration.nix
              outputs.nixosModules.sxmo-utils
            ];

            # Enable graphics in the VM for screenshots.
            virtualisation.graphics = true;

            # Add the screenshot tool.
            # It correctly comes from the overridden `pkgs`.
            environment.systemPackages = [ pkgs.grim ];
          };

                    testScript = ''
            import os

            machine.start()
            machine.wait_for_unit("graphical.target")
            machine.wait_for_unit("sxmo.service")

            # Give the UI plenty of time to draw everything
            machine.sleep(10)

            # sxmo_wm.sh execwait will find the user's graphical session and run the
            # command within it, inheriting all the necessary environment variables.
            machine.succeed("sxmo_wm.sh execwait grim /tmp/screenshot.png")

            # Copy the screenshot from the VM to the host for analysis
            machine.copy_from_vm("/tmp/screenshot.png")

            # Assert that the screenshot file is not empty or tiny
            assert os.path.getsize("screenshot.png") > 5000, "Screenshot file is too small, UI likely didn't render."
          '';
        };

        # --- NEW VM TEST: Check sxmo_appmenu.sh ---
        sxmo-appmenu-test = pkgs.nixosTest {
          name = "sxmo-appmenu-test";
          nodes.machine = {
            imports = [
              ./nixos/common-configuration.nix
              outputs.nixosModules.sxmo-utils
            ];
            virtualisation.graphics = true; # Sxmo services might need this
          };
          testScript = ''
            machine.start()
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("sxmo.service")

            # Give services a moment to settle after sxmo.service is active
            machine.sleep(5)

            # Check if sxmo_appmenu.sh can be executed successfully by the user
            # sxmo_appmenu.sh might try to interact with dmenu/bemenu,
            # but we are primarily testing if the script can be found and started.
            # A successful exit (0) is a good sign.
            # It might print to stderr if no menu utility is found in PATH or if display is not available,
            # so we don't check stderr, only the exit code.
            machine.succeed("sudo -u alex sxmo_appmenu.sh")
          '';
        };

        # --- NEW UI TEST: Check for foot terminal process ---
        sxmo-foot-terminal-test = pkgs.nixosTest {
          name = "sxmo-foot-terminal-test";
          nodes.machine = {
            imports = [
              ./nixos/common-configuration.nix
              outputs.nixosModules.sxmo-utils
            ];
            virtualisation.graphics = true; # UI tests need graphics
            environment.systemPackages = [ pkgs.foot pkgs.procps ]; # Add foot for the test, procps for pgrep
          };
          testScript = ''
            machine.start()
            machine.wait_for_unit("graphical.target")
            machine.wait_for_unit("sxmo.service")

            # Give the UI plenty of time to draw everything and start initial applications
            machine.sleep(15)

            # Check if the foot terminal process is running.
            # This assumes sxmo or its user configuration might start foot.
            # If not, this test would need adjustment or target a different default UI process.
            machine.succeed("pgrep -u alex foot")
          '';
        };
      });
  };
}