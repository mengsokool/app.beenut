#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_BIN="$ROOT_DIR/service/build/src/beenutd/beenutd"
BASE_CONFIG="$ROOT_DIR/service/config/default.json"
TMP_DIR="$(mktemp -d)"
TMP_CONFIG="$TMP_DIR/default.json"
LOG_FILE="$TMP_DIR/beenutd.log"
SMOKE_SOCKET="/tmp/beenutd-smoke.sock"
SMOKE_PREVIEW="/tmp/beenut-preview-smoke.shm"

cleanup() {
  if [[ -n "${DAEMON_PID:-}" ]] && kill -0 "$DAEMON_PID" 2>/dev/null; then
    kill "$DAEMON_PID" 2>/dev/null || true
    wait "$DAEMON_PID" 2>/dev/null || true
  fi
  rm -f "$SMOKE_SOCKET"
  rm -f "$SMOKE_PREVIEW"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cp "$BASE_CONFIG" "$TMP_CONFIG"
perl -0pi -e "s#/tmp/beenutd\\.sock#${SMOKE_SOCKET}#g" "$TMP_CONFIG"
perl -0pi -e "s#/tmp/beenut-preview\\.sock#${SMOKE_PREVIEW}#g" "$TMP_CONFIG"
rm -f "$SMOKE_SOCKET"
rm -f "$SMOKE_PREVIEW"
"$SERVICE_BIN" --mode mock --config "$TMP_CONFIG" >"$LOG_FILE" 2>&1 &
DAEMON_PID=$!

"$ROOT_DIR/packaging/scripts/wait-for-socket.sh" "$SMOKE_SOCKET" 5

for _ in {1..50}; do
  if [[ -s "$SMOKE_PREVIEW" ]]; then
    break
  fi
  sleep 0.1
done
if [[ ! -s "$SMOKE_PREVIEW" ]]; then
  echo "preview shm was not created" >&2
  exit 1
fi
PREVIEW_MAGIC="$(od -An -tx4 -N4 "$SMOKE_PREVIEW" | tr -d '[:space:]')"
if [[ "$PREVIEW_MAGIC" != "31565342" ]]; then
  echo "preview shm magic mismatch: $PREVIEW_MAGIC" >&2
  exit 1
fi
PREVIEW_FRAME_INDEX="$(od -An -tu8 -j48 -N8 "$SMOKE_PREVIEW" | tr -d '[:space:]')"
if [[ -z "$PREVIEW_FRAME_INDEX" || "$PREVIEW_FRAME_INDEX" -le 0 || $((PREVIEW_FRAME_INDEX % 2)) -ne 0 ]]; then
  echo "preview shm frame index is not a completed frame: $PREVIEW_FRAME_INDEX" >&2
  exit 1
fi

OUTPUT="$(
  {
    printf '{"type":"getCapabilities"}\n'
    printf '{"type":"validateConfig","config":{"model":{"engine":"mock"}}}\n'
    printf '{"type":"runDiagnostic","target":"camera"}\n'
    printf '{"type":"saveConfig","config":{"model":{"engine":"mock"}}}\n'
    sleep 1
  } | nc -U "$SMOKE_SOCKET"
)"

grep -q '"type":"status"' <<<"$OUTPUT"
grep -q '"type":"capabilities"' <<<"$OUTPUT"
grep -q '"type":"configValidation"' <<<"$OUTPUT"
grep -q '"type":"diagnosticEvent"' <<<"$OUTPUT"
grep -q '"type":"configSaveResult"' <<<"$OUTPUT"
grep -q '"ok":true' <<<"$OUTPUT"

echo "beenutd smoke test passed"
