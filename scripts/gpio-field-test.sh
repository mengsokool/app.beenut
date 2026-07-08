#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${BEENUT_CONFIG:-/etc/beenut/config.json}"
OUTPUT_PATH=""
EXERCISE_RELAY=0
RELAY_DELAY="0.2"

usage() {
  cat <<USAGE
Usage: $0 [--config PATH] [--output PATH] [--exercise-relay] [--relay-delay SECONDS]

Validates BeeNut GPIO access on Raspberry Pi / SBC hardware and writes JSON
evidence. By default it only inventories and reads; --exercise-relay toggles the
configured relay pin off/on/off.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_PATH="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    --exercise-relay)
      EXERCISE_RELAY=1
      shift
      ;;
    --relay-delay)
      RELAY_DELAY="${2:-}"
      shift 2
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

if [[ -z "$OUTPUT_PATH" ]]; then
  OUTPUT_PATH="$(pwd)/gpio-field-test.json"
fi
mkdir -p "$(dirname "$OUTPUT_PATH")"

python3 - "$CONFIG_PATH" "$OUTPUT_PATH" "$EXERCISE_RELAY" "$RELAY_DELAY" <<'PY'
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

config_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
exercise_relay = sys.argv[3] == "1"
relay_delay = float(sys.argv[4])

config = {}
if config_path.exists():
    config = json.loads(config_path.read_text(encoding="utf-8"))
gpio = config.get("gpio", {}) if isinstance(config, dict) else {}
backend = str(os.environ.get("BEENUT_GPIO_BACKEND") or gpio.get("backend") or "auto")
chip = str(gpio.get("chip") or "gpiochip0")
tray_pin = int(gpio.get("tray_sensor_pin", 22))
relay_pin = int(gpio.get("relay_pin", 27))
active_low = bool(gpio.get("active_low", True))

commands = {
    "gpiodetect": shutil.which("gpiodetect"),
    "gpioinfo": shutil.which("gpioinfo"),
    "gpioget": shutil.which("gpioget"),
    "gpioset": shutil.which("gpioset"),
}

def run(args, timeout=2.0):
    try:
        completed = subprocess.run(
            args,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return {
            "command": args,
            "exit_code": completed.returncode,
            "stdout": completed.stdout.strip(),
            "stderr": completed.stderr.strip(),
        }
    except Exception as exc:
        return {
            "command": args,
            "exit_code": -1,
            "stdout": "",
            "stderr": str(exc),
        }

def chip_path(name):
    return name if name.startswith("/") else f"/dev/{name}"

steps = []
hardware_available = False
read_ok = False
write_ok = False
backend_used = "none"

if commands["gpiodetect"]:
    result = run([commands["gpiodetect"]])
    steps.append({"name": "gpiodetect", **result})
    hardware_available = result["exit_code"] == 0 and bool(result["stdout"])
else:
    steps.append({"name": "gpiodetect", "exit_code": 127, "stdout": "", "stderr": "missing"})

device_path = chip_path(chip)
if Path(device_path).exists():
    hardware_available = True
    backend_used = "libgpiod"

if hardware_available and commands["gpioget"]:
    result = run([commands["gpioget"], chip, str(tray_pin)])
    steps.append({"name": "read_tray_sensor", "pin": tray_pin, **result})
    read_ok = result["exit_code"] == 0 and result["stdout"] in ("0", "1")
else:
    steps.append({
        "name": "read_tray_sensor",
        "pin": tray_pin,
        "exit_code": 127,
        "stdout": "",
        "stderr": "gpioget missing or gpiochip unavailable",
    })

if exercise_relay:
    if hardware_available and commands["gpioset"]:
        raw_off = "1" if active_low else "0"
        raw_on = "0" if active_low else "1"
        sequence_ok = True
        for index, raw in enumerate((raw_off, raw_on, raw_off)):
            result = run([commands["gpioset"], chip, f"{relay_pin}={raw}"])
            result.update({"name": "write_relay", "pin": relay_pin, "raw": raw, "sequence": index})
            steps.append(result)
            sequence_ok = sequence_ok and result["exit_code"] == 0
            time.sleep(relay_delay)
        write_ok = sequence_ok
    else:
        steps.append({
            "name": "write_relay",
            "pin": relay_pin,
            "exit_code": 127,
            "stdout": "",
            "stderr": "gpioset missing or gpiochip unavailable",
        })
else:
    write_ok = None

sysfs_available = Path("/sys/class/gpio").exists()
if backend_used == "none" and sysfs_available:
    backend_used = "sysfs"
    hardware_available = True

passed = hardware_available and read_ok and (write_ok is not False)
report = {
    "schema_version": 1,
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "config_path": str(config_path),
    "backend_requested": backend,
    "backend_used": backend_used,
    "chip": chip,
    "chip_path": device_path,
    "tray_sensor_pin": tray_pin,
    "relay_pin": relay_pin,
    "active_low": active_low,
    "exercise_relay": exercise_relay,
    "hardware_available": hardware_available,
    "read_ok": read_ok,
    "write_ok": write_ok,
    "passed": passed,
    "commands": commands,
    "steps": steps,
}
output_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(output_path)
raise SystemExit(0 if passed else 1)
PY
