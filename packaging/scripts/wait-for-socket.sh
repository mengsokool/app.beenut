#!/usr/bin/env sh
set -eu

socket_path="${1:-/tmp/beenutd.sock}"
timeout_seconds="${2:-30}"
started_at="$(date +%s)"

while [ ! -S "$socket_path" ]; do
  now="$(date +%s)"
  elapsed=$((now - started_at))
  if [ "$elapsed" -ge "$timeout_seconds" ]; then
    echo "Timed out waiting for socket: $socket_path" >&2
    exit 1
  fi
  sleep 0.2
done

exit 0
