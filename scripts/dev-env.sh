#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${BEENUT_FLUTTER_ROOT:-}" ]]; then
  ROOT_DIR="$BEENUT_FLUTTER_ROOT"
elif [[ -f "$PWD/pubspec.yaml" && -d "$PWD/service" ]]; then
  ROOT_DIR="$PWD"
else
  if [[ -n "${BASH_SOURCE:-}" ]]; then
    SCRIPT_PATH="${BASH_SOURCE[0]}"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    SCRIPT_PATH="$(eval 'echo ${(%):-%N}')"
  else
    SCRIPT_PATH="$0"
  fi
  ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
fi
BREW_PREFIX="${BREW_PREFIX:-/opt/homebrew}"
QT_PREFIX="${QT_PREFIX:-$BREW_PREFIX/opt/qt}"
GSTREAMER_PREFIX="${GSTREAMER_PREFIX:-$BREW_PREFIX/opt/gstreamer}"

export PATH="$BREW_PREFIX/bin:$QT_PREFIX/bin:$BREW_PREFIX/share/flutter/bin:$PATH"
export CMAKE_PREFIX_PATH="$QT_PREFIX:$GSTREAMER_PREFIX:$BREW_PREFIX/opt/onnxruntime:${CMAKE_PREFIX_PATH:-}"
export PKG_CONFIG_PATH="$BREW_PREFIX/lib/pkgconfig:$BREW_PREFIX/share/pkgconfig:$GSTREAMER_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export DYLD_LIBRARY_PATH="$BREW_PREFIX/lib:$GSTREAMER_PREFIX/lib:${DYLD_LIBRARY_PATH:-}"
export GI_TYPELIB_PATH="$BREW_PREFIX/lib/girepository-1.0:$GSTREAMER_PREFIX/lib/girepository-1.0:${GI_TYPELIB_PATH:-}"

if [[ -d "$ROOT_DIR/.cache/gst-plugins" ]]; then
  export GST_PLUGIN_SYSTEM_PATH_1_0="$ROOT_DIR/.cache/gst-plugins"
else
  export GST_PLUGIN_SYSTEM_PATH_1_0="$GSTREAMER_PREFIX/lib/gstreamer-1.0"
fi
export GST_PLUGIN_PATH_1_0=""
export GST_PLUGIN_SCANNER_1_0="$GSTREAMER_PREFIX/libexec/gstreamer-1.0/gst-plugin-scanner"
mkdir -p "$ROOT_DIR/.cache"
export GST_REGISTRY_1_0="$ROOT_DIR/.cache/gstreamer-registry.bin"
