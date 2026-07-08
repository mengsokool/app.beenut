#!/usr/bin/env bash
set -euo pipefail

VERSION="${BEENUT_VERSION:-}"
OUTPUT_DIR="${OUTPUT_DIR:-build/release}"
CHANNEL="${BEENUT_CHANNEL:-stable}"

usage() {
  cat <<USAGE
Usage: BEENUT_VERSION=0.3.0 $0 artifact...

Creates:
  build/release/beenut-release-VERSION.json
  build/release/checksums.sha256
USAGE
}

if [[ -z "$VERSION" || "$#" -eq 0 ]]; then
  usage >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"
CHECKSUMS_PATH="$OUTPUT_DIR/checksums.sha256"
MANIFEST_PATH="$OUTPUT_DIR/beenut-release-$VERSION.json"
: >"$CHECKSUMS_PATH"

artifact_args=()
for artifact in "$@"; do
  if [[ ! -f "$artifact" ]]; then
    echo "Artifact not found: $artifact" >&2
    exit 1
  fi
  checksum="$(sha256sum "$artifact" | awk '{print $1}')"
  printf '%s  %s\n' "$checksum" "$(basename "$artifact")" >>"$CHECKSUMS_PATH"
  artifact_args+=("$artifact")
done

python3 - "$MANIFEST_PATH" "$VERSION" "$CHANNEL" "$CHECKSUMS_PATH" "${artifact_args[@]}" <<'PY'
import hashlib
import json
import os
import platform
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
version = sys.argv[2]
channel = sys.argv[3]
checksums_path = Path(sys.argv[4])
artifacts = [Path(value) for value in sys.argv[5:]]

def artifact_type(path: Path) -> str:
    name = path.name
    if name.endswith(".deb"):
        return "deb"
    if name.endswith(".app.zip"):
        return "macos-app"
    if name.endswith(".dmg"):
        return "macos-installer"
    if "windows" in name.lower() and name.endswith(".zip"):
        return "windows-app"
    if name == "install-linux.sh":
        return "installer"
    if name.endswith(".img.xz"):
        return "os-image"
    if name.endswith(".sha256") or name == "checksums.sha256":
        return "checksum"
    if name.endswith(".json"):
        return "manifest"
    return "artifact"

items = []
for path in artifacts:
    data = path.read_bytes()
    items.append({
        "type": artifact_type(path),
        "path": path.name,
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    })

deb_items = [item for item in items if item["type"] == "deb"]
manifest = {
    "schema_version": 1,
    "product": "beenut",
    "version": version,
    "channel": channel,
    "created_by": platform.node(),
    "artifacts": items,
    "checksums": checksums_path.name,
}
if deb_items:
    manifest["package"] = deb_items[0]["path"]

manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

echo "$MANIFEST_PATH"
echo "$CHECKSUMS_PATH"
