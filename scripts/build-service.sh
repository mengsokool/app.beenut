#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/dev-env.sh"

cmake -S "$ROOT_DIR/service" -B "$ROOT_DIR/service/build" \
  -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}" \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build "$ROOT_DIR/service/build" -j "${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)}"
