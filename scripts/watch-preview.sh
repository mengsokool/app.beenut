#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOCKET_PATH="${1:-/tmp/beenut-preview.sock}"
CAPS="${2:-video/x-raw,width=1280,height=1280,framerate=30/1}"

source "$ROOT_DIR/scripts/dev-env.sh" >/dev/null

exec gst-launch-1.0 -e \
  shmsrc socket-path="$SOCKET_PATH" is-live=true do-timestamp=true \
  ! "$CAPS" \
  ! queue leaky=downstream max-size-buffers=2 \
  ! videoconvert \
  ! autovideosink sync=false
