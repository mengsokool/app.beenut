#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/smoke-backend.sh"

if command -v flutter >/dev/null 2>&1; then
  flutter analyze --no-pub
fi

echo "Pi smoke checks passed."
