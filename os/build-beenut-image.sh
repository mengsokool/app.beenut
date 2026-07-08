#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build/os}"
VERSION="${BEENUT_VERSION:-0.2.0}"
BOARD="${BEENUT_BOARD:-rpi5}"
DEB_PATH_OVERRIDE=""
METADATA_ONLY=0
ROOTFS_DIR="${ROOTFS_DIR:-}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Builds or describes a BeeNut appliance OS image (Pi or PC).

Options:
  -v, --version VER  Appliance version to build (default: $VERSION).
  -b, --board NAME   Board profile: rpi5, rpi4, x86_64 (default: $BOARD).
  --deb PATH         Custom path to target .deb package.
  --metadata-only    Verify inputs and write manifest/checksum placeholders only.
  --rootfs-dir DIR   Stage BeeNut overlays, package artifact, and manifest into
                     an existing or new root filesystem directory.
  -h, --help         Show this help message.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)
      VERSION="${2:-}"
      if [[ -z "$VERSION" ]]; then
        echo "--version requires a value" >&2
        exit 2
      fi
      shift 2
      ;;
    -b|--board)
      BOARD="${2:-}"
      if [[ -z "$BOARD" ]]; then
        echo "--board requires a profile name" >&2
        exit 2
      fi
      shift 2
      ;;
    --deb)
      DEB_PATH_OVERRIDE="${2:-}"
      if [[ -z "$DEB_PATH_OVERRIDE" ]]; then
        echo "--deb requires a path to package file" >&2
        exit 2
      fi
      shift 2
      ;;
    --metadata-only)
      METADATA_ONLY=1
      shift
      ;;
    --rootfs-dir)
      ROOTFS_DIR="${2:-}"
      if [[ -z "$ROOTFS_DIR" ]]; then
        echo "--rootfs-dir requires a path" >&2
        exit 2
      fi
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

BOARD_CONFIG="$ROOT_DIR/os/config/${BOARD}.env"
if [[ ! -f "$BOARD_CONFIG" ]]; then
  echo "Board config not found: $BOARD_CONFIG" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$BOARD_CONFIG"

# Determine target architecture based on board configuration
if [[ "$BOARD" == "x86_64" ]]; then
  ARCH="amd64"
  RECIPE="beenut-x86_64.yaml"
elif [[ "$BOARD" == "arm64" ]]; then
  ARCH="arm64"
  RECIPE="beenut-arm64.yaml"
else
  ARCH="arm64"
  RECIPE="beenut.yaml"
fi

# Determine target DEB path prioritizing --deb command override
if [[ -n "$DEB_PATH_OVERRIDE" ]]; then
  DEB_PATH="$DEB_PATH_OVERRIDE"
else
  DEB_PATH="${BEENUT_DEB:-$ROOT_DIR/build/deb/beenut_${VERSION}_${ARCH}.deb}"
fi

if [[ ! -f "$DEB_PATH" ]]; then
  echo "BeeNut package not found: $DEB_PATH" >&2
  echo "Build one first, for example: BEENUT_ARCH=${ARCH} scripts/build-debian.sh" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

IMAGE_NAME="beenut-os-${BOARD}-${ARCH}-${VERSION}.img"
IMAGE_PATH="$OUTPUT_DIR/$IMAGE_NAME"
SHA_PATH="$OUTPUT_DIR/${IMAGE_NAME}.xz.sha256"
MANIFEST_PATH="$OUTPUT_DIR/manifest.json"
OVERLAY_DIR="$ROOT_DIR/os/overlays"
DEB_OVERLAY_DIR="$ROOT_DIR/os/deb"

python3 - "$MANIFEST_PATH" "$VERSION" "$BOARD" "$BEENUT_IMAGE_BASE" "$BEENUT_SUPPORTED_BOARDS" "$DEB_PATH" "${IMAGE_NAME}.xz" "$OVERLAY_DIR" <<'PY'
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

manifest_path = Path(sys.argv[1])
version = sys.argv[2]
board = sys.argv[3]
base = sys.argv[4]
supported_boards = [item for item in sys.argv[5].split(",") if item]
deb_path = Path(sys.argv[6])
image_name = sys.argv[7]
overlay_dir = Path(sys.argv[8])

deb_bytes = deb_path.read_bytes()
overlays = []
if overlay_dir.exists():
    for path in sorted(item for item in overlay_dir.rglob("*") if item.is_file()):
        data = path.read_bytes()
        overlays.append({
            "path": str(path.relative_to(overlay_dir)),
            "sha256": hashlib.sha256(data).hexdigest(),
        })
manifest = {
    "product": "BeeNut OS",
    "schema_version": 1,
    "version": version,
    "board": board,
    "base": base,
    "supportedBoards": supported_boards,
    "beenutPackage": deb_path.name,
    "beenutPackageSha256": hashlib.sha256(deb_bytes).hexdigest(),
    "overlays": overlays,
    "image": image_name,
    "createdAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
}
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

stage_rootfs() {
  local rootfs_dir="$1"
  mkdir -p "$rootfs_dir"
  if [[ -d "$OVERLAY_DIR" ]]; then
    cp -a "$OVERLAY_DIR/." "$rootfs_dir/"
  fi
  install -d "$rootfs_dir/opt/beenut/packages"
  install -m 0644 "$DEB_PATH" "$rootfs_dir/opt/beenut/packages/$(basename "$DEB_PATH")"
  install -d "$rootfs_dir/etc/beenut"
  install -m 0644 "$MANIFEST_PATH" "$rootfs_dir/etc/beenut/image-manifest.json"
  cat >"$rootfs_dir/etc/beenut/image-build.env" <<ENV
BEENUT_VERSION=$VERSION
BEENUT_BOARD=$BOARD
BEENUT_IMAGE_BASE=$BEENUT_IMAGE_BASE
BEENUT_PACKAGE=/opt/beenut/packages/$(basename "$DEB_PATH")
ENV
}

stage_deb_overlay() {
  mkdir -p "$DEB_OVERLAY_DIR"
  rm -f "$DEB_OVERLAY_DIR"/beenut_*.deb
  install -m 0644 "$DEB_PATH" "$DEB_OVERLAY_DIR/$(basename "$DEB_PATH")"
}

if [[ -n "$ROOTFS_DIR" ]]; then
  stage_rootfs "$ROOTFS_DIR"
  echo "$ROOTFS_DIR"
  echo "$MANIFEST_PATH"
  exit 0
fi

if [[ "$METADATA_ONLY" == "1" ]]; then
  : > "$IMAGE_PATH"
  sha256sum "$IMAGE_PATH" > "$SHA_PATH"
  echo "$MANIFEST_PATH"
  echo "$SHA_PATH"
  exit 0
fi

if command -v debos >/dev/null 2>&1; then
  echo "Building BeeNut OS appliance image using debos recipe: $RECIPE..."
  # Clean old build products
  rm -f "$IMAGE_PATH" "${IMAGE_PATH}.xz" "${IMAGE_PATH}.xz.sha256"
  stage_deb_overlay

  # Run debos with variables passed in
  debos \
    --template-var="IMAGE_NAME:$IMAGE_NAME" \
    --artifactdir="$OUTPUT_DIR" \
    "$ROOT_DIR/os/$RECIPE"

  # Calculate sha256 checksum for the newly built compressed image
  if [[ -f "${IMAGE_PATH}.xz" ]]; then
    sha256sum "${IMAGE_PATH}.xz" > "$SHA_PATH"
    echo "OS Image successfully built: ${IMAGE_PATH}.xz"
    echo "SHA256: $(cat "$SHA_PATH")"
  else
    echo "Error: debos build completed but target image file was not found: ${IMAGE_PATH}.xz" >&2
    exit 1
  fi
elif [[ -d "${PI_GEN_DIR:-}" ]]; then
  echo "PI_GEN_DIR is set, but full image generation via pi-gen is deprecated in favor of debos." >&2
  exit 1
else
  echo "No image builder configured. Please install debos to build custom target OS images." >&2
  exit 1
fi
exit 0
