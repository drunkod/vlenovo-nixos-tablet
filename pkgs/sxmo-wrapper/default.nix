# vlenovo/pkgs/sxmo-wrapper/default.nix
# This wrapper handles the RUNTIME environment.
{ lib
, pkgs
, sxmo-utils-unwrapped
, codemadness-frontends
, yt-dlp
}:

sxmo-utils-unwrapped.overrideAttrs (oldAttrs: {
  # This postPatch hook modifies the scripts to work in the Nix environment.
  postPatch = with pkgs; ''
    # Force the Makefile to use the full path to GNU sed to ensure
    # the correct tool is used during the build.
    substituteInPlace Makefile \
      --replace "sed" "${gnused}/bin/sed"

    substituteInPlace setup_config_version.sh \
      --replace "busybox" "${busybox}/bin/busybox"
    

    # The migration script needs to find all default config files. The original
    # script relies on XDG_DATA_DIRS to find them. We inject the correct path
    # at the top of the script so all subsequent calls to `xdg_data_path` work.
    sed -i '2i export XDG_DATA_DIRS="${placeholder "out"}/share''${XDG_DATA_DIRS:+:}$XDG_DATA_DIRS"' \
      scripts/core/sxmo_migrate.sh

    # Inject the full runtime PATH at the top of sxmo_init.sh.
    # This script is sourced by sxmo_winit.sh (on start) and its `trap`
    # calls other hooks (on stop), so this ensures the PATH is always set.
    sed -i '2i export PATH="${placeholder "out"}/bin:${lib.makeBinPath ([
      (sway.override { withBaseWrapper = true; withGtkWrapper = true; })
      bemenu foot wvkbd swayidle wob mako superd lisgd
      coreutils gnugrep util-linux jq dbus
      libnotify inotify-tools xdg-user-dirs light
      codemadness-frontends yt-dlp
    ])}''${PATH:+:}$PATH"' scripts/core/sxmo_init.sh


  # Use absolute paths to prevent any sourcing issues.
  substituteInPlace scripts/core/sxmo_winit.sh \
    --replace ". sxmo_init.sh" ". ${placeholder "out"}/bin/sxmo_init.sh"
    
  substituteInPlace configs/profile.d/sxmo_init.sh \
    --replace ". sxmo_common.sh" ". ${placeholder "out"}/bin/sxmo_common.sh"

  substituteInPlace scripts/core/sxmo_init.sh \
      --replace "/etc/profile.d/sxmo_init.sh" "${placeholder "out"}/etc/profile.d/sxmo_init.sh"

# Patch the sway config template to use the absolute path for the startup hook.
# The hooks are installed in the share directory, not bin.
substituteInPlace configs/appcfg/sway_template \
  --replace "exec sxmo_hook_start.sh" "exec ${placeholder "out"}/share/sxmo/default_hooks/sxmo_hook_start.sh"

  '';

  meta = sxmo-utils-unwrapped.meta // {
    description = "Scripts and programs for the Sxmo mobile environment (Nix wrapped)";
  };
})