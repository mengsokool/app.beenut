#!/usr/bin/env bash
# Automated script to build BeeNut OS image using OrbStack Linux machine.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARD="${BEENUT_BOARD:-rpi5}"
VERSION="${BEENUT_VERSION:-0.2.0}"
MACHINE_NAME="beenut-builder"
DEBOS_MEMORY="${DEBOS_MEMORY:-4Gb}"
DEBOS_CPUS="${DEBOS_CPUS:-4}"
XZ_THREADS="${XZ_THREADS:-0}"

# Verify docker CLI is available
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: Docker CLI not found. Please make sure OrbStack Docker is running and in your PATH." >&2
  exit 1
fi
if ! command -v orb >/dev/null 2>&1; then
  echo "Error: OrbStack CLI 'orb' not found. Install OrbStack or use os/build-beenut-image.sh on a Linux host." >&2
  exit 1
fi

echo "=== 1/3 Checking target architectures ==="
# Map target architectures
if [[ "$BOARD" == "x86_64" ]]; then
  ARCH="amd64"
else
  ARCH="arm64"
fi

# Ensure build directories exist early to prevent Docker mount latency
mkdir -p "$ROOT_DIR/os/deb"
mkdir -p "$ROOT_DIR/build/os"

echo "=== 2/3 Building the application package (.deb) via VM ==="
if ! orb list 2>/dev/null | grep -q "$MACHINE_NAME"; then
  orb create debian "$MACHINE_NAME"
fi
# Install python3 and dpkg-dev to build the package on the Debian VM
orb -m "$MACHINE_NAME" sudo apt-get update
orb -m "$MACHINE_NAME" sudo apt-get install -y python3 dpkg-dev cmake g++ qt6-base-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev curl

CACHE_DIR="$ROOT_DIR/.cache"
mkdir -p "$CACHE_DIR"
if [[ "$ARCH" == "amd64" ]]; then
  ONNX_ARCH="x64"
else
  ONNX_ARCH="aarch64"
fi
ONNX_TAR="$CACHE_DIR/onnxruntime-linux-${ONNX_ARCH}-1.18.1.tgz"
ONNX_DIR="$CACHE_DIR/onnxruntime-linux-${ONNX_ARCH}-1.18.1"

if [[ ! -d "$ONNX_DIR" ]]; then
  echo "ONNX Runtime not found in cache. Downloading from Microsoft release page..."
  if [[ ! -f "$ONNX_TAR" ]]; then
    curl -L -o "$ONNX_TAR" "https://github.com/microsoft/onnxruntime/releases/download/v1.18.1/onnxruntime-linux-${ONNX_ARCH}-1.18.1.tgz"
  fi
  tar -xzf "$ONNX_TAR" -C "$CACHE_DIR"
  echo "ONNX Runtime downloaded and extracted."
fi

# Load board environment config to obtain target kiosk mode
source "$ROOT_DIR/os/config/${BOARD}.env"

echo "Cleaning host CMake caches to prevent path mismatch..."
rm -rf "$ROOT_DIR/service/build"

echo "Compiling C++ backend (beenutd) inside VM..."
# Pass CMAKE_PREFIX_PATH pointing to extracted Linux aarch64 onnxruntime
orb -m "$MACHINE_NAME" sh -c "export CMAKE_PREFIX_PATH=$ONNX_DIR:\$CMAKE_PREFIX_PATH && cd $ROOT_DIR && ./scripts/build-service.sh"

echo "Packaging debian package inside VM..."
ALLOW_INCOMPLETE_PACKAGE="${ALLOW_MISSING_ARTIFACTS:-0}"
# Bundle ONNX Runtime private library into package libs using ONNXRUNTIME_LIB_DIR.
# Set BUILD_ROOT=/tmp/package-root to bypass VirtioFS file locking conflicts in macOS shared folders
orb -m "$MACHINE_NAME" sh -c "export ONNXRUNTIME_LIB_DIR=$ONNX_DIR/lib && cd $ROOT_DIR && BUILD_ROOT=/tmp/package-root ALLOW_MISSING_ARTIFACTS=$ALLOW_INCOMPLETE_PACKAGE BEENUT_PACKAGE_PROFILE=$BEENUT_PACKAGE_PROFILE BEENUT_KIOSK_MODE=$BEENUT_KIOSK_MODE BEENUT_ARCH=$ARCH ./scripts/build-debian.sh"

# Ensure latest deb package is copied to os/deb/
rm -f "$ROOT_DIR/os/deb"/beenut_*.deb
cp "$ROOT_DIR"/build/deb/beenut_${VERSION}_${ARCH}.deb "$ROOT_DIR/os/deb/"

# Flush filesystem buffers to make files visible in Docker context instantly
sync

echo "=== 3/3 Running debos builder via Docker ==="
# Get absolute path for mount
ABS_ROOT="$(cd "$ROOT_DIR" && pwd)"
BUILD_DIR="$ABS_ROOT/build/os"
mkdir -p "$BUILD_DIR"

if [[ "$BOARD" == "x86_64" ]]; then
  RECIPE="beenut-x86_64.yaml"
elif [[ "$BOARD" == "arm64" ]]; then
  RECIPE="beenut-arm64.yaml"
else
  RECIPE="beenut.yaml"
fi

IMAGE_NAME="beenut-os-${BOARD}-${ARCH}-${VERSION}.img"

echo "Launching godebos/debos container..."
# Debos requires privileged privileges to create partition loops and systemd chroot
# Run with --entrypoint /bin/sh to stage building in native /tmp/os-build filesystem
# This completely bypasses VirtioFS host file locking issues (QEMU write lock errors) on macOS shared folders
docker run \
  --rm \
  --privileged \
  --device /dev/loop-control \
  --device /dev/loop0 \
  --device /dev/loop1 \
  --device /dev/loop2 \
  --device /dev/loop3 \
  --device /dev/loop4 \
  --device /dev/loop5 \
  --device /dev/loop6 \
  --device /dev/loop7 \
  --cap-add SYS_ADMIN \
  --security-opt label=disable \
  --volume "$ABS_ROOT:/workspace" \
  --workdir /workspace \
  --entrypoint /bin/sh \
  godebos/debos \
  -c "set -e; mkdir -p /tmp/os-build; debos --memory=\"$DEBOS_MEMORY\" --cpus=\"$DEBOS_CPUS\" --template-var=\"IMAGE_NAME:$IMAGE_NAME\" --artifactdir=\"/tmp/os-build\" \"/workspace/os/$RECIPE\"; if [ -f \"/tmp/os-build/$IMAGE_NAME\" ]; then xz -f -T\"$XZ_THREADS\" \"/tmp/os-build/$IMAGE_NAME\"; fi; if [ -f \"/tmp/os-build/$IMAGE_NAME.xz\" ]; then sha256sum \"/tmp/os-build/$IMAGE_NAME.xz\" > \"/tmp/os-build/$IMAGE_NAME.xz.sha256\"; cp -a \"/tmp/os-build/$IMAGE_NAME.xz\" \"/tmp/os-build/$IMAGE_NAME.xz.sha256\" /workspace/build/os/; else cp -a /tmp/os-build/. /workspace/build/os/; fi"

# Compress the raw image file if a fallback path copied it uncompressed.
if [[ -f "$BUILD_DIR/$IMAGE_NAME" ]]; then
  echo "Compressing raw disk image to ${IMAGE_NAME}.xz..."
  xz -f "$BUILD_DIR/$IMAGE_NAME"
fi

# Create checksum file after docker finishes
if [[ -f "$BUILD_DIR/${IMAGE_NAME}.xz" ]]; then
  sha256sum "$BUILD_DIR/${IMAGE_NAME}.xz" > "$BUILD_DIR/${IMAGE_NAME}.xz.sha256"
  echo "=== OS Image build successfully finished! ==="
  echo "Result: $BUILD_DIR/${IMAGE_NAME}.xz"
  echo "SHA256: $(cat "$BUILD_DIR/${IMAGE_NAME}.xz.sha256")"
else
  echo "Error: debos build finished but target image file was not created." >&2
  exit 1
fi
