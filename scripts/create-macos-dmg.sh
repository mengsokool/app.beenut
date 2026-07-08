#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
OUTPUT_PATH="${2:-}"
VOLUME_NAME="${VOLUME_NAME:-BeeNut}"

usage() {
  cat <<USAGE
Usage: $0 /path/to/BeeNut.app /path/to/BeeNut-macos-VERSION.dmg

Creates a drag-to-Applications macOS DMG containing BeeNut.app and an
Applications folder shortcut.
USAGE
}

if [[ -z "$APP_PATH" || -z "$OUTPUT_PATH" || ! -d "$APP_PATH" ]]; then
  usage >&2
  exit 2
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "hdiutil is required to create a macOS DMG." >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
STAGING_DIR="$WORK_DIR/staging"
RW_DMG="$WORK_DIR/beenut-rw.dmg"
mkdir -p "$STAGING_DIR"

cleanup() {
  set +e
  if [[ -n "${MOUNT_DIR:-}" && -d "$MOUNT_DIR" ]]; then
    hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$OUTPUT_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDRW \
  -fs HFS+ \
  -quiet \
  "$RW_DMG"

MOUNT_DIR="$WORK_DIR/mount"
mkdir -p "$MOUNT_DIR"
hdiutil attach "$RW_DMG" \
  -mountpoint "$MOUNT_DIR" \
  -nobrowse \
  -quiet

osascript <<OSA >/dev/null 2>&1 || true
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 620, 420}
    set icon size of icon view options of container window to 96
    set arrangement of icon view options of container window to not arranged
    set position of item "BeeNut.app" of container window to {170, 150}
    set position of item "Applications" of container window to {390, 150}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
OSA

hdiutil detach "$MOUNT_DIR" -quiet
MOUNT_DIR=""
hdiutil convert "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_PATH" \
  -quiet

echo "$OUTPUT_PATH"
