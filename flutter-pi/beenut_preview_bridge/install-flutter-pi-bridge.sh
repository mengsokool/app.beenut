#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/flutter-pi-source" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_DIR="$ROOT_DIR/flutter-pi/beenut_preview_bridge"
FLUTTER_PI_DIR="$1"

if [[ ! -f "$FLUTTER_PI_DIR/src/pluginregistry.h" || ! -f "$FLUTTER_PI_DIR/src/texture_registry.h" ]]; then
  echo "not a flutter-pi source tree: $FLUTTER_PI_DIR" >&2
  exit 1
fi

mkdir -p "$FLUTTER_PI_DIR/src/plugins/beenut_preview_bridge"
cp "$PLUGIN_DIR/beenut_preview_bridge.c" "$FLUTTER_PI_DIR/src/plugins/beenut_preview_bridge/plugin.c"
cp "$PLUGIN_DIR/shm_preview.c" "$FLUTTER_PI_DIR/src/plugins/beenut_preview_bridge/shm_preview.c"
cp "$PLUGIN_DIR/shm_preview.h" "$FLUTTER_PI_DIR/src/plugins/beenut_preview_bridge/shm_preview.h"
cp "$PLUGIN_DIR/beenut_preview_bridge.h" "$FLUTTER_PI_DIR/src/plugins/beenut_preview_bridge/beenut_preview_bridge.h"

python3 - "$FLUTTER_PI_DIR/CMakeLists.txt" <<'PYCODE'
from pathlib import Path
import sys
import re
path = Path(sys.argv[1])
text = path.read_text()
source = "src/plugins/beenut_preview_bridge/plugin.c"
text = re.sub(r"\n# BEGIN BEENUT BRIDGE.*?# END BEENUT BRIDGE\n", "\n", text, flags=re.S)
text = text.replace("\n# BeeNut native camera textures require the OpenGL renderer.\nif(NOT HAVE_EGL_GLES2)\n  message(FATAL_ERROR \"BeeNut preview requires EGL/GLES2\")\nendif()\n", "\n")
# Remove the old helper's insertion inside BUILD_TEST_PLUGIN (normally OFF).
text = "\n".join(line for line in text.split("\n") if source not in line and "beenut_preview_bridge/shm_preview.c" not in line)
if "add_library(\n  flutterpi_module" not in text and "add_library(flutterpi_module" not in text:
    raise SystemExit("Unsupported flutter-pi checkout: flutterpi_module target missing")
text += "\n# BEGIN BEENUT BRIDGE\n# Native preview and keyboard input are required by BeeNut.\n"
text += "if(NOT HAVE_EGL_GLES2)\n  message(FATAL_ERROR \"BeeNut preview requires EGL/GLES2\")\nendif()\n"
text += f"target_sources(flutterpi_module PRIVATE {source} src/plugins/beenut_preview_bridge/shm_preview.c)\n"
text += "if(NOT BUILD_TEXT_INPUT_PLUGIN OR NOT BUILD_RAW_KEYBOARD_PLUGIN)\n  message(FATAL_ERROR \"BeeNut requires text_input and raw_keyboard plugins\")\nendif()\n# END BEENUT BRIDGE\n"
path.write_text(text)
PYCODE

echo "Installed Beenut flutter-pi bridge source into $FLUTTER_PI_DIR"
