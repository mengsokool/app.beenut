#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${BEENUT_CONFIG:-/etc/beenut/config.json}"
DEFAULT_CONFIG="${BEENUT_DEFAULT_CONFIG:-/opt/beenut/config/default.json}"
BACKUP_DIR="${BACKUP_DIR:-/var/lib/beenut/backups/config}"
LOG_DIR="${LOG_DIR:-/var/log/beenut}"
WIPE_LOGS=0
RESTART_SERVICES=1
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

usage() {
  cat <<USAGE
Usage: $0 [--wipe-logs] [--no-restart]

Restores BeeNut runtime configuration to the package default.
The current config is backed up before reset. Models and device identity are kept.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wipe-logs)
      WIPE_LOGS=1
      shift
      ;;
    --no-restart)
      RESTART_SERVICES=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$DEFAULT_CONFIG" ]]; then
  echo "Default config not found: $DEFAULT_CONFIG" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR" "$(dirname "$CONFIG_PATH")"

if command -v systemctl >/dev/null 2>&1; then
  systemctl stop beenut-kiosk.service >/dev/null 2>&1 || true
  systemctl stop beenut-service.service >/dev/null 2>&1 || true
fi

if [[ -f "$CONFIG_PATH" ]]; then
  cp "$CONFIG_PATH" "$BACKUP_DIR/config-$STAMP.json"
fi

tmp_config="$(mktemp "$(dirname "$CONFIG_PATH")/.config.json.XXXXXX")"
cp "$DEFAULT_CONFIG" "$tmp_config"
chmod 0640 "$tmp_config"
if id beenut >/dev/null 2>&1; then
  chown beenut:beenut "$tmp_config" || true
fi
mv "$tmp_config" "$CONFIG_PATH"

if [[ "$WIPE_LOGS" == "1" ]]; then
  find "$LOG_DIR" -type f -name '*.log' -delete 2>/dev/null || true
  find "$LOG_DIR/diagnostics" -type f -name '*.tar.gz' -delete 2>/dev/null || true
fi

if [[ "$RESTART_SERVICES" == "1" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl restart beenut-service.service >/dev/null 2>&1 || true
  if systemctl is-enabled beenut-kiosk.service >/dev/null 2>&1; then
    systemctl restart beenut-kiosk.service >/dev/null 2>&1 || true
  fi
fi

echo "Factory reset complete"
echo "Config: $CONFIG_PATH"
echo "Backup directory: $BACKUP_DIR"
