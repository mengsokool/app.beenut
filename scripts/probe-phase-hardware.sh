#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<USAGE
Usage: $0 <probe>

Probes:
  camera-inventory
  gstreamer-inventory
  gpio-inventory
  ai-runtime-inventory
  systemd-units
  package-inventory
USAGE
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

section() {
  printf '\n## %s\n' "$1"
}

probe_camera_inventory() {
  local found=1
  section "v4l2"
  if have_command v4l2-ctl; then
    v4l2-ctl --list-devices && found=0 || true
  else
    echo "v4l2-ctl: missing"
  fi

  section "libcamera"
  if have_command libcamera-hello; then
    libcamera-hello --list-cameras && found=0 || true
  else
    echo "libcamera-hello: missing"
  fi

  section "macOS"
  if have_command system_profiler; then
    system_profiler SPCameraDataType && found=0 || true
  else
    echo "system_profiler: missing"
  fi
  return "$found"
}

probe_gstreamer_inventory() {
  have_command gst-inspect-1.0 || {
    echo "gst-inspect-1.0: missing"
    return 1
  }

  local found=1
  section "version"
  gst-inspect-1.0 --version
  section "camera sources"
  for plugin in libcamerasrc v4l2src avfvideosrc videotestsrc; do
    if gst-inspect-1.0 "$plugin" >/tmp/beenut-gst-probe.$$ 2>&1; then
      echo "$plugin: available"
      head -80 /tmp/beenut-gst-probe.$$
      found=0
    else
      echo "$plugin: missing"
    fi
  done
  rm -f /tmp/beenut-gst-probe.$$
  return "$found"
}

probe_gpio_inventory() {
  local found=1
  section "libgpiod"
  if have_command gpiodetect; then
    if gpiodetect; then
      found=0
    fi
  else
    echo "gpiodetect: missing"
  fi

  if have_command gpioinfo; then
    gpioinfo | head -200 || true
  else
    echo "gpioinfo: missing"
  fi

  section "gpio devices"
  if compgen -G "/dev/gpiochip*" >/dev/null; then
    ls -la /dev/gpiochip*
    found=0
  else
    echo "/dev/gpiochip*: missing"
  fi

  section "sysfs"
  if [[ -d /sys/class/gpio ]]; then
    ls -la /sys/class/gpio
    if compgen -G "/sys/class/gpio/gpiochip*" >/dev/null; then
      found=0
    fi
  else
    echo "/sys/class/gpio: missing"
  fi
  return "$found"
}

probe_ai_runtime_inventory() {
  local found=1
  section "hailo"
  if have_command hailortcli; then
    hailortcli scan && found=0 || true
  else
    echo "hailortcli: missing"
  fi
  if compgen -G "/dev/hailo*" >/dev/null; then
    ls -la /dev/hailo*
    found=0
  else
    echo "/dev/hailo*: missing"
  fi

  section "models"
  local model_roots=(
    "/opt/beenut/service/models"
    "/opt/beenut/models"
    "$ROOT_DIR/service/models"
    "$ROOT_DIR/opt/beenut/service/models"
    "$ROOT_DIR/build/deb/opt/beenut/service/models"
  )
  for root in "${model_roots[@]}"; do
    if [[ -d "$root" ]]; then
      echo "model root: $root"
      if find "$root" -maxdepth 4 -type f \( -name '*.onnx' -o -name '*.hef' \) -print -quit | grep -q .; then
        find "$root" -maxdepth 4 -type f \( -name '*.onnx' -o -name '*.hef' -o -name 'manifest.json' -o -name 'labels.txt' \) -printf "%p %s bytes\n" 2>/dev/null || find "$root" -maxdepth 4 -type f \( -name '*.onnx' -o -name '*.hef' -o -name 'manifest.json' -o -name 'labels.txt' \) -print
        found=0
      fi
    fi
  done
  return "$found"
}

probe_systemd_units() {
  local found=1
  section "installed units"
  if have_command systemctl; then
    systemctl cat beenut-service beenut-kiosk beenut-first-boot 2>/dev/null && found=0 || true
    systemctl is-enabled beenut-service beenut-kiosk beenut-first-boot 2>/dev/null || true
    systemctl status beenut-service beenut-kiosk --no-pager 2>/dev/null || true
  else
    echo "systemctl: missing"
  fi

  section "packaged units"
  local required=(
    "$ROOT_DIR/packaging/systemd/beenut-service.service"
    "$ROOT_DIR/systemd/beenut-service.service"
    "$ROOT_DIR/packaging/systemd/beenut-first-boot.service"
    "$ROOT_DIR/systemd/beenut-first-boot.service"
    "$ROOT_DIR/packaging/systemd/beenut-kiosk-flutter-pi.service"
    "$ROOT_DIR/systemd/beenut-kiosk-flutter-pi.service"
    "$ROOT_DIR/packaging/systemd/beenut-kiosk-linux.service"
    "$ROOT_DIR/systemd/beenut-kiosk-linux.service"
  )
  local unit_names=(
    beenut-service.service
    beenut-first-boot.service
    beenut-kiosk-flutter-pi.service
    beenut-kiosk-linux.service
  )
  local missing=0
  for unit_name in "${unit_names[@]}"; do
    local found_unit=""
    for unit in "${required[@]}"; do
      if [[ "$(basename "$unit")" == "$unit_name" && -f "$unit" ]]; then
        found_unit="$unit"
        break
      fi
    done
    if [[ -n "$found_unit" ]]; then
      echo "$found_unit: present"
      sed -n '1,120p' "$found_unit"
    else
      echo "$unit_name: missing"
      missing=1
    fi
  done
  if [[ "$missing" == "0" ]]; then
    found=0
  fi
  return "$found"
}

probe_package_inventory() {
  local found=1
  section "dpkg"
  if have_command dpkg; then
    dpkg -l | grep -E "beenut|flutter-pi|gstreamer|hailo|onnx" && found=0 || true
  else
    echo "dpkg: missing"
  fi

  section "package staging"
  for path in "$ROOT_DIR/packaging/debian/DEBIAN/control" "$ROOT_DIR/DEBIAN/control" "$ROOT_DIR/build/deb" "$ROOT_DIR/VERSION" "/opt/beenut/VERSION"; do
    if [[ -e "$path" ]]; then
      echo "$path: present"
      found=0
    else
      echo "$path: missing"
    fi
  done
  return "$found"
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

case "$1" in
  camera-inventory) probe_camera_inventory ;;
  gstreamer-inventory) probe_gstreamer_inventory ;;
  gpio-inventory) probe_gpio_inventory ;;
  ai-runtime-inventory) probe_ai_runtime_inventory ;;
  systemd-units) probe_systemd_units ;;
  package-inventory) probe_package_inventory ;;
  -h|--help) usage ;;
  *)
    echo "Unknown probe: $1" >&2
    usage >&2
    exit 2
    ;;
esac
