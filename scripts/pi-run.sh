#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-$ROOT_DIR/service/config/default.json}"
BACKEND_BIN="${BACKEND_BIN:-$ROOT_DIR/service/build/src/beenutd/beenutd}"
KIOSK_MODE="${BEENUT_KIOSK_MODE:-linux}"

if [[ ! -x "$BACKEND_BIN" ]]; then
  echo "beenutd not found. Run scripts/build-pi.sh first." >&2
  exit 1
fi

cleanup() {
  if [[ -n "${BACKEND_PID:-}" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
    wait "$BACKEND_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

"$BACKEND_BIN" --config "$CONFIG" &
BACKEND_PID=$!

"$ROOT_DIR/packaging/scripts/wait-for-socket.sh" /tmp/beenutd.sock 10
if [[ "$KIOSK_MODE" == "flutter-pi" ]]; then
  if [[ -z "${FLUTTER_PI_BUNDLE_DIR:-}" ]]; then
    echo "Set FLUTTER_PI_BUNDLE_DIR to run flutter-pi mode." >&2
    exit 1
  fi
  exec flutter-pi --release "$FLUTTER_PI_BUNDLE_DIR"
fi

flutter run -d linux
