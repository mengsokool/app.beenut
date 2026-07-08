#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_NAME="${BEENUT_PACKAGE_NAME:-beenut}"
VERSION="${BEENUT_VERSION:-0.2.0}"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build/package-root}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build}"
PACKAGE_ROOT="$BUILD_ROOT/$PACKAGE_NAME"
ARCH="${BEENUT_ARCH:-arm64}"
BEENUTD_BIN="${BEENUTD_BIN:-$ROOT_DIR/service/build/src/beenutd/beenutd}"
FLUTTER_LINUX_BUNDLE_DIR="${FLUTTER_LINUX_BUNDLE_DIR:-}"
FLUTTER_PI_BUNDLE_DIR="${FLUTTER_PI_BUNDLE_DIR:-}"
PACKAGE_PROFILE="${BEENUT_PACKAGE_PROFILE:-}"
KIOSK_MODE="${BEENUT_KIOSK_MODE:-}"
ONNXRUNTIME_LIB_DIR="${ONNXRUNTIME_LIB_DIR:-}"
ALLOW_MISSING_ARTIFACTS="${ALLOW_MISSING_ARTIFACTS:-0}"

copy_dir() {
  local source_dir="$1"
  local target_dir="$2"
  mkdir -p "$target_dir"
  tar -C "$source_dir" -cf - . | tar -C "$target_dir" -xf -
}

install_file() {
  local source_file="$1"
  local target_file="$2"
  local mode="$3"
  mkdir -p "$(dirname "$target_file")"
  rm -f "$target_file"
  cp "$source_file" "$target_file"
  chmod "$mode" "$target_file"
}

missing_artifact() {
  local message="$1"
  if [[ "$ALLOW_MISSING_ARTIFACTS" == "1" ]]; then
    echo "warning: $message" >&2
    return 0
  fi
  echo "$message" >&2
  exit 1
}

rm -rf "$PACKAGE_ROOT"
mkdir -p "$PACKAGE_ROOT" "$OUTPUT_DIR"

if [[ -z "$PACKAGE_PROFILE" ]]; then
  case "${KIOSK_MODE:-flutter-pi}" in
    flutter-pi) PACKAGE_PROFILE="appliance-pi" ;;
    linux) PACKAGE_PROFILE="appliance-linux" ;;
    service) PACKAGE_PROFILE="dev-service" ;;
    *) PACKAGE_PROFILE="appliance-pi" ;;
  esac
fi

case "$PACKAGE_PROFILE" in
  desktop)
    KIOSK_MODE="${KIOSK_MODE:-linux}"
    ;;
  appliance-linux)
    KIOSK_MODE="${KIOSK_MODE:-linux}"
    ;;
  appliance-pi)
    KIOSK_MODE="${KIOSK_MODE:-flutter-pi}"
    ;;
  dev-service)
    KIOSK_MODE="${KIOSK_MODE:-service}"
    ;;
  *)
    echo "BEENUT_PACKAGE_PROFILE must be 'desktop', 'appliance-linux', 'appliance-pi', or 'dev-service'" >&2
    exit 1
    ;;
esac

if [[ "$KIOSK_MODE" != "flutter-pi" && "$KIOSK_MODE" != "linux" && "$KIOSK_MODE" != "service" ]]; then
  echo "BEENUT_KIOSK_MODE must be 'flutter-pi', 'linux', or 'service'" >&2
  exit 1
fi
if [[ "$PACKAGE_PROFILE" == "desktop" && "$KIOSK_MODE" != "linux" ]]; then
  echo "desktop profile requires BEENUT_KIOSK_MODE=linux" >&2
  exit 1
fi
if [[ "$PACKAGE_PROFILE" == "appliance-linux" && "$KIOSK_MODE" != "linux" ]]; then
  echo "appliance-linux profile requires BEENUT_KIOSK_MODE=linux" >&2
  exit 1
fi
if [[ "$PACKAGE_PROFILE" == "appliance-pi" && "$KIOSK_MODE" != "flutter-pi" ]]; then
  echo "appliance-pi profile requires BEENUT_KIOSK_MODE=flutter-pi" >&2
  exit 1
fi
if [[ "$PACKAGE_PROFILE" == "dev-service" && "$KIOSK_MODE" != "service" ]]; then
  echo "dev-service profile requires BEENUT_KIOSK_MODE=service" >&2
  exit 1
fi

copy_dir "$ROOT_DIR/packaging/debian/DEBIAN" "$PACKAGE_ROOT/DEBIAN"
copy_dir "$ROOT_DIR/packaging/systemd" "$PACKAGE_ROOT/opt/beenut/systemd"
copy_dir "$ROOT_DIR/packaging/scripts" "$PACKAGE_ROOT/opt/beenut/scripts"
install_file "$ROOT_DIR/assets/images/logo.png" "$PACKAGE_ROOT/opt/beenut/branding/logo.png" 0644
install_file "$ROOT_DIR/assets/images/logo.png" "$PACKAGE_ROOT/usr/share/pixmaps/beenut.png" 0644
install_file "$ROOT_DIR/assets/images/logo.png" "$PACKAGE_ROOT/usr/share/icons/hicolor/256x256/apps/beenut.png" 0644
install_file "$ROOT_DIR/packaging/setup/beenut_setup.py" "$PACKAGE_ROOT/opt/beenut/bin/beenut-setup" 0755
install_file "$ROOT_DIR/packaging/setup/beenut_setup.py" "$PACKAGE_ROOT/usr/bin/beenut-setup" 0755
install_file "$ROOT_DIR/scripts/check-phase-evidence.py" "$PACKAGE_ROOT/opt/beenut/scripts/check-phase-evidence.py" 0755
install_file "$ROOT_DIR/scripts/create-release-evidence-set.sh" "$PACKAGE_ROOT/opt/beenut/scripts/create-release-evidence-set.sh" 0755
install_file "$ROOT_DIR/scripts/desktop-field-validation.sh" "$PACKAGE_ROOT/opt/beenut/scripts/desktop-field-validation.sh" 0755
install_file "$ROOT_DIR/scripts/gpio-field-test.sh" "$PACKAGE_ROOT/opt/beenut/scripts/gpio-field-test.sh" 0755
install_file "$ROOT_DIR/scripts/pi-field-validation.sh" "$PACKAGE_ROOT/opt/beenut/scripts/pi-field-validation.sh" 0755
install_file "$ROOT_DIR/scripts/probe-phase-hardware.sh" "$PACKAGE_ROOT/opt/beenut/scripts/probe-phase-hardware.sh" 0755
install_file "$ROOT_DIR/scripts/usb-update-field-validation.sh" "$PACKAGE_ROOT/opt/beenut/scripts/usb-update-field-validation.sh" 0755
install_file "$ROOT_DIR/scripts/validate-phase-gates.sh" "$PACKAGE_ROOT/opt/beenut/scripts/validate-phase-gates.sh" 0755
copy_dir "$ROOT_DIR/service/config" "$PACKAGE_ROOT/opt/beenut/config"
copy_dir "$ROOT_DIR/service/models" "$PACKAGE_ROOT/opt/beenut/service/models"
printf '%s\n' "$KIOSK_MODE" > "$PACKAGE_ROOT/opt/beenut/kiosk-mode"
printf '%s\n' "$PACKAGE_PROFILE" > "$PACKAGE_ROOT/opt/beenut/package-profile"
printf '%s\n' "$VERSION" > "$PACKAGE_ROOT/opt/beenut/VERSION"

python3 - "$PACKAGE_ROOT/opt/beenut/config/default.json" "$KIOSK_MODE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
mode = sys.argv[2]
config = json.loads(path.read_text(encoding="utf-8"))
camera = config.setdefault("camera", {})
if mode == "flutter-pi":
    camera["preview_transport"] = "dmabuf_egl"
    if camera.get("source") in (None, "", "auto", "avfoundation"):
        camera["source"] = "libcamera"
        camera["device"] = ""
elif mode == "service":
    camera["source"] = "mock"
    camera["device"] = ""
    camera["preview_transport"] = "shm_nv12"
    config.setdefault("model", {})["engine"] = "mock"
    config["safe_mode"] = True
else:
    camera["preview_transport"] = "shm_nv12"
    if camera.get("source") in (None, "", "auto", "avfoundation"):
        camera["source"] = "libcamera"
        camera["device"] = ""
path.write_text(json.dumps(config, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
PY

if [[ -x "$BEENUTD_BIN" ]]; then
  install_file "$BEENUTD_BIN" "$PACKAGE_ROOT/opt/beenut/bin/beenutd" 0755
else
  missing_artifact "beenutd binary not found or not executable: $BEENUTD_BIN"
  mkdir -p "$PACKAGE_ROOT/opt/beenut/bin"
fi

if [[ -z "$FLUTTER_LINUX_BUNDLE_DIR" ]]; then
  for candidate in \
    "$ROOT_DIR/build/linux/arm64/release/bundle" \
    "$ROOT_DIR/build/linux/arm64/debug/bundle" \
    "$ROOT_DIR/build/linux/x64/release/bundle" \
    "$ROOT_DIR/build/linux/x64/debug/bundle"; do
    if [[ -x "$candidate/beenut" ]]; then
      FLUTTER_LINUX_BUNDLE_DIR="$candidate"
      break
    fi
  done
fi

if [[ -n "$FLUTTER_PI_BUNDLE_DIR" && -d "$FLUTTER_PI_BUNDLE_DIR" && -f "$FLUTTER_PI_BUNDLE_DIR/kernel_blob.bin" ]]; then
  copy_dir "$FLUTTER_PI_BUNDLE_DIR" "$PACKAGE_ROOT/opt/beenut/flutter-pi"
elif [[ "$KIOSK_MODE" == "flutter-pi" ]]; then
  missing_artifact "flutter-pi asset bundle missing kernel_blob.bin: set FLUTTER_PI_BUNDLE_DIR"
  mkdir -p "$PACKAGE_ROOT/opt/beenut/flutter-pi"
else
  mkdir -p "$PACKAGE_ROOT/opt/beenut/flutter-pi"
fi

if [[ -d "$FLUTTER_LINUX_BUNDLE_DIR" && -x "$FLUTTER_LINUX_BUNDLE_DIR/beenut" ]]; then
  copy_dir "$FLUTTER_LINUX_BUNDLE_DIR" "$PACKAGE_ROOT/opt/beenut/flutter-linux"
elif [[ "$KIOSK_MODE" == "linux" ]]; then
  missing_artifact "Flutter Linux bundle missing executable: set FLUTTER_LINUX_BUNDLE_DIR or run 'flutter build linux --release'"
  mkdir -p "$PACKAGE_ROOT/opt/beenut/flutter-linux"
else
  mkdir -p "$PACKAGE_ROOT/opt/beenut/flutter-linux"
fi

if [[ "$KIOSK_MODE" == "linux" ]]; then
  mkdir -p "$PACKAGE_ROOT/usr/bin" "$PACKAGE_ROOT/usr/share/applications"
  cat >"$PACKAGE_ROOT/usr/bin/beenut" <<'SH'
#!/usr/bin/env sh
export LD_LIBRARY_PATH="/opt/beenut/flutter-linux/lib:/opt/beenut/lib:${LD_LIBRARY_PATH:-}"
exec /opt/beenut/flutter-linux/beenut "$@"
SH
  chmod 0755 "$PACKAGE_ROOT/usr/bin/beenut"
  cat >"$PACKAGE_ROOT/usr/share/applications/beenut.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=BeeNut
Comment=Industrial counting app
Exec=/usr/bin/beenut
Icon=beenut
Terminal=false
Categories=Utility;Science;
StartupNotify=true
DESKTOP
  chmod 0644 "$PACKAGE_ROOT/usr/share/applications/beenut.desktop"
fi

if [[ "$KIOSK_MODE" == "flutter-pi" ]]; then
  ln -sfn beenut-kiosk-flutter-pi.service "$PACKAGE_ROOT/opt/beenut/systemd/beenut-kiosk.service"
elif [[ "$KIOSK_MODE" == "linux" ]]; then
  ln -sfn beenut-kiosk-linux.service "$PACKAGE_ROOT/opt/beenut/systemd/beenut-kiosk.service"
fi

if [[ -n "$ONNXRUNTIME_LIB_DIR" ]]; then
  if [[ -d "$ONNXRUNTIME_LIB_DIR" ]]; then
    copy_dir "$ONNXRUNTIME_LIB_DIR" "$PACKAGE_ROOT/opt/beenut/lib"
  else
    missing_artifact "ONNX Runtime library directory not found: $ONNXRUNTIME_LIB_DIR"
  fi
else
  mkdir -p "$PACKAGE_ROOT/opt/beenut/lib"
fi

find "$PACKAGE_ROOT/DEBIAN" -type f -exec chmod 0755 {} \;
find "$PACKAGE_ROOT/opt/beenut/scripts" -type f -exec chmod 0755 {} \;

python3 - "$PACKAGE_ROOT/DEBIAN/control" "$VERSION" "$ARCH" "$KIOSK_MODE" "$PACKAGE_PROFILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
version = sys.argv[2]
arch = sys.argv[3]
mode = sys.argv[4]
profile = sys.argv[5]
base_depends = [
    "libc6",
    "libstdc++6",
    "python3",
    "sudo",
    "libqt6core6",
    "libqt6network6",
    "gstreamer1.0-tools",
    "gstreamer1.0-plugins-base",
    "gstreamer1.0-plugins-good",
    "gstreamer1.0-plugins-bad",
    "gpiod",
]
if mode == "flutter-pi":
    base_depends += ["libegl1", "libgl1", "gstreamer1.0-libcamera", "flutter-pi"]
elif mode == "linux":
    base_depends += ["libgtk-3-0", "libegl1", "libgl1", "gstreamer1.0-libcamera", "cage"]
    if profile == "desktop":
        base_depends.remove("cage")
descriptions = {
    "desktop": "Linux BeeNut desktop counting app",
    "appliance-linux": "Linux BeeNut appliance kiosk",
    "appliance-pi": "Raspberry Pi BeeNut appliance kiosk",
    "dev-service": "BeeNut backend service diagnostics package",
}
lines = path.read_text(encoding="utf-8").splitlines()
next_lines = []
for line in lines:
    if line.startswith("Version: "):
        next_lines.append(f"Version: {version}")
    elif line.startswith("Architecture: "):
        next_lines.append(f"Architecture: {arch}")
    elif line.startswith("Depends: "):
        next_lines.append("Depends: " + ", ".join(base_depends))
    elif line.startswith("Description: "):
        next_lines.append("Description: " + descriptions.get(profile, "BeeNut counting appliance"))
    else:
        next_lines.append(line)
path.write_text("\n".join(next_lines) + "\n", encoding="utf-8")
PY

echo "$PACKAGE_ROOT"
