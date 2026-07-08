#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR=""
RUN_HARDWARE_GATES=1
CONFIRM_BOOT_PREVIEW=0
CONFIRM_BOOT_BRANDING=0
CONFIRM_POWER_BUTTON=0
CONFIRM_FACTORY_RESET=0
CONFIRM_THERMAL_SOAK=0
CONFIRM_USB_UPDATE=0
CONFIRM_PERMISSION_RETRY=0
EXERCISE_GPIO_RELAY=0
EXERCISE_FACTORY_RESET=0
EXERCISE_FIRST_BOOT=0
EXERCISE_POWEROFF_DRY_RUN=0
EXERCISE_SYSTEMD_CRASH=0
OPERATOR="${OPERATOR:-}"
CONFIG_PATH="${BEENUT_CONFIG:-/etc/beenut/config.json}"
DEVICE_PATH="${DEVICE_PATH:-/etc/beenut/device.json}"
FIRST_BOOT_LOG_PATH="${LOG_PATH:-/var/log/beenut/first-boot.log}"
SOCKET_PATH="${BEENUTD_SOCKET:-/tmp/beenutd.sock}"

find_tool() {
  local name="$1"
  local candidates=(
    "$ROOT_DIR/scripts/$name"
    "$ROOT_DIR/packaging/scripts/$name"
    "/opt/beenut/scripts/$name"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" || -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

usage() {
  cat <<USAGE
Usage: $0 [options]

Collects Raspberry Pi / SBC field evidence and writes manual-evidence.json into
the validation run directory.

Options:
  --run-dir DIR                  Use an existing build/phase-validation run.
  --skip-hardware-gates          Do not run validate-phase-gates.sh --hardware-only.
  --operator NAME                Operator name for QA notes.
  --confirm-boot-preview         Operator confirms boot-to-kiosk live preview.
  --confirm-boot-branding        Operator confirms BeeNut boot branding is visible.
  --confirm-power-button         Operator confirms appliance power button shutdown.
  --confirm-factory-reset        Operator confirms factory reset restored defaults.
  --confirm-thermal-soak         Operator confirms sustained thermal soak behavior.
  --confirm-usb-update           Operator confirms offline USB update and rollback test.
  --confirm-permission-retry     Operator confirms permission denial/retry UX.
  --exercise-gpio-relay          Toggle the configured relay pin during GPIO validation.
  --exercise-first-boot          Run first-boot.sh and capture device metadata/log evidence.
  --exercise-factory-reset       Run factory-reset.sh --no-restart and capture reset evidence.
  --exercise-poweroff-dry-run    Send shutdown over the backend socket; requires BEENUT_POWEROFF_COMMAND dry-run override.
  --exercise-systemd-crash       Kill beenut-service and verify systemd restarts it.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)
      RUN_DIR="${2:-}"
      shift 2
      ;;
    --skip-hardware-gates)
      RUN_HARDWARE_GATES=0
      shift
      ;;
    --operator)
      OPERATOR="${2:-}"
      shift 2
      ;;
    --confirm-boot-preview)
      CONFIRM_BOOT_PREVIEW=1
      shift
      ;;
    --confirm-boot-branding)
      CONFIRM_BOOT_BRANDING=1
      shift
      ;;
    --confirm-power-button)
      CONFIRM_POWER_BUTTON=1
      shift
      ;;
    --confirm-factory-reset)
      CONFIRM_FACTORY_RESET=1
      shift
      ;;
    --confirm-thermal-soak)
      CONFIRM_THERMAL_SOAK=1
      shift
      ;;
    --confirm-usb-update)
      CONFIRM_USB_UPDATE=1
      shift
      ;;
    --confirm-permission-retry)
      CONFIRM_PERMISSION_RETRY=1
      shift
      ;;
    --exercise-gpio-relay)
      EXERCISE_GPIO_RELAY=1
      shift
      ;;
    --exercise-first-boot)
      EXERCISE_FIRST_BOOT=1
      shift
      ;;
    --exercise-factory-reset)
      EXERCISE_FACTORY_RESET=1
      shift
      ;;
    --exercise-poweroff-dry-run)
      EXERCISE_POWEROFF_DRY_RUN=1
      shift
      ;;
    --exercise-systemd-crash)
      EXERCISE_SYSTEMD_CRASH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$RUN_HARDWARE_GATES" == "1" ]]; then
  if [[ -n "$RUN_DIR" ]]; then
    echo "--run-dir cannot be combined with hardware gate execution" >&2
    exit 2
  fi
  validate_script="$(find_tool validate-phase-gates.sh)"
  RUN_DIR="$("$validate_script" --hardware-only | tail -n 1)"
fi

if [[ -z "$RUN_DIR" ]]; then
  echo "No run directory provided. Use --run-dir or allow hardware gates to run." >&2
  exit 2
fi

RUN_DIR="$(cd "$RUN_DIR" && pwd)"
EVIDENCE_DIR="$RUN_DIR/evidence"
LOG_DIR="$RUN_DIR/logs"
EXTRACT_DIR="$RUN_DIR/diagnostics-extracted"
CANDIDATES_TSV="$RUN_DIR/manual-evidence.candidates.tsv"
mkdir -p "$EVIDENCE_DIR" "$LOG_DIR" "$EXTRACT_DIR"
: >"$CANDIDATES_TSV"

stamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

record_evidence() {
  local item="$1"
  local cover="$2"
  local relpath="$3"
  local notes="$4"
  printf '%s\t%s\t%s\t%s\n' "$item" "$cover" "$relpath" "$notes" >>"$CANDIDATES_TSV"
}

usable_file() {
  local path="$1"
  [[ -f "$path" && -s "$path" ]] || return 1
  if head -n 1 "$path" | grep -q '^missing:'; then
    return 1
  fi
}

copy_usable() {
  local source="$1"
  local reltarget="$2"
  local target="$RUN_DIR/$reltarget"
  usable_file "$source" || return 1
  mkdir -p "$(dirname "$target")"
  if [[ "$(cd "$(dirname "$source")" && pwd)/$(basename "$source")" == "$(cd "$(dirname "$target")" && pwd)/$(basename "$target")" ]]; then
    return 0
  fi
  cp "$source" "$target"
}

redact_json_file() {
  local source="$1"
  local reltarget="$2"
  local target="$RUN_DIR/$reltarget"
  usable_file "$source" || return 1
  mkdir -p "$(dirname "$target")"
  python3 - "$source" "$target" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
data = json.loads(source.read_text(encoding="utf-8"))
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
        parts = value.split("/", 3)
        return "/Users/<redacted>" + (f"/{parts[3]}" if len(parts) > 3 else "")
    return value

target.write_text(json.dumps(redact(data), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

write_note() {
  local reltarget="$1"
  local title="$2"
  local target="$RUN_DIR/$reltarget"
  mkdir -p "$(dirname "$target")"
  {
    echo "$title"
    echo "captured_at=$(stamp)"
    echo "operator=${OPERATOR:-unknown}"
    echo "run_dir=$RUN_DIR"
  } >"$target"
}

diagnostics_tar=""
if diagnostics_script="$(find_tool collect-diagnostics.sh)"; then
  diagnostics_tar="$(OUTPUT_DIR="$LOG_DIR" "$diagnostics_script" 2>"$LOG_DIR/collect-diagnostics.err" || true)"
  if [[ -f "$diagnostics_tar" ]]; then
    tar -C "$EXTRACT_DIR" -xzf "$diagnostics_tar"
  fi
fi

DIAG_DIR="$EXTRACT_DIR/diagnostics"
if [[ ! -d "$DIAG_DIR" ]]; then
  DIAG_DIR=""
fi

if [[ -n "$DIAG_DIR" ]]; then
  if copy_usable "$DIAG_DIR/capabilities.json" "evidence/capabilities.json"; then
    record_evidence "M15 camera formats" "capabilities.json or backend capability snapshot" "evidence/capabilities.json" "Backend capabilities captured from diagnostics bundle."
    record_evidence "Capability-driven platform model" "backend capabilities.json for the target class" "evidence/capabilities.json" "Backend capabilities captured from diagnostics bundle."
  fi
  if copy_usable "$DIAG_DIR/diagnostic-events.jsonl" "evidence/backend-diagnostic-events.jsonl"; then
    if grep -qi '"gpio"\|gpio' "$RUN_DIR/evidence/backend-diagnostic-events.jsonl"; then
      record_evidence "N8 libgpiod support" "backend GPIO ready/blocked diagnostic event" "evidence/backend-diagnostic-events.jsonl" "Backend GPIO diagnostic event captured from service socket."
    fi
    if grep -qi 'shutdown\|power' "$RUN_DIR/evidence/backend-diagnostic-events.jsonl"; then
      record_evidence "Power button shutdown" "backend shutdown event" "evidence/backend-diagnostic-events.jsonl" "Backend shutdown/power event captured from service socket."
    fi
  fi
  copy_usable "$DIAG_DIR/journal-beenut-service.log" "logs/journal-beenut-service.log" || true
  copy_usable "$DIAG_DIR/journal-beenut-kiosk.log" "logs/journal-beenut-kiosk.log" || true
  copy_usable "$DIAG_DIR/temperature.txt" "logs/thermal-sample.log" || true
  copy_usable "$DIAG_DIR/config.redacted.json" "evidence/config-after-validation.redacted.json" || true
fi

copy_usable "$RUN_DIR/gpio-inventory.log" "logs/gpio-inventory.log" || true
copy_usable "$RUN_DIR/systemd-units.log" "logs/systemd-units.log" || true
copy_usable "$RUN_DIR/thermal-sample.log" "logs/thermal-sample.log" || true
copy_usable "$RUN_DIR/package-inventory.log" "logs/package-inventory.log" || true

if copy_usable "/etc/issue" "evidence/boot-branding-issue.txt"; then
  if grep -qi 'BeeNut' "$RUN_DIR/evidence/boot-branding-issue.txt"; then
    record_evidence "Boot branding" "photo or console capture of BeeNut boot branding" "evidence/boot-branding-issue.txt" "BeeNut TTY issue branding captured from appliance."
  fi
fi
if copy_usable "/etc/motd" "evidence/boot-branding-motd.txt"; then
  if grep -qi 'BeeNut' "$RUN_DIR/evidence/boot-branding-motd.txt"; then
    record_evidence "Boot branding" "photo or console capture of BeeNut boot branding" "evidence/boot-branding-motd.txt" "BeeNut MOTD branding captured from appliance."
  fi
fi

if gpio_test_script="$(find_tool gpio-field-test.sh)"; then
  gpio_args=(--output "$RUN_DIR/evidence/gpio-field-test.json")
  if [[ "$EXERCISE_GPIO_RELAY" == "1" ]]; then
    gpio_args+=(--exercise-relay)
  fi
  "$gpio_test_script" "${gpio_args[@]}" >"$LOG_DIR/gpio-field-test.out" 2>"$LOG_DIR/gpio-field-test.err" || true
  if copy_usable "$RUN_DIR/evidence/gpio-field-test.json" "evidence/gpio-field-test.json"; then
    if python3 - "$RUN_DIR/evidence/gpio-field-test.json" <<'PY'
import json
import sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
raise SystemExit(0 if data.get("passed") else 1)
PY
    then
      record_evidence "N8 libgpiod support" "backend GPIO ready/blocked diagnostic event" "evidence/gpio-field-test.json" "GPIO field test passed against configured chip and pins."
    fi
  fi
fi

if copy_usable "$DEVICE_PATH" "evidence/device.json"; then
  record_evidence "First boot service" "/etc/beenut/device.json after first boot" "evidence/device.json" "Device metadata captured after first boot service."
fi

if copy_usable "/etc/beenut/image-manifest.json" "evidence/image-manifest.json"; then
  record_evidence "Image builder skeleton" "image manifest from full bootable image build" "evidence/image-manifest.json" "Image manifest captured from installed appliance."
fi

if copy_usable "$FIRST_BOOT_LOG_PATH" "logs/first-boot.log"; then
  record_evidence "First boot service" "/etc/beenut/device.json after first boot" "logs/first-boot.log" "First boot service log captured from appliance."
fi

if command -v journalctl >/dev/null 2>&1; then
  journalctl -u beenut-kiosk -n 240 --no-pager >"$RUN_DIR/logs/journal-beenut-kiosk.log" 2>/dev/null || true
  journalctl -u beenut-service -n 240 --no-pager >"$RUN_DIR/logs/journal-beenut-service.log" 2>/dev/null || true
fi

if usable_file "$RUN_DIR/logs/journal-beenut-kiosk.log"; then
  record_evidence "Auto-start service/kiosk" "journal-beenut-kiosk.log after reboot" "logs/journal-beenut-kiosk.log" "Kiosk journal captured from appliance."
fi

if [[ -f "$RUN_DIR/logs/thermal-sample.log" ]]; then
  record_evidence "Thermal throttling" "backend thermal status metrics during sustained preview/inference" "logs/thermal-sample.log" "Thermal sample captured during field validation."
fi

if copy_usable "/var/log/beenut/update-result.log" "logs/update-result.log"; then
  record_evidence "USB offline update" "offline update log" "logs/update-result.log" "Offline update result log captured from appliance."
  record_evidence "USB offline update" "post-reboot package version" "logs/package-inventory.log" "Package inventory captured after update validation."
fi

if [[ "$CONFIRM_BOOT_PREVIEW" == "1" ]]; then
  write_note "evidence/boot-preview-qa-note.txt" "Operator confirmed boot-to-kiosk live preview."
  record_evidence "Pi/SBC primary path" "boot-to-kiosk preview observation" "evidence/boot-preview-qa-note.txt" "Operator confirmed live preview after boot."
fi

if [[ "$CONFIRM_BOOT_BRANDING" == "1" ]]; then
  write_note "evidence/boot-branding-qa-note.txt" "Operator confirmed BeeNut boot branding."
  record_evidence "Boot branding" "photo or console capture of BeeNut boot branding" "evidence/boot-branding-qa-note.txt" "Operator confirmed boot branding."
fi

if [[ "$CONFIRM_POWER_BUTTON" == "1" ]]; then
  write_note "evidence/power-button-qa-note.txt" "Operator confirmed power button shutdown."
  record_evidence "Power button shutdown" "system journal shutdown evidence" "evidence/power-button-qa-note.txt" "Operator confirmed appliance shutdown through configured button path."
fi

if [[ "$CONFIRM_FACTORY_RESET" == "1" ]]; then
  write_note "evidence/factory-reset-qa-note.txt" "Operator confirmed factory reset."
  record_evidence "Factory reset" "factory reset log" "evidence/factory-reset-qa-note.txt" "Operator confirmed reset command completed."
  record_evidence "Factory reset" "post-reset config snapshot" "evidence/config-after-validation.redacted.json" "Post-reset config snapshot captured from diagnostics."
fi

if [[ "$EXERCISE_FIRST_BOOT" == "1" ]]; then
  first_boot_log="$RUN_DIR/logs/first-boot-exercise.log"
  if first_boot_script="$(find_tool first-boot.sh)"; then
    "$first_boot_script" >"$first_boot_log" 2>&1 || true
  else
    echo "first-boot.sh: missing" >"$first_boot_log"
  fi
  if grep -q 'First boot complete\|First boot already completed' "$first_boot_log"; then
    cp "$first_boot_log" "$RUN_DIR/logs/first-boot.log"
    record_evidence "First boot service" "/etc/beenut/device.json after first boot" "logs/first-boot.log" "first-boot.sh completed or was already completed on the appliance."
    if copy_usable "$DEVICE_PATH" "evidence/device.json"; then
      record_evidence "First boot service" "/etc/beenut/device.json after first boot" "evidence/device.json" "Device metadata captured after first boot exercise."
    fi
  fi
fi

if [[ "$EXERCISE_FACTORY_RESET" == "1" ]]; then
  reset_log="$RUN_DIR/logs/factory-reset.log"
  if reset_script="$(find_tool factory-reset.sh)"; then
    "$reset_script" --no-restart >"$reset_log" 2>&1 || true
  else
    echo "factory-reset.sh: missing" >"$reset_log"
  fi
  if grep -q 'Factory reset complete' "$reset_log"; then
    record_evidence "Factory reset" "factory reset log" "logs/factory-reset.log" "factory-reset.sh completed on the appliance."
    if redact_json_file "$CONFIG_PATH" "evidence/config-after-validation.redacted.json"; then
      record_evidence "Factory reset" "post-reset config snapshot" "evidence/config-after-validation.redacted.json" "Post-reset config snapshot captured after factory reset."
    fi
  fi
fi

if [[ "$EXERCISE_POWEROFF_DRY_RUN" == "1" ]]; then
  poweroff_log="$RUN_DIR/logs/poweroff-dry-run-event.jsonl"
  python3 - "$SOCKET_PATH" "$poweroff_log" <<'PY' || true
import json
import socket
import sys
import time
from pathlib import Path

socket_path = sys.argv[1]
out = Path(sys.argv[2])
deadline = time.monotonic() + 8
out.parent.mkdir(parents=True, exist_ok=True)

try:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(2)
        sock.connect(socket_path)
        sock.sendall(b'{"type":"shutdown"}\n')
        buffer = b""
        lines = []
        while time.monotonic() < deadline:
            chunk = sock.recv(4096)
            if not chunk:
                break
            buffer += chunk
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                if not line:
                    continue
                text = line.decode("utf-8", errors="replace")
                lines.append(text)
                out.write_text("\n".join(lines) + "\n", encoding="utf-8")
                try:
                    message = json.loads(line)
                except json.JSONDecodeError:
                    continue
                event = message.get("event", {})
                if message.get("type") == "diagnosticEvent" and event.get("target") == "shutdown":
                    raise SystemExit(0 if event.get("ok") else 1)
except OSError as exc:
    out.write_text(json.dumps({
        "type": "error",
        "target": "shutdown",
        "ok": False,
        "detail": str(exc),
    }) + "\n", encoding="utf-8")
raise SystemExit(1)
PY
  if grep -q '"target":"shutdown"' "$poweroff_log" 2>/dev/null && grep -q '"ok":true' "$poweroff_log" 2>/dev/null; then
    record_evidence "Power button shutdown" "backend shutdown event" "logs/poweroff-dry-run-event.jsonl" "Backend shutdown request path accepted with BEENUT_POWEROFF_COMMAND dry-run override."
  fi
fi

if [[ "$CONFIRM_THERMAL_SOAK" == "1" ]]; then
  write_note "evidence/thermal-soak-qa-note.txt" "Operator confirmed sustained thermal soak."
  record_evidence "Thermal throttling" "backend thermal status metrics during sustained preview/inference" "evidence/thermal-soak-qa-note.txt" "Operator confirmed sustained preview/inference thermal behavior."
fi

if [[ "$CONFIRM_USB_UPDATE" == "1" ]]; then
  write_note "evidence/usb-update-qa-note.txt" "Operator confirmed offline USB update and rollback."
  record_evidence "USB offline update" "rollback test evidence" "evidence/usb-update-qa-note.txt" "Operator confirmed rollback behavior."
fi

if [[ "$CONFIRM_PERMISSION_RETRY" == "1" ]]; then
  write_note "evidence/permission-retry-qa-note.txt" "Operator confirmed permission denial/retry UX."
  record_evidence "Permission denied UX" "denial/retry screen recording or QA note" "evidence/permission-retry-qa-note.txt" "Operator confirmed denial/retry recovery."
  record_evidence "Permission denied UX" "app logs without crash" "logs/journal-beenut-kiosk.log" "Kiosk logs captured after permission retry validation."
fi

if [[ "$EXERCISE_SYSTEMD_CRASH" == "1" ]]; then
  crash_log="$RUN_DIR/logs/systemd-crash-restart.log"
  {
    echo "captured_at=$(stamp)"
    echo "operator=${OPERATOR:-unknown}"
    if command -v systemctl >/dev/null 2>&1; then
      before_pid="$(systemctl show -p MainPID --value beenut-service.service 2>/dev/null || true)"
      echo "before_main_pid=$before_pid"
      if [[ -n "$before_pid" && "$before_pid" != "0" ]]; then
        kill -9 "$before_pid" 2>/dev/null || true
      else
        systemctl kill -s KILL beenut-service.service 2>/dev/null || true
      fi
      sleep 4
      systemctl status beenut-service.service --no-pager 2>&1 || true
      after_pid="$(systemctl show -p MainPID --value beenut-service.service 2>/dev/null || true)"
      active_state="$(systemctl show -p ActiveState --value beenut-service.service 2>/dev/null || true)"
      echo "after_main_pid=$after_pid"
      echo "active_state=$active_state"
      journalctl -u beenut-service -n 120 --no-pager 2>&1 || true
    else
      echo "systemctl: missing"
    fi
  } >"$crash_log" 2>&1
  if grep -q 'active_state=active' "$crash_log"; then
    record_evidence "systemd crash restart" "journal evidence after forced service crash" "logs/systemd-crash-restart.log" "beenut-service was killed and systemd returned it to active state."
  fi
fi

python3 - "$RUN_DIR/manual-evidence.json" "$CANDIDATES_TSV" "$OPERATOR" <<'PY'
import csv
import json
import sys
from collections import OrderedDict
from datetime import datetime, timezone
from pathlib import Path

out = Path(sys.argv[1])
tsv = Path(sys.argv[2])
operator = sys.argv[3] or "unknown"
entries = []
seen = set()
if tsv.exists():
    with tsv.open("r", encoding="utf-8", newline="") as handle:
        for item, cover, relpath, notes in csv.reader(handle, delimiter="\t"):
            if not (out.parent / relpath).exists():
                continue
            key = (item, cover, relpath)
            if key in seen:
                continue
            seen.add(key)
            entries.append(OrderedDict([
                ("item", item),
                ("covers", [cover]),
                ("files", [relpath]),
                ("notes", notes),
            ]))

manifest = OrderedDict([
    ("schema_version", 1),
    ("target", "raspberry-pi-field"),
    ("captured_at", datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
    ("captured_by", operator),
    ("evidence", entries),
])
out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

check_script="$(find_tool check-phase-evidence.py)"
python3 "$check_script" "$RUN_DIR" \
  --output "$RUN_DIR/phase-evidence-report.json" \
  --write-manual-template "$RUN_DIR/manual-evidence.template.json" \
  >"$RUN_DIR/phase-evidence-report.log"

echo "$RUN_DIR"
