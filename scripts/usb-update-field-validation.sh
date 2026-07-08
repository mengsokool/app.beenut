#!/usr/bin/env bash
set -euo pipefail

RUN_DIR=""
PACKAGE_PATH=""
OPERATOR="${OPERATOR:-}"
CONFIRM_INSTALL=0
CONFIRM_ROLLBACK=0
NO_RESTART=0
HEALTH_TIMEOUT=20

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<USAGE
Usage: $0 --run-dir DIR --package PATH [options]

Builds a USB update fixture, runs apply-usb-update.sh --dry-run, and records
field evidence for the offline update checklist.

Options:
  --run-dir DIR           Existing build/phase-validation run directory.
  --package PATH          .deb package to place in the USB update fixture.
  --operator NAME         Operator name for QA notes.
  --confirm-install       Operator confirms install/reboot/package version.
  --confirm-rollback      Operator confirms rollback behavior was tested.
  --no-restart            Pass --no-restart to apply-usb-update.sh for dry-run/install.
  --health-timeout SEC    Health timeout for real install validation.
USAGE
}

find_tool() {
  local name="$1"
  local candidates=(
    "$ROOT_DIR/packaging/scripts/$name"
    "$ROOT_DIR/scripts/$name"
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

write_sha256sum() {
  local target="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$target"
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$target"
  else
    echo "Neither sha256sum nor shasum is available." >&2
    return 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)
      RUN_DIR="${2:-}"
      shift 2
      ;;
    --package)
      PACKAGE_PATH="${2:-}"
      shift 2
      ;;
    --operator)
      OPERATOR="${2:-}"
      shift 2
      ;;
    --confirm-install)
      CONFIRM_INSTALL=1
      shift
      ;;
    --confirm-rollback)
      CONFIRM_ROLLBACK=1
      shift
      ;;
    --no-restart)
      NO_RESTART=1
      shift
      ;;
    --health-timeout)
      HEALTH_TIMEOUT="${2:-}"
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

if [[ -z "$RUN_DIR" || -z "$PACKAGE_PATH" ]]; then
  usage >&2
  exit 2
fi

RUN_DIR="$(cd "$RUN_DIR" && pwd)"
PACKAGE_PATH="$(cd "$(dirname "$PACKAGE_PATH")" && pwd)/$(basename "$PACKAGE_PATH")"
if [[ ! -f "$PACKAGE_PATH" ]]; then
  echo "Package not found: $PACKAGE_PATH" >&2
  exit 1
fi

UPDATE_DIR="$RUN_DIR/usb-update-fixture"
LOG_DIR="$RUN_DIR/logs"
EVIDENCE_DIR="$RUN_DIR/evidence"
CANDIDATES_TSV="$RUN_DIR/manual-evidence.usb-update.tsv"
mkdir -p "$UPDATE_DIR/packages" "$LOG_DIR" "$EVIDENCE_DIR"
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

write_note() {
  local reltarget="$1"
  local title="$2"
  local target="$RUN_DIR/$reltarget"
  mkdir -p "$(dirname "$target")"
  {
    echo "$title"
    echo "captured_at=$(stamp)"
    echo "operator=${OPERATOR:-unknown}"
    echo "package=$(basename "$PACKAGE_PATH")"
    echo "run_dir=$RUN_DIR"
  } >"$target"
}

cp "$PACKAGE_PATH" "$UPDATE_DIR/packages/$(basename "$PACKAGE_PATH")"
cat >"$UPDATE_DIR/manifest.json" <<JSON
{
  "schema_version": 1,
  "package": "packages/$(basename "$PACKAGE_PATH")",
  "created_at": "$(stamp)"
}
JSON
(cd "$UPDATE_DIR" && write_sha256sum "packages/$(basename "$PACKAGE_PATH")" > checksums.sha256)

if ! apply_script="$(find_tool apply-usb-update.sh)"; then
  echo "Could not find apply-usb-update.sh in packaging/scripts, scripts, or /opt/beenut/scripts." >&2
  exit 1
fi
common_args=(--health-timeout "$HEALTH_TIMEOUT")
if [[ "$NO_RESTART" == "1" ]]; then
  common_args+=(--no-restart)
fi

RESULT_LOG="$LOG_DIR/usb-update-dry-run.log" "$apply_script" --dry-run "${common_args[@]}" "$UPDATE_DIR" >"$LOG_DIR/usb-update-dry-run.out" 2>"$LOG_DIR/usb-update-dry-run.err"
cp "$LOG_DIR/usb-update-dry-run.log" "$LOG_DIR/update-result.log"
record_evidence "USB offline update" "offline update log" "logs/update-result.log" "USB update dry-run verified manifest, checksum, and package candidate."

{
  echo "captured_at=$(stamp)"
  if command -v dpkg >/dev/null 2>&1; then
    dpkg -I "$PACKAGE_PATH" 2>/dev/null || true
    dpkg -l | grep -E "beenut|flutter-pi|gstreamer|hailo|onnx" || true
  else
    echo "dpkg: missing"
    echo "package=$(basename "$PACKAGE_PATH")"
  fi
} >"$LOG_DIR/package-version-after-update.log"

if [[ "$CONFIRM_INSTALL" == "1" ]]; then
  write_note "evidence/usb-update-install-qa-note.txt" "Operator confirmed offline USB install and post-reboot package version."
  record_evidence "USB offline update" "post-reboot package version" "logs/package-version-after-update.log" "Package version evidence captured after operator-confirmed update."
fi

if [[ "$CONFIRM_ROLLBACK" == "1" ]]; then
  write_note "evidence/usb-update-rollback-qa-note.txt" "Operator confirmed USB update rollback behavior."
  record_evidence "USB offline update" "rollback test evidence" "evidence/usb-update-rollback-qa-note.txt" "Operator confirmed rollback after failed update health check."
fi

python3 - "$RUN_DIR/manual-evidence.usb-update.json" "$CANDIDATES_TSV" "$OPERATOR" <<'PY'
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
    ("target", "usb-update-field"),
    ("captured_at", datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
    ("captured_by", operator),
    ("evidence", entries),
])
out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

echo "$RUN_DIR/manual-evidence.usb-update.json"
