#!/run/current-system/sw/bin/bash
# Tablet root-only transient trial with independent systemd rollback timer.
# Never alters /etc, GRUB, current-system, or NixOS profile.
set -euo pipefail
umask 077
export PATH=/run/current-system/sw/bin:/usr/bin:/bin
[[ "$EUID" == 0 ]] || { echo 'Requires tablet root' >&2; exit 77; }
[[ -e /run/current-system && -e /run/booted-system ]] || exit 77
[[ "$(cat /etc/hostname)" == vlenovo ]] || { echo 'Refusing non-tablet host'; exit 77; }
[[ "$(readlink -f /run/current-system)" == "$(readlink -f /run/booted-system)" ]] || exit 78
[[ -r /boot/grub/grub.cfg ]] && grep -Fq 'NixOS - Configuration 55' /boot/grub/grub.cfg || exit 78
[[ -r /nix/var/nix/profiles/system-55-link/kernel &&
   -r /nix/var/nix/profiles/system-55-link/initrd ]] || exit 78
[[ "$(systemctl show flick -P FragmentPath)" == /etc/systemd/system/flick.service ]] || exit 78
[[ "$(systemctl is-active flick)" == active ]] || exit 78
for s in sshd seatd NetworkManager; do systemctl is-active --quiet "$s" || exit 78; done

mode="$1"
builds=/home/alex/lenovo-mvp/builds
case "$mode" in
  qt-egl)
    binary="$builds/flick-qt-egl-experimental-x86_64"
    elf_sha=361d97fcda198e202540298a23455496cabbaaf70a825a58ae85747b11a72f04
    launcher="$builds/.launch-flick-qt-egl-experimental"
    launcher_sha=3a5091a4be2b48814526dea0c4e0e72aaade46315422ef1024e61ac17b338776 ;;
  qt-egl-qml)
    binary="$builds/flick-qt-egl-qml-experimental-x86_64"
    elf_sha=4c0d8a75d70f727092522cc82941f12d6421b1b0c44b26e0f7a1a4cbe054006d
    launcher="$builds/.launch-flick-qt-egl-qml-experimental"
    launcher_sha=03c4d9c73be4475648feae827d53a31f55d7893c399dd0e99be661448c430e22 ;;
  qt-egl-qml-soak)
    binary="$builds/flick-qt-egl-qml-experimental-x86_64"
    elf_sha=4c0d8a75d70f727092522cc82941f12d6421b1b0c44b26e0f7a1a4cbe054006d
    launcher="$builds/.launch-flick-qt-egl-qml-experimental"
    launcher_sha=03c4d9c73be4475648feae827d53a31f55d7893c399dd0e99be661448c430e22 ;;
  *) echo "Only qt-egl, qt-egl-qml or qt-egl-qml-soak accepted" >&2; exit 2 ;;
esac
[[ -f "$binary" && -x "$binary" && ! -L "$binary" ]] || exit 78
[[ -f "$launcher" && -x "$launcher" && ! -L "$launcher" ]] || exit 78
[[ "$(sha256sum "$binary" | cut -d' ' -f1)" == "$elf_sha" ]] || exit 78
[[ "$(sha256sum "$launcher" | cut -d' ' -f1)" == "$launcher_sha" ]] || exit 78
bash -n "$launcher"
dropdir=/run/systemd/system/flick.service.d
override="$dropdir/90-vlenovo-gpu-trial.conf"
[[ ! -e "$override" && ! -L "$override" ]] || { echo 'Existing trial override; refusing' >&2; exit 78; }
[[ ! -d "$dropdir" || -z "$(ls -A "$dropdir")" ]] || { echo 'Existing Flick drop-ins; refusing' >&2; exit 78; }
[[ -z "$(systemctl show flick -P DropInPaths)" ]] || exit 78
rollback=/run/vlenovo-flick-gpu/rollback.sh
[[ -f "$rollback" && -x "$rollback" && ! -L "$rollback" ]] || exit 78
grep -Fxq "OVERRIDE=$override" "$rollback"
timer="vlenovo-flick-trial-rollback-$mode"
if systemctl is-active --quiet "$timer.timer"; then echo 'Existing rollback timer already active'; exit 78; fi
mkdir -p "$dropdir"
rollback_delay=145s
[[ "$mode" == qt-egl-qml-soak ]] && rollback_delay=360s
systemd-run --quiet --unit="$timer" --on-active="$rollback_delay" \
    --timer-property=AccuracySec=1s "$rollback"
systemctl is-active --quiet "$timer.timer" || { echo 'Rollback timer not active'; exit 78; }
cat > "$override" <<EOF
# VLENOVO_FLICK_GPU_TRIAL=1
[Service]
ExecStart=
ExecStart=$launcher
EOF
chmod 0600 "$override"
systemctl daemon-reload
printf 'TIMER_ARMED=%s\nTRIAL_VARIANT=%s\nTRIAL_LAUNCHER=%s\nORIGINAL_PID=%s\nUTC_BEFORE_RESTART=%s\n' \
    "$timer.timer" "$mode" "$launcher" "$(systemctl show flick -P MainPID)" "$(date -u +%FT%TZ)"
systemctl restart flick.service
printf 'RESTART_RETURNED=0\nTRIAL_PID=%s\nUTC_AFTER_RESTART=%s\n' \
    "$(systemctl show flick -P MainPID)" "$(date -u +%FT%TZ)"
