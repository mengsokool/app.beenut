#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$ROOT_DIR/release-evidence.json"
RELEASE="beenut-release"
INCLUDE_DECISIONS=1
STRICT=0
RUNS=()
MANUAL=()

usage() {
  cat <<USAGE
Usage: $0 [options] RUN_DIR...

Creates a release-evidence.json file for scripts/check-phase-evidence.py from
validation run directories and their manual evidence manifests.

Options:
  --output PATH             Output evidence set path. Default: release-evidence.json
  --release NAME            Release name written into the evidence set.
  --manual-evidence PATH    Extra manual evidence manifest to include.
  --no-decision-records     Do not include docs/manual-evidence.decision-records.json.
  --strict                  Run check-phase-evidence.py --strict after writing.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --release)
      RELEASE="${2:-}"
      shift 2
      ;;
    --manual-evidence)
      MANUAL+=("${2:-}")
      shift 2
      ;;
    --no-decision-records)
      INCLUDE_DECISIONS=0
      shift
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      RUNS+=("$1")
      shift
      ;;
  esac
done

if [[ "${#RUNS[@]}" == "0" ]]; then
  usage >&2
  exit 2
fi

OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"

if [[ "$INCLUDE_DECISIONS" == "1" ]]; then
  MANUAL+=("$ROOT_DIR/docs/manual-evidence.decision-records.json")
fi

for run in "${RUNS[@]}"; do
  if [[ ! -d "$run" ]]; then
    echo "Run directory not found: $run" >&2
    exit 1
  fi
  if [[ ! -f "$run/summary.json" ]]; then
    echo "Run directory has no summary.json: $run" >&2
    exit 1
  fi
  for manifest in \
    "$run/manual-evidence.json" \
    "$run/manual-evidence.desktop.json" \
    "$run/manual-evidence.usb-update.json"
  do
    if [[ -f "$manifest" ]]; then
      MANUAL+=("$manifest")
    fi
  done
done

for manifest in "${MANUAL[@]}"; do
  if [[ ! -f "$manifest" ]]; then
    echo "Manual evidence manifest not found: $manifest" >&2
    exit 1
  fi
done

python3 - "$ROOT_DIR" "$OUTPUT" "$RELEASE" "${RUNS[@]}" -- "${MANUAL[@]}" <<'PY'
import json
import os
import sys
from collections import OrderedDict
from pathlib import Path

root = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
release = sys.argv[3]
separator = sys.argv.index("--")
runs = [Path(value).resolve() for value in sys.argv[4:separator]]
manual = [Path(value).resolve() for value in sys.argv[separator + 1:]]

def rel(path: Path) -> str:
    try:
        return os.path.relpath(path, output.parent)
    except ValueError:
        return str(path)

data = OrderedDict([
    ("schema_version", 1),
    ("release", release),
    ("runs", [rel(path) for path in runs]),
    ("manual_evidence", [rel(path) for path in manual]),
])
output.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

echo "$OUTPUT"

if [[ "$STRICT" == "1" ]]; then
  python3 "$ROOT_DIR/scripts/check-phase-evidence.py" --evidence-set "$OUTPUT" --strict
fi
