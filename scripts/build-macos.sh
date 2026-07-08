#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_MODE="${BUILD_MODE:-release}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

cmake -S "$ROOT_DIR/service" -B "$ROOT_DIR/service/build" \
  -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}" \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build "$ROOT_DIR/service/build" -j "$JOBS"

flutter pub get
flutter build macos "--$BUILD_MODE"

case "$BUILD_MODE" in
  release) PRODUCT_MODE="Release" ;;
  debug) PRODUCT_MODE="Debug" ;;
  profile) PRODUCT_MODE="Profile" ;;
  *) PRODUCT_MODE="$BUILD_MODE" ;;
esac

APP_DIR="$ROOT_DIR/build/macos/Build/Products/$PRODUCT_MODE/BeeNut.app"
if [[ ! -d "$APP_DIR" ]]; then
  APP_DIR="$(find "$ROOT_DIR/build/macos/Build/Products" -maxdepth 2 -name '*.app' -type d | head -n 1)"
fi

if [[ -z "$APP_DIR" || ! -d "$APP_DIR" ]]; then
  echo "Unable to locate built macOS .app bundle." >&2
  exit 1
fi

install -m 0755 \
  "$ROOT_DIR/service/build/src/beenutd/beenutd" \
  "$APP_DIR/Contents/MacOS/beenutd"

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="${MACOS_CODESIGN_IDENTITY:--}"
  if [[ "$PRODUCT_MODE" == "Release" ]]; then
    ENTITLEMENTS="$ROOT_DIR/macos/Runner/Release.entitlements"
  else
    ENTITLEMENTS="$ROOT_DIR/macos/Runner/DebugProfile.entitlements"
  fi
  codesign --force --sign "$SIGN_IDENTITY" \
    -i "app.beenut.beenutFlutter.beenutd" \
    "$APP_DIR/Contents/MacOS/beenutd"
  codesign --force --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_DIR"
fi

echo "$APP_DIR"
