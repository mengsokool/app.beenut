#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_MODE="${BUILD_MODE:-release}"
KIOSK_MODE="${BEENUT_KIOSK_MODE:-flutter-pi}"
PACKAGE_PROFILE="${BEENUT_PACKAGE_PROFILE:-}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This build script is intended to run on Raspberry Pi OS / Debian Linux." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter command not found. Install Flutter for Linux arm64 and add it to PATH." >&2
  exit 1
fi

cmake -S "$ROOT_DIR/service" -B "$ROOT_DIR/service/build" \
  -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}" \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build "$ROOT_DIR/service/build" -j "$JOBS"

flutter pub get

if [[ "$KIOSK_MODE" == "linux" ]]; then
  PACKAGE_PROFILE="${PACKAGE_PROFILE:-appliance-linux}"
  flutter build linux "--$BUILD_MODE"
  if [[ "$BUILD_MODE" == "release" ]]; then
    BUNDLE_DIR="$ROOT_DIR/build/linux/arm64/release/bundle"
  else
    BUNDLE_DIR="$ROOT_DIR/build/linux/arm64/debug/bundle"
  fi

  if [[ ! -x "$BUNDLE_DIR/beenut" ]]; then
    echo "Flutter Linux bundle was not found at $BUNDLE_DIR" >&2
    echo "Check build/linux/*/$BUILD_MODE/bundle for the actual architecture directory." >&2
    exit 1
  fi

  BEENUT_PACKAGE_PROFILE="$PACKAGE_PROFILE" BEENUT_KIOSK_MODE=linux FLUTTER_LINUX_BUNDLE_DIR="$BUNDLE_DIR" "$ROOT_DIR/scripts/assemble-package.sh"
else
  PACKAGE_PROFILE="${PACKAGE_PROFILE:-appliance-pi}"
  if [[ -z "${FLUTTER_PI_BUNDLE_DIR:-}" ]]; then
    echo "BEENUT_KIOSK_MODE=flutter-pi requires FLUTTER_PI_BUNDLE_DIR=/path/to/flutter-pi/bundle." >&2
    echo "Build/export the Flutter asset bundle for flutter-pi, then rerun this script." >&2
    exit 1
  fi
  BEENUT_PACKAGE_PROFILE="$PACKAGE_PROFILE" BEENUT_KIOSK_MODE=flutter-pi "$ROOT_DIR/scripts/assemble-package.sh"
fi
echo "Pi build complete."
