#!/usr/bin/env bash
set -euo pipefail

UPDATE_DIR=""
CONFIG_PATH="${BEENUT_CONFIG:-/etc/beenut/config.json}"
BACKUP_ROOT="${BACKUP_ROOT:-/var/lib/beenut/backups}"
RESULT_LOG="${RESULT_LOG:-/var/log/beenut/update-result.log}"
SOCKET_PATH="${BEENUT_SOCKET:-/tmp/beenutd.sock}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DRY_RUN=0
RESTART_SERVICES=1
HEALTH_TIMEOUT=20

usage() {
  cat <<USAGE
Usage: $0 [--dry-run] [--no-restart] [--health-timeout seconds] /media/usb/beenut-update

Expected layout:
  beenut-update/
    manifest.json
    checksums.sha256
    beenut_VERSION_ARCH.deb or packages/beenut_VERSION_ARCH.deb
    models/                 optional
USAGE
}

log() {
  mkdir -p "$(dirname "$RESULT_LOG")"
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$RESULT_LOG"
}

install_package() {
  local package_path="$1"
  if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y "$package_path"
  else
    dpkg -i "$package_path"
  fi
}

restart_services() {
  if [[ "$RESTART_SERVICES" != "1" ]] || ! command -v systemctl >/dev/null 2>&1; then
    return 0
  fi
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl restart beenut-service.service >/dev/null 2>&1 || true
  if systemctl is-enabled beenut-kiosk.service >/dev/null 2>&1; then
    systemctl restart beenut-kiosk.service >/dev/null 2>&1 || true
  fi
}

health_check() {
  if [[ "$RESTART_SERVICES" != "1" || "$HEALTH_TIMEOUT" -le 0 ]]; then
    return 0
  fi
  if [[ -x /opt/beenut/scripts/wait-for-socket.sh ]]; then
    /opt/beenut/scripts/wait-for-socket.sh "$SOCKET_PATH" "$HEALTH_TIMEOUT"
  else
    local started_at
    started_at="$(date +%s)"
    while [[ ! -S "$SOCKET_PATH" ]]; do
      if (( $(date +%s) - started_at >= HEALTH_TIMEOUT )); then
        echo "Timed out waiting for socket: $SOCKET_PATH" >&2
        return 1
      fi
      sleep 0.2
    done
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-restart)
      RESTART_SERVICES=0
      shift
      ;;
    --health-timeout)
      HEALTH_TIMEOUT="${2:-}"
      if ! [[ "$HEALTH_TIMEOUT" =~ ^[0-9]+$ ]]; then
        echo "--health-timeout requires a non-negative integer" >&2
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$UPDATE_DIR" ]]; then
        echo "Only one update directory can be provided" >&2
        exit 2
      fi
      UPDATE_DIR="$1"
      shift
      ;;
  esac
done

if [[ -z "$UPDATE_DIR" ]]; then
  usage >&2
  exit 2
fi

if [[ ! -d "$UPDATE_DIR" ]]; then
  echo "Update directory not found: $UPDATE_DIR" >&2
  exit 1
fi

UPDATE_DIR="$(cd "$UPDATE_DIR" && pwd)"
MANIFEST="$UPDATE_DIR/manifest.json"
CHECKSUMS="$UPDATE_DIR/checksums.sha256"
PACKAGE_PATH=""

if [[ -f "$CHECKSUMS" ]]; then
  log "Verifying checksums in $CHECKSUMS"
  (cd "$UPDATE_DIR" && sha256sum -c "$(basename "$CHECKSUMS")")
else
  log "WARNING: checksums.sha256 not found; continuing without checksum verification"
fi

if [[ -f "$MANIFEST" ]]; then
  PACKAGE_PATH="$(python3 - "$MANIFEST" "$UPDATE_DIR" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
root = Path(sys.argv[2])
for key in ("package", "deb", "deb_path"):
    value = manifest.get(key)
    if isinstance(value, str) and value:
        print(root / value)
        raise SystemExit
artifacts = manifest.get("artifacts", [])
if isinstance(artifacts, list):
    for item in artifacts:
        if isinstance(item, dict) and item.get("type") in ("deb", "package"):
            path = item.get("path")
            if isinstance(path, str) and path:
                print(root / path)
                raise SystemExit
PY
)"
fi

if [[ -z "$PACKAGE_PATH" ]]; then
  PACKAGE_PATH="$(find "$UPDATE_DIR" -maxdepth 1 -type f -name '*.deb' | sort | head -n 1)"
fi

if [[ -z "$PACKAGE_PATH" && -d "$UPDATE_DIR/packages" ]]; then
  PACKAGE_PATH="$(find "$UPDATE_DIR/packages" -maxdepth 1 -type f -name '*.deb' | sort | head -n 1)"
fi

if [[ -z "$PACKAGE_PATH" || ! -f "$PACKAGE_PATH" ]]; then
  echo "No .deb package found in update directory: $UPDATE_DIR or $UPDATE_DIR/packages" >&2
  exit 1
fi

if [[ "$DRY_RUN" == "1" ]]; then
  log "Dry run passed; package candidate: $PACKAGE_PATH"
  exit 0
fi

mkdir -p "$BACKUP_ROOT/config" "$BACKUP_ROOT/packages"
ROLLBACK_PACKAGE="$(
  python3 - "$BACKUP_ROOT/packages" "$(basename "$PACKAGE_PATH")" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
current = sys.argv[2]
packages = [
    path for path in root.glob("*.deb")
    if path.name != current and path.is_file()
]
packages.sort(key=lambda path: path.stat().st_mtime, reverse=True)
if packages:
    print(packages[0])
PY
)"
if [[ -f "$CONFIG_PATH" ]]; then
  cp "$CONFIG_PATH" "$BACKUP_ROOT/config/config-before-update-$STAMP.json"
fi
cp "$PACKAGE_PATH" "$BACKUP_ROOT/packages/$(basename "$PACKAGE_PATH")"

log "Applying package: $PACKAGE_PATH"
if [[ "$RESTART_SERVICES" == "1" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl stop beenut-kiosk.service >/dev/null 2>&1 || true
  systemctl stop beenut-service.service >/dev/null 2>&1 || true
fi

install_package "$PACKAGE_PATH"

if [[ -d "$UPDATE_DIR/models" ]]; then
  log "Copying model updates"
  mkdir -p /opt/beenut/service/models
  cp -a "$UPDATE_DIR/models/." /opt/beenut/service/models/
fi

restart_services

if ! health_check; then
  log "Health check failed after update"
  if [[ -n "$ROLLBACK_PACKAGE" && -f "$ROLLBACK_PACKAGE" ]]; then
    log "Rolling back to $ROLLBACK_PACKAGE"
    install_package "$ROLLBACK_PACKAGE"
    restart_services
    if health_check; then
      log "Rollback complete"
      exit 1
    fi
  fi
  log "Rollback unavailable or health check still failing"
  exit 1
fi

log "Update complete"
echo "$RESULT_LOG"
