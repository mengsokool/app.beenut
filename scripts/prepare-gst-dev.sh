#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREW_PREFIX="${BREW_PREFIX:-/opt/homebrew}"
GSTREAMER_PREFIX="${GSTREAMER_PREFIX:-$BREW_PREFIX/opt/gstreamer}"
SRC_DIR="$GSTREAMER_PREFIX/lib/gstreamer-1.0"
DST_DIR="$ROOT_DIR/.cache/gst-plugins"
mkdir -p "$DST_DIR"

plugins=(
  libgstapp.dylib
  libgstapplemedia.dylib
  libgstautodetect.dylib
  libgstcoreelements.dylib
  libgstshm.dylib
  libgsttypefindfunctions.dylib
  libgstvideoconvertscale.dylib
  libgstvideofilter.dylib
  libgstvideorate.dylib
  libgstvideotestsrc.dylib
)

for plugin in "${plugins[@]}"; do
  if [[ ! -f "$SRC_DIR/$plugin" ]]; then
    echo "Missing GStreamer plugin: $SRC_DIR/$plugin" >&2
    exit 1
  fi
  rm -f "$DST_DIR/$plugin"
  ln -s "$SRC_DIR/$plugin" "$DST_DIR/$plugin"
done

echo "$DST_DIR"
