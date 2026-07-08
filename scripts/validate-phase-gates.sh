#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build/phase-validation}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUTPUT_DIR/$STAMP"
DEV_ONLY=0
HARDWARE_ONLY=0
SKIP_SLOW=0

usage() {
  cat <<USAGE
Usage: $0 [--dev-only] [--hardware-only] [--skip-slow]

Runs BeeNut phase acceptance checks and writes evidence logs to:
  $OUTPUT_DIR/<timestamp>/

Modes:
  --dev-only       Run workstation checks only.
  --hardware-only  Run field hardware evidence checks only.
  --skip-slow      Skip longer build/test commands.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev-only)
      DEV_ONLY=1
      shift
      ;;
    --hardware-only)
      HARDWARE_ONLY=1
      shift
      ;;
    --skip-slow)
      SKIP_SLOW=1
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

if [[ "$DEV_ONLY" == "1" && "$HARDWARE_ONLY" == "1" ]]; then
  echo "--dev-only and --hardware-only are mutually exclusive" >&2
  exit 2
fi

mkdir -p "$RUN_DIR"

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

write_manifest() {
  python3 - "$RUN_DIR/manifest.json" "$STAMP" <<'PY'
import json
import platform
import sys
from pathlib import Path

path, stamp = Path(sys.argv[1]), sys.argv[2]
path.write_text(json.dumps({
    "schema_version": 1,
    "created_utc": stamp,
    "host": platform.node(),
    "system": platform.platform(),
}, indent=2) + "\n", encoding="utf-8")
PY
}

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

run_step() {
  local name="$1"
  shift
  local log="$RUN_DIR/$name.log"
  local status="pass"
  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
    "$@"
  } >"$log" 2>&1 || status="fail"
  printf '%s\t%s\t%s\n' "$name" "$status" "$log" >>"$RUN_DIR/summary.tsv"
  [[ "$status" == "pass" ]]
}

run_optional() {
  local name="$1"
  shift
  local log="$RUN_DIR/$name.log"
  local status="pass"
  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
    "$@"
  } >"$log" 2>&1 || status="warn"
  printf '%s\t%s\t%s\n' "$name" "$status" "$log" >>"$RUN_DIR/summary.tsv"
}

run_shell_syntax_checks() {
  local scripts=(
    scripts/assemble-package.sh
    scripts/build-debian.sh
    scripts/build-macos.sh
    scripts/build-service.sh
    scripts/create-release-manifest.sh
    scripts/create-release-evidence-set.sh
    scripts/desktop-field-validation.sh
    scripts/gpio-field-test.sh
    scripts/build-pi.sh
    scripts/pi-install-deps.sh
    scripts/pi-field-validation.sh
    scripts/pi-run.sh
    scripts/pi-smoke.sh
    scripts/probe-phase-hardware.sh
    scripts/smoke-backend.sh
    scripts/usb-update-field-validation.sh
    os/build-beenut-image.sh
    packaging/scripts/apply-usb-update.sh
    packaging/scripts/collect-diagnostics.sh
    packaging/scripts/factory-reset.sh
    packaging/scripts/first-boot.sh
    packaging/scripts/wait-for-socket.sh
  )
  run_step shell-syntax bash -n "${scripts[@]}"
}

run_dev_checks() {
  run_shell_syntax_checks
  run_step flutter-analyze flutter analyze
  run_step flutter-test flutter test
  run_step native-service-build cmake --build service/build --target beenutd -j 4
  run_step native-service-tests sh -c 'cmake --build service/build --target service_tests -j 4 && ctest --test-dir service/build --output-on-failure'
  run_step git-diff-check git diff --check
  if [[ "$SKIP_SLOW" != "1" ]]; then
    run_optional backend-smoke scripts/smoke-backend.sh
  fi
}

run_hardware_evidence() {
  local diagnostics_script
  local probe_script
  diagnostics_script="$(find_tool collect-diagnostics.sh || true)"
  probe_script="$(find_tool probe-phase-hardware.sh || true)"
  run_optional system-uname uname -a
  run_optional os-release sh -c 'cat /etc/os-release 2>/dev/null || sw_vers 2>/dev/null || true'
  if [[ -n "$probe_script" ]]; then
    run_optional camera-inventory "$probe_script" camera-inventory
    run_optional gstreamer-inventory "$probe_script" gstreamer-inventory
    run_optional gpio-inventory "$probe_script" gpio-inventory
    run_optional ai-runtime-inventory "$probe_script" ai-runtime-inventory
  else
    run_optional camera-inventory sh -c 'echo "probe-phase-hardware.sh: missing"; exit 1'
    run_optional gstreamer-inventory sh -c 'echo "probe-phase-hardware.sh: missing"; exit 1'
    run_optional gpio-inventory sh -c 'echo "probe-phase-hardware.sh: missing"; exit 1'
    run_optional ai-runtime-inventory sh -c 'echo "probe-phase-hardware.sh: missing"; exit 1'
  fi
  run_optional thermal-sample sh -c 'vcgencmd measure_temp 2>/dev/null; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null || true'
  if [[ -n "$probe_script" ]]; then
    run_optional systemd-units "$probe_script" systemd-units
    run_optional package-inventory "$probe_script" package-inventory
  else
    run_optional systemd-units sh -c 'echo "probe-phase-hardware.sh: missing"; exit 1'
    run_optional package-inventory sh -c 'echo "probe-phase-hardware.sh: missing"; exit 1'
  fi
  if [[ -n "$diagnostics_script" ]]; then
    run_optional diagnostics-bundle sh -c 'OUTPUT_DIR="'"$RUN_DIR"'" "'"$diagnostics_script"'" 2>/dev/null || true'
  else
    run_optional diagnostics-bundle sh -c 'echo "collect-diagnostics.sh: missing"; exit 1'
  fi
  run_optional systemd-restart-policy sh -c 'grep -R "Restart=always" "'"$ROOT_DIR"'/packaging/systemd" "'"$ROOT_DIR"'/systemd" /etc/systemd/system /lib/systemd/system 2>/dev/null | grep -E "beenut-service|beenut-kiosk"'
}

write_summary_json() {
  python3 - "$RUN_DIR/summary.tsv" "$RUN_DIR/summary.json" <<'PY'
import json
import sys
from pathlib import Path

tsv, out = Path(sys.argv[1]), Path(sys.argv[2])
items = []
if tsv.exists():
    for line in tsv.read_text(encoding="utf-8").splitlines():
        name, status, log = line.split("\t", 2)
        items.append({"name": name, "status": status, "log": log})
out.write_text(json.dumps({
    "schema_version": 1,
    "passed": all(item["status"] != "fail" for item in items),
    "items": items,
}, indent=2) + "\n", encoding="utf-8")
PY
}

write_evidence_report() {
  local check_script
  check_script="$(find_tool check-phase-evidence.py)"
  python3 "$check_script" "$RUN_DIR" \
    --output "$RUN_DIR/phase-evidence-report.json" \
    --write-manual-template "$RUN_DIR/manual-evidence.template.json" \
    >"$RUN_DIR/phase-evidence-report.log"
}

cd "$ROOT_DIR"
: >"$RUN_DIR/summary.tsv"
write_manifest

if [[ "$HARDWARE_ONLY" != "1" ]]; then
  run_dev_checks
fi
if [[ "$DEV_ONLY" != "1" ]]; then
  run_hardware_evidence
fi

write_summary_json
write_evidence_report
echo "$RUN_DIR"
