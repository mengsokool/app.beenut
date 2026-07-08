#!/usr/bin/env bash
set -euo pipefail

RUN_DIR=""
OPERATOR="${OPERATOR:-}"
CONFIRM_PERMISSION_RETRY=0
CONFIRM_CAMERA_RELEASE=0

usage() {
  cat <<USAGE
Usage: $0 --run-dir DIR [options]

Collects desktop field evidence for packaged macOS/Linux permission and camera
lifecycle checks.

Options:
  --run-dir DIR                  Existing build/phase-validation run directory.
  --operator NAME                Operator name for QA notes.
  --confirm-permission-retry     Operator confirms deny/retry/grant recovery.
  --confirm-camera-release       Operator confirms camera is released after app close/reopen.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)
      RUN_DIR="${2:-}"
      shift 2
      ;;
    --operator)
      OPERATOR="${2:-}"
      shift 2
      ;;
    --confirm-permission-retry)
      CONFIRM_PERMISSION_RETRY=1
      shift
      ;;
    --confirm-camera-release)
      CONFIRM_CAMERA_RELEASE=1
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

if [[ -z "$RUN_DIR" ]]; then
  usage >&2
  exit 2
fi

RUN_DIR="$(cd "$RUN_DIR" && pwd)"
EVIDENCE_DIR="$RUN_DIR/evidence"
LOG_DIR="$RUN_DIR/logs"
CANDIDATES_TSV="$RUN_DIR/manual-evidence.desktop.tsv"
mkdir -p "$EVIDENCE_DIR" "$LOG_DIR"
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
    echo "run_dir=$RUN_DIR"
    echo "platform=$(uname -a 2>/dev/null || true)"
  } >"$target"
}

{
  echo "captured_at=$(stamp)"
  ps -axo pid,ppid,user,%cpu,%mem,command 2>/dev/null | grep -E "beenut|flutter|BeeNut" | grep -v grep || true
  if command -v lsof >/dev/null 2>&1; then
    lsof 2>/dev/null | grep -E "AVCapture|AppleCamera|/dev/video|beenut|flutter" | head -200 || true
  fi
} >"$LOG_DIR/desktop-camera-lifecycle.log"

if [[ "$CONFIRM_PERMISSION_RETRY" == "1" ]]; then
  write_note "evidence/desktop-permission-retry-qa-note.txt" "Operator confirmed desktop permission denial/retry recovery."
  record_evidence "Permission denied UX" "denial/retry screen recording or QA note" "evidence/desktop-permission-retry-qa-note.txt" "Desktop packaged app recovered after deny/retry/grant flow."
  record_evidence "Permission denied UX" "app logs without crash" "logs/desktop-camera-lifecycle.log" "Desktop lifecycle log captured after permission retry flow."
fi

if [[ "$CONFIRM_CAMERA_RELEASE" == "1" ]]; then
  write_note "evidence/desktop-camera-release-qa-note.txt" "Operator confirmed camera release after app close and reopen."
  record_evidence "Desktop fallback behavior" "camera permission denial/retry observation" "evidence/desktop-permission-retry-qa-note.txt" "Desktop permission retry observation recorded."
  record_evidence "Desktop fallback behavior" "camera handle released after app close" "evidence/desktop-camera-release-qa-note.txt" "Operator confirmed camera handle release after closing the packaged app."
fi

python3 - "$RUN_DIR/manual-evidence.desktop.json" "$CANDIDATES_TSV" "$OPERATOR" <<'PY'
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
    ("target", "desktop-field"),
    ("captured_at", datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
    ("captured_by", operator),
    ("evidence", entries),
])
out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

echo "$RUN_DIR/manual-evidence.desktop.json"
