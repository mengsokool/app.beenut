#!/bin/sh
# Enable BeeNut appliance units in a rootfs during image creation.
set -e

enable_unit() {
  unit="$1"
  target="${2:-multi-user.target}"

  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable "$unit"
    return
  fi

  unit_path="/etc/systemd/system/$unit"
  wants_dir="/etc/systemd/system/$target.wants"
  if [ ! -f "$unit_path" ]; then
    echo "Missing unit: $unit_path" >&2
    exit 1
  fi
  mkdir -p "$wants_dir"
  ln -sfn "../$unit" "$wants_dir/$unit"
}

disable_unit() {
  unit="$1"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable "$unit" >/dev/null 2>&1 || true
  fi
  find /etc/systemd/system -path "*/$unit" -type l -delete 2>/dev/null || true
}

enable_unit beenut-service.service multi-user.target
enable_unit beenut-kiosk.service multi-user.target
enable_unit beenut-kiosk.service graphical.target
disable_unit getty@tty1.service
