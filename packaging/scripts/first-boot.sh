#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${BEENUT_CONFIG:-/etc/beenut/config.json}"
DEFAULT_CONFIG="${BEENUT_DEFAULT_CONFIG:-/opt/beenut/config/default.json}"
DEVICE_PATH="${DEVICE_PATH:-/etc/beenut/device.json}"
DONE_PATH="${DONE_PATH:-/var/lib/beenut/first-boot.done}"
LOG_PATH="${LOG_PATH:-/var/log/beenut/first-boot.log}"
IMAGE_VERSION_PATH="${IMAGE_VERSION_PATH:-/etc/beenut/image-version}"
APP_VERSION_PATH="${APP_VERSION_PATH:-/opt/beenut/VERSION}"

mkdir -p "$(dirname "$CONFIG_PATH")" "$(dirname "$DEVICE_PATH")" "$(dirname "$DONE_PATH")" "$(dirname "$LOG_PATH")"

exec > >(tee -a "$LOG_PATH") 2>&1

if [[ -f "$DONE_PATH" ]]; then
  echo "First boot already completed: $DONE_PATH"
  exit 0
fi

echo "Starting BeeNut first boot setup"

board_model=""
if [[ -f /proc/device-tree/model ]]; then
  board_model="$(tr -d '\0' </proc/device-tree/model || true)"
fi
if [[ -z "$board_model" && -f /proc/cpuinfo ]]; then
  board_model="$(awk -F: '/Model/ {sub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
fi
serial="$(awk -F: '/Serial/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
if [[ -z "$serial" ]]; then
  serial="$(cat /etc/machine-id 2>/dev/null | head -c 16 || true)"
fi
if [[ -z "$serial" ]]; then
  serial="unknown"
fi

platform_class="linux_pc"
if echo "$board_model" | grep -qi "Raspberry Pi"; then
  platform_class="raspberry_pi"
elif [[ -e /sys/class/gpio || -e /dev/gpiochip0 ]]; then
  platform_class="linux_sbc"
fi

image_version="$(cat "$IMAGE_VERSION_PATH" 2>/dev/null || true)"
app_version="$(cat "$APP_VERSION_PATH" 2>/dev/null || true)"
device_id="beenut-${platform_class}-${serial}"

python3 - "$DEVICE_PATH" "$device_id" "$platform_class" "$board_model" "$serial" "$image_version" "$app_version" <<'PY'
import json
import sys
from pathlib import Path

target = Path(sys.argv[1])
data = {
    "deviceId": sys.argv[2],
    "platformClass": sys.argv[3],
    "boardModel": sys.argv[4],
    "serial": sys.argv[5],
    "imageVersion": sys.argv[6],
    "appVersion": sys.argv[7],
}
target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

if [[ ! -f "$CONFIG_PATH" && -f "$DEFAULT_CONFIG" ]]; then
  cp "$DEFAULT_CONFIG" "$CONFIG_PATH"
fi

if [[ -f "$CONFIG_PATH" ]]; then
  cp "$CONFIG_PATH" "$CONFIG_PATH.first-boot.bak"
  python3 - "$CONFIG_PATH" "$platform_class" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
platform_class = sys.argv[2]
config = json.loads(path.read_text(encoding="utf-8"))
config.setdefault("schema_version", 1)
camera = config.setdefault("camera", {})
counting = config.setdefault("counting", {})

if platform_class == "raspberry_pi":
    if camera.get("source") in (None, "", "auto", "avfoundation"):
        camera["source"] = "libcamera"
        camera["device"] = ""
    if camera.get("preview_transport") in (None, "", "auto", "iosurface_nv12"):
        camera["preview_transport"] = "dmabuf_egl"
else:
    if camera.get("preview_transport") in (None, "", "auto", "dmabuf_egl", "iosurface_nv12"):
        camera["preview_transport"] = "shm_nv12"
    if counting.get("trigger_mode") == "tray_sensor":
        counting["trigger_mode"] = "real_time"
    config["safe_mode"] = True

path.write_text(json.dumps(config, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
PY
fi

if [[ "${BEENUT_SET_HOSTNAME:-0}" == "1" && "$serial" != "unknown" ]] && command -v hostnamectl >/dev/null 2>&1; then
  hostnamectl set-hostname "beenut-${serial: -6}" || true
fi

if id beenut >/dev/null 2>&1; then
  chown beenut:beenut "$CONFIG_PATH" "$DEVICE_PATH" 2>/dev/null || true
fi
chmod 0640 "$CONFIG_PATH" "$DEVICE_PATH" 2>/dev/null || true

date -u +%Y-%m-%dT%H:%M:%SZ > "$DONE_PATH"
echo "First boot complete"
echo "Device: $device_id"
echo "Platform: $platform_class"
