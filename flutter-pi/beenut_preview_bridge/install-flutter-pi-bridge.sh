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
cp "$PLUGIN_DIR/beenut_preview_bridge.h" "$FLUTTER_PI_DIR/src/plugins/beenut_preview_bridge/beenut_preview_bridge.h"

if ! rg -q "beenut_preview_bridge/plugin.c" "$FLUTTER_PI_DIR/CMakeLists.txt"; then
  python3 - "$FLUTTER_PI_DIR/CMakeLists.txt" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
needle = "src/plugins/testplugin.c"
insert = "src/plugins/beenut_preview_bridge/plugin.c"
if insert in text:
    raise SystemExit(0)
if needle in text:
    text = text.replace(needle, f"{needle}\n    {insert}", 1)
else:
    marker = "add_executable(flutter-pi"
    idx = text.find(marker)
    if idx < 0:
        raise SystemExit("Could not find flutter-pi source list in CMakeLists.txt")
    end = text.find(")", idx)
    text = text[:end] + f"\n    {insert}" + text[end:]
path.write_text(text)
PY
fi

echo "Installed Beenut flutter-pi bridge source into $FLUTTER_PI_DIR"
