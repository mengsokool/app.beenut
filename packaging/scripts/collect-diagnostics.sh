#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-/var/log/beenut/diagnostics}"
CONFIG_PATH="${BEENUT_CONFIG:-/etc/beenut/config.json}"
RUNTIME_DIR="${RUNTIME_DIR:-/tmp}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/beenut-diagnostics.XXXXXX")"
BUNDLE_DIR="$WORK_DIR/diagnostics"

mkdir -p "$BUNDLE_DIR" "$OUTPUT_DIR"

write_command() {
  local output_file="$1"
  shift
  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
    "$@"
  } >"$BUNDLE_DIR/$output_file" 2>&1 || true
}

copy_if_exists() {
  local source_file="$1"
  local target_file="$2"
  if [[ -f "$source_file" ]]; then
    cp "$source_file" "$BUNDLE_DIR/$target_file"
  else
    printf 'missing: %s\n' "$source_file" >"$BUNDLE_DIR/$target_file"
  fi
}

query_backend() {
  local socket_path="$1"
  local config_path="$2"
  python3 - "$socket_path" "$config_path" "$BUNDLE_DIR" <<'PY'
import json
import socket
import sys
from pathlib import Path

socket_path, config_path, bundle_dir = sys.argv[1], sys.argv[2], Path(sys.argv[3])
events_path = bundle_dir / "backend-events.jsonl"
capabilities_path = bundle_dir / "capabilities.json"
validation_path = bundle_dir / "validation.json"
diagnostics_path = bundle_dir / "diagnostic-events.jsonl"

def write_missing(path: Path, message: str) -> None:
    path.write_text(f"missing: {message}\n", encoding="utf-8")

if not Path(socket_path).exists():
    for path in (events_path, capabilities_path, validation_path, diagnostics_path):
        write_missing(path, socket_path)
    raise SystemExit(0)

config = {}
try:
    config = json.loads(Path(config_path).read_text(encoding="utf-8"))
except Exception:
    pass

commands = [
    {"type": "getCapabilities"},
    {"type": "validateConfig", "config": config},
    {"type": "runDiagnostic", "target": "camera"},
    {"type": "runDiagnostic", "target": "model"},
    {"type": "runDiagnostic", "target": "gpio"},
]

events = []
diagnostics = []
capabilities = None
validation = None

try:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(2.0)
    client.connect(socket_path)
    for command in commands:
        client.sendall((json.dumps(command, separators=(",", ":")) + "\n").encode("utf-8"))

    buffer = b""
    while True:
        try:
            chunk = client.recv(65536)
        except socket.timeout:
            break
        if not chunk:
            break
        buffer += chunk
        while b"\n" in buffer:
            raw, buffer = buffer.split(b"\n", 1)
            if not raw.strip():
                continue
            try:
                event = json.loads(raw.decode("utf-8"))
            except Exception:
                continue
            events.append(event)
            event_type = event.get("type")
            if event_type == "capabilities":
                capabilities = event.get("capabilities")
            elif event_type == "configValidation":
                validation = event.get("validation")
            elif event_type == "diagnosticEvent":
                diagnostics.append(event.get("event", event))
            if capabilities is not None and validation is not None and len(diagnostics) >= 3:
                raise TimeoutError
except TimeoutError:
    pass
except Exception as exc:
    write_missing(events_path, f"{socket_path}: {exc}")
finally:
    try:
        client.close()
    except Exception:
        pass

if events:
    events_path.write_text("".join(json.dumps(event, ensure_ascii=False) + "\n" for event in events), encoding="utf-8")
else:
    write_missing(events_path, socket_path)

if capabilities is not None:
    capabilities_path.write_text(json.dumps(capabilities, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
else:
    write_missing(capabilities_path, socket_path)

if validation is not None:
    validation_path.write_text(json.dumps(validation, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
else:
    write_missing(validation_path, socket_path)

if diagnostics:
    diagnostics_path.write_text("".join(json.dumps(event, ensure_ascii=False) + "\n" for event in diagnostics), encoding="utf-8")
else:
    write_missing(diagnostics_path, socket_path)
PY
}

cat >"$BUNDLE_DIR/manifest.json" <<JSON
{
  "created_utc": "$STAMP",
  "hostname": "$(hostname 2>/dev/null || true)",
  "config_path": "$CONFIG_PATH",
  "runtime_dir": "$RUNTIME_DIR"
}
JSON

redact_config() {
  local source_file="$1"
  local target_file="$2"
  python3 - "$source_file" "$target_file" <<'PY' || cp "$source_file" "$target_file"
import json
import sys

source, target = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as f:
    data = json.load(f)

secret_words = ("password", "passphrase", "token", "secret", "license", "key")

def redact(value):
    if isinstance(value, dict):
        return {
            key: ("<redacted>" if any(word in key.lower() for word in secret_words) else redact(child))
            for key, child in value.items()
        }
    if isinstance(value, list):
        return [redact(item) for item in value]
    if isinstance(value, str) and value.startswith("/Users/"):
        return "/Users/<redacted>" + value[value.find("/", len("/Users/")):] if "/" in value[len("/Users/"):] else "/Users/<redacted>"
    return value

with open(target, "w", encoding="utf-8") as f:
    json.dump(redact(data), f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
}

if [[ -f "$CONFIG_PATH" ]]; then
  redact_config "$CONFIG_PATH" "$BUNDLE_DIR/config.redacted.json"
else
  printf 'missing: %s\n' "$CONFIG_PATH" >"$BUNDLE_DIR/config.redacted.json"
fi

if [[ -f "$CONFIG_PATH.bak" ]]; then
  redact_config "$CONFIG_PATH.bak" "$BUNDLE_DIR/config.backup.redacted.json"
else
  printf 'missing: %s\n' "$CONFIG_PATH.bak" >"$BUNDLE_DIR/config.backup.redacted.json"
fi
copy_if_exists "$RUNTIME_DIR/beenutd.sock" "runtime-control-socket.txt"
copy_if_exists "$RUNTIME_DIR/beenut-preview.sock" "runtime-preview-socket.txt"
copy_if_exists "$RUNTIME_DIR/beenut-preview.sock.dmabuf" "runtime-dmabuf-socket.txt"
query_backend "$RUNTIME_DIR/beenutd.sock" "$CONFIG_PATH"

write_command system.txt uname -a
write_command os-release.txt sh -c 'cat /etc/os-release 2>/dev/null || sw_vers 2>/dev/null || true'
write_command process.txt sh -c 'ps -axo pid,ppid,user,%cpu,%mem,command | grep -E "beenut|flutter-pi|flutter|beenut" | grep -v grep'
write_command disk.txt df -h
write_command memory.txt sh -c 'free -h 2>/dev/null || vm_stat 2>/dev/null || true'
write_command temperature.txt sh -c 'vcgencmd measure_temp 2>/dev/null || cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null || true'
write_command camera.txt sh -c 'v4l2-ctl --list-devices 2>/dev/null; libcamera-hello --list-cameras 2>/dev/null; system_profiler SPCameraDataType 2>/dev/null'
write_command gstreamer.txt sh -c 'gst-inspect-1.0 --version 2>/dev/null; gst-inspect-1.0 libcamerasrc 2>/dev/null | head -80; gst-inspect-1.0 v4l2src 2>/dev/null | head -80'
write_command gpio.txt sh -c 'gpiodetect 2>/dev/null; gpioinfo 2>/dev/null | head -200; ls -la /sys/class/gpio 2>/dev/null'
write_command ai-runtime.txt sh -c 'hailortcli scan 2>/dev/null; ls -la /dev/hailo* 2>/dev/null; find /opt/beenut/service/models -maxdepth 3 -type f -printf "%p %s bytes\n" 2>/dev/null'
write_command systemd.txt sh -c 'systemctl status beenut-service beenut-kiosk --no-pager 2>/dev/null'
write_command journal-beenut-service.log sh -c 'journalctl -u beenut-service -n 300 --no-pager 2>/dev/null'
write_command journal-beenut-kiosk.log sh -c 'journalctl -u beenut-kiosk -n 300 --no-pager 2>/dev/null'
write_command package.txt sh -c 'dpkg -l | grep -E "beenut|flutter-pi|gstreamer|hailo|onnx" 2>/dev/null'

TAR_PATH="$OUTPUT_DIR/beenut-diagnostics-$STAMP.tar.gz"
tar -C "$WORK_DIR" -czf "$TAR_PATH" diagnostics
rm -rf "$WORK_DIR"

echo "$TAR_PATH"
