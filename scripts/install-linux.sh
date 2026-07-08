#!/usr/bin/env bash
set -euo pipefail

REPO="${BEENUT_GITHUB_REPO:-mengsokool/app.beenut}"
VERSION="${BEENUT_VERSION:-latest}"
PROFILE="${BEENUT_PROFILE:-}"
CHANNEL="${BEENUT_CHANNEL:-stable}"
SKIP_CHECKSUM="${BEENUT_SKIP_CHECKSUM:-0}"
TMP_DIR=""
LOCK_FD=""

step() {
  echo ""
  echo "==> $*"
}

usage() {
  cat <<USAGE
Usage: install-linux.sh [--repo owner/name] [--version latest|vX.Y.Z] [--profile profile]

Downloads the BeeNut Debian package from GitHub Releases, verifies it when
checksums are published, installs or upgrades it with apt, then runs
beenut-setup.

Environment:
  BEENUT_GITHUB_REPO  GitHub repository, default: $REPO
  BEENUT_VERSION      Release tag or 'latest', default: $VERSION
  BEENUT_PROFILE      appliance-pi, appliance-linux, desktop, or dev-service
  BEENUT_CHANNEL      Release channel label for logs, default: $CHANNEL
  BEENUT_SKIP_CHECKSUM Set to 1 only for local/private release testing
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --channel)
      CHANNEL="${2:-}"
      shift 2
      ;;
    --skip-checksum)
      SKIP_CHECKSUM=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$REPO" || "$REPO" != */* ]]; then
  echo "Invalid GitHub repository: $REPO" >&2
  exit 2
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run with sudo/root:" >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/$REPO/master/scripts/install-linux.sh | sudo bash" >&2
  exit 1
fi

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
  if [[ -n "$LOCK_FD" ]]; then
    eval "exec ${LOCK_FD}>&-"
  fi
}
trap cleanup EXIT

with_lock() {
  if command -v flock >/dev/null 2>&1; then
    LOCK_FD=9
    exec 9>/tmp/beenut-install.lock
    if ! flock -n 9; then
      echo "Another BeeNut installation is already running." >&2
      exit 1
    fi
  fi
}

apt_install() {
  step "Installing packages: $*"
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

apt_repair() {
  step "Repairing interrupted apt/dpkg state"
  dpkg --configure -a
  DEBIAN_FRONTEND=noninteractive apt-get -f install -y
}

need_command() {
  local command_name="$1"
  local package_name="${2:-$1}"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    apt-get update
    apt_install "$package_name"
  fi
}

curl_download() {
  local url="$1"
  local target="$2"
  local progress_args=(--silent)
  if [[ -t 2 ]]; then
    progress_args=(--progress-bar)
  fi
  curl --fail --location --show-error \
    "${progress_args[@]}" \
    --retry 4 --retry-delay 2 --retry-connrefused \
    "$url" -o "$target"
}

detect_arch() {
  if command -v dpkg >/dev/null 2>&1; then
    dpkg --print-architecture
    return
  fi
  case "$(uname -m)" in
    aarch64|arm64) echo "arm64" ;;
    x86_64|amd64) echo "amd64" ;;
    armv7l|armhf) echo "armhf" ;;
    *) uname -m ;;
  esac
}

validate_profile() {
  case "$1" in
    ""|appliance-pi|appliance-linux|desktop|dev-service) ;;
    *)
      echo "Invalid BEENUT_PROFILE: $1" >&2
      echo "Use appliance-pi, appliance-linux, desktop, or dev-service." >&2
      exit 2
      ;;
  esac
}

asset_url_for() {
  local release_json="$1"
  local arch="$2"
  sed -n 's/.*"browser_download_url": "\(.*\.deb\)".*/\1/p' "$release_json" \
    | awk -v arch="$arch" '
        $0 ~ "_" arch "\\.deb$" { print; found=1; exit }
        $0 ~ arch && !found { candidate=$0 }
        END { if (!found && candidate) print candidate }
      '
}

asset_named_url() {
  local release_json="$1"
  local name="$2"
  sed -n 's/.*"browser_download_url": "\(.*\)".*/\1/p' "$release_json" \
    | awk -v name="$name" '$0 ~ "/" name "$" { print; exit }'
}

verify_checksum() {
  local release_json="$1"
  local deb_path="$2"
  local checksums_url checksums_path deb_name
  if [[ "$SKIP_CHECKSUM" == "1" ]]; then
    echo "Checksum verification skipped by BEENUT_SKIP_CHECKSUM=1."
    return
  fi
  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum is not available; installing coreutils."
    apt-get update
    apt_install coreutils
  fi
  checksums_url="$(asset_named_url "$release_json" "checksums.sha256")"
  if [[ -z "$checksums_url" ]]; then
    echo "checksums.sha256 was not found in the release; refusing to install without verification." >&2
    echo "Set BEENUT_SKIP_CHECKSUM=1 only for private/local testing." >&2
    exit 1
  fi
  checksums_path="$TMP_DIR/checksums.sha256"
  step "Downloading release checksums"
  curl_download "$checksums_url" "$checksums_path"
  deb_name="$(basename "$deb_path")"
  if ! awk -v name="$deb_name" '$2 == name { found=1 } END { exit found ? 0 : 1 }' "$checksums_path"; then
    echo "Release checksums do not include $deb_name." >&2
    exit 1
  fi
  step "Verifying package checksum"
  (cd "$TMP_DIR" && awk -v name="$deb_name" '$2 == name { print; exit }' checksums.sha256 | sha256sum -c -)
}

run_setup() {
  if ! command -v beenut-setup >/dev/null 2>&1; then
    return
  fi

  if [[ -n "$PROFILE" ]]; then
    case "$PROFILE" in
      appliance-pi|appliance-linux)
        echo "Appliance recovery command after install: sudo beenut-setup --recover-desktop"
        ;;
    esac
    step "Applying BeeNut setup profile: $PROFILE"
    beenut-setup --profile "$PROFILE" --non-interactive
  elif [[ -r /dev/tty && -w /dev/tty ]]; then
    step "Opening interactive BeeNut setup"
    beenut-setup </dev/tty >/dev/tty
  elif [[ -t 0 && -t 1 ]]; then
    step "Opening interactive BeeNut setup"
    beenut-setup
  else
    echo "No interactive terminal detected; applying safe desktop/package setup only."
    step "Applying safe non-interactive BeeNut setup"
    beenut-setup --non-interactive --no-appliance-hardening
  fi
}

validate_profile "$PROFILE"
with_lock

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer currently supports Debian-family Linux systems with apt-get." >&2
  exit 1
fi
if ! command -v dpkg >/dev/null 2>&1; then
  echo "dpkg is required to install BeeNut Debian packages." >&2
  exit 1
fi

apt_repair
need_command curl curl
need_command sed sed
need_command awk gawk
need_command ca-certificates ca-certificates

ARCH="$(detect_arch)"
API_URL="https://api.github.com/repos/$REPO/releases"
if [[ "$VERSION" == "latest" ]]; then
  RELEASE_URL="$API_URL/latest"
else
  RELEASE_URL="$API_URL/tags/$VERSION"
fi

echo "BeeNut Linux installer"
echo "Repository: $REPO"
echo "Release: $VERSION ($CHANNEL)"
echo "Architecture: $ARCH"
if [[ -n "$PROFILE" ]]; then
  echo "Requested profile: $PROFILE"
fi

TMP_DIR="$(mktemp -d)"
RELEASE_JSON="$TMP_DIR/release.json"
step "Fetching release metadata"
curl_download "$RELEASE_URL" "$RELEASE_JSON"

ASSET_URL="$(asset_url_for "$RELEASE_JSON" "$ARCH")"

if [[ -z "$ASSET_URL" ]]; then
  echo "No .deb asset found for architecture '$ARCH' in $REPO release '$VERSION'." >&2
  echo "Open the release page and download the matching package manually:" >&2
  if [[ "$VERSION" == "latest" ]]; then
    echo "  https://github.com/$REPO/releases/latest" >&2
  else
    echo "  https://github.com/$REPO/releases/tag/$VERSION" >&2
  fi
  exit 1
fi

DEB_PATH="$TMP_DIR/$(basename "$ASSET_URL")"
step "Downloading package: $(basename "$ASSET_URL")"
echo "$ASSET_URL"
curl_download "$ASSET_URL" "$DEB_PATH"
verify_checksum "$RELEASE_JSON" "$DEB_PATH"

step "Installing or upgrading BeeNut"
apt_install "$DEB_PATH"
apt_repair
run_setup

echo "BeeNut installation complete."
