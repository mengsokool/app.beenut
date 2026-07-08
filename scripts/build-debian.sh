#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_NAME="${BEENUT_PACKAGE_NAME:-beenut}"
VERSION="${BEENUT_VERSION:-0.2.0}"
if [[ -n "${BEENUT_ARCH:-}" ]]; then
  ARCH="$BEENUT_ARCH"
elif command -v dpkg >/dev/null 2>&1; then
  ARCH="$(dpkg --print-architecture)"
else
  case "$(uname -m)" in
    arm64|aarch64) ARCH="arm64" ;;
    x86_64|amd64) ARCH="amd64" ;;
    *) ARCH="arm64" ;;
  esac
fi
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build/deb}"
PACKAGE_ROOT="$(BEENUT_PACKAGE_NAME="$PACKAGE_NAME" BEENUT_VERSION="$VERSION" BEENUT_ARCH="$ARCH" BEENUT_PACKAGE_PROFILE="${BEENUT_PACKAGE_PROFILE:-}" BEENUT_KIOSK_MODE="${BEENUT_KIOSK_MODE:-}" OUTPUT_DIR="$OUTPUT_DIR" "$ROOT_DIR/scripts/assemble-package.sh")"
DEB_PATH="$OUTPUT_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "dpkg-deb not found. Package layout assembled at $PACKAGE_ROOT" >&2
  echo "Run this command on Debian/Raspberry Pi OS to create $DEB_PATH." >&2
  exit 127
fi

dpkg-deb --build --root-owner-group "$PACKAGE_ROOT" "$DEB_PATH"
echo "$DEB_PATH"
