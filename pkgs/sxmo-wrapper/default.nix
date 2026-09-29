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

    # Upstream superd units use FHS /usr/bin paths. On NixOS, resolve these
    # commands through the wrapped runtime PATH instead.
    sed -i 's|ExecStart=/usr/bin/|ExecStart=|' \
      configs/services/*.service \
      configs/external-services/*.service

    # NixOS provides the audio daemon through systemd/user services. Sxmo
    # 1.17.1 predates the systemd guard that exists upstream now, so add it
    # here to prevent superd from spawning a second PulseAudio restart loop.
    substituteInPlace configs/default_hooks/sxmo_hook_start.sh \
      --replace 'if [ -z "$SXMO_NO_AUDIO" ]; then
	if [ "$(command -v pulseaudio)" ]; then
		superctl start pulseaudio
	elif [ "$(command -v pipewire)" ]; then
		# pipewire-pulse will start pipewire
		superctl start pipewire-pulse
		superctl start wireplumber
	fi

	# monitor for headphone for statusbar
	superctl start sxmo_soundmonitor
fi' 'if [ -z "$SXMO_NO_AUDIO" ]; then
	if ! [ -d /run/systemd/system ]; then
		if [ "$(command -v pulseaudio)" ]; then
			superctl start pulseaudio
		elif [ "$(command -v pipewire)" ]; then
			# pipewire-pulse will start pipewire
			superctl start pipewire-pulse
			superctl start wireplumber
		fi
	fi

	# monitor for headphone for statusbar
	superctl start sxmo_soundmonitor
fi'

    # Allow device profiles to add lisgd arguments such as explicit physical
    # screen geometry. This is needed on scaled HiDPI touchscreens.
    substituteInPlace configs/default_hooks/sxmo_hook_lisgdstart.sh \
      --replace 'lisgd "$@" -d "$LISGD_INPUT_DEVICE"' 'lisgd "$@" ''${SXMO_LISGD_EXTRA_ARGS:-} -d "$LISGD_INPUT_DEVICE"'

    # The migration script needs to find all default config files. The original
    # script relies on XDG_DATA_DIRS to find them. We inject the correct path
    # at the top of the script so all subsequent calls to `xdg_data_path` work.
    sed -i '2i export XDG_DATA_DIRS="${placeholder "out"}/share''${XDG_DATA_DIRS:+:}$XDG_DATA_DIRS"' \
      scripts/core/sxmo_migrate.sh

    # Runtime hooks and superd service definitions are also discovered through
    # XDG_DATA_DIRS. Nix does not add this package's share directory by default.
    sed -i '2i export XDG_DATA_DIRS="${placeholder "out"}/share''${XDG_DATA_DIRS:+:}$XDG_DATA_DIRS"' \
      scripts/core/sxmo_init.sh

    # Inject the full runtime PATH at the top of sxmo_init.sh.
    # This script is sourced by sxmo_winit.sh (on start) and its `trap`
    # calls other hooks (on stop), so this ensures the PATH is always set.
    sed -i '2i export PATH="${placeholder "out"}/bin:${lib.makeBinPath ([
      (sway.override { withBaseWrapper = true; withGtkWrapper = true; })
      bemenu foot wvkbd swayidle swaybg wob mako superd lisgd
      bc bonsai brightnessctl conky curl grim slurp
      coreutils gnugrep util-linux jq dbus procps
      libnotify inotify-tools xdg-user-dirs xdg-utils light
      networkmanager playerctl pulseaudio upower wl-clipboard wtype
      codemadness-frontends yt-dlp
    ])}''${PATH:+:}$PATH"' scripts/core/sxmo_init.sh


  # Use absolute paths to prevent any sourcing issues.
  substituteInPlace scripts/core/sxmo_winit.sh \
    --replace ". sxmo_init.sh" ". ${placeholder "out"}/bin/sxmo_init.sh"
    
  substituteInPlace configs/profile.d/sxmo_init.sh \
    --replace ". sxmo_common.sh" ". ${placeholder "out"}/bin/sxmo_common.sh"

  substituteInPlace scripts/core/sxmo_init.sh \
      --replace "/etc/profile.d/sxmo_init.sh" "${placeholder "out"}/etc/profile.d/sxmo_init.sh"

# The tablet's physical Meta button is Linux KEY_LEFTMETA (evdev 125), which
# becomes XKB keycode 133. Bind the raw keycode instead of Super_L so SXMO's
# mobile menu keymaps cannot overwrite the meaning of the button.
substituteInPlace scripts/core/sxmo_swayinitconf.sh \
  --replace 'if [ -n "$SXMO_DISABLE_KEYBINDS" ]; then' 'swaymsg -- bindcode --release --input-device="1:1:gpio-keys" 133 exec ${placeholder "out"}/bin/vlenovo-osk-toggle

if [ -n "$SXMO_DISABLE_KEYBINDS" ]; then'

  '';

  postInstall = (oldAttrs.postInstall or "") + ''
    cat > "$out/bin/vlenovo-osk-toggle" <<'EOF'
#!/bin/sh
set -u

LOG="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/vlenovo-osk.log"
LOCK="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/vlenovo-osk.lock"

if ! mkdir "$LOCK" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT HUP INT TERM

{
  printf '%s key action\n' "$(date -Ins)"
  if ${pkgs.procps}/bin/pgrep -x wvkbd-mobintl >/dev/null 2>&1; then
    echo "closing existing wvkbd"
    ${pkgs.procps}/bin/pkill -x wvkbd-mobintl || true
    exit 0
  fi

  echo "opening wvkbd"
  ${pkgs.wvkbd}/bin/wvkbd-mobintl >> "$LOG" 2>&1 &
  pid=$!
  sleep 0.4
  if kill -0 "$pid" 2>/dev/null; then
    echo "wvkbd started pid=$pid"
  else
    echo "wvkbd failed pid=$pid"
  fi
} >> "$LOG" 2>&1
EOF
    chmod 755 "$out/bin/vlenovo-osk-toggle"

    install -D -m 0755 ${./vlenovo-deviceprofile.sh} \
      "$out/bin/sxmo_deviceprofile_vlenovo.sh"
  '';

  meta = sxmo-utils-unwrapped.meta // {
    description = "Scripts and programs for the Sxmo mobile environment (Nix wrapped)";
  };
})