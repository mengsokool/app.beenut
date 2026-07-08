#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${DOCKER_IMAGE:-debian:12-slim}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-}"

echo "Starting Docker build for Debian package..."

docker_args=(run --rm -i)
if [[ -n "$DOCKER_PLATFORM" ]]; then
  docker_args+=(--platform "$DOCKER_PLATFORM")
fi
docker_args+=(
  -v "$ROOT_DIR:/workspace" \
  -w /workspace \
  "$IMAGE" \
  bash
)

docker "${docker_args[@]}" << 'EOF'
    set -euo pipefail
    apt-get update && \
    apt-get install -y clang cmake curl g++ gawk libgtk-3-dev libgstreamer1.0-dev \
      libgstreamer-plugins-base1.0-dev liblzma-dev ninja-build pkg-config qt6-base-dev \
      unzip xz-utils git

    # Setup Flutter
    if [ ! -d '/opt/flutter' ]; then
      echo 'Cloning Flutter stable SDK...'
      git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/flutter
    fi
    export PATH="/opt/flutter/bin:$PATH"
    export PUB_CACHE="/workspace/.pub-cache"
    flutter config --enable-linux-desktop

    case "$(uname -m)" in
      x86_64|amd64)
        DEB_ARCH='amd64'
        FLUTTER_ARCH_DIR='x64'
        ORT_ARCH='x64'
        ;;
      aarch64|arm64)
        DEB_ARCH='arm64'
        FLUTTER_ARCH_DIR='arm64'
        ORT_ARCH='aarch64'
        ;;
      *)
        echo "Unsupported container architecture: $(uname -m)" >&2
        exit 1
        ;;
    esac

    # Download ONNX Runtime if not present
    ORT_VERSION='1.18.1'
    ORT_DIR="onnxruntime-linux-$ORT_ARCH-$ORT_VERSION"
    if [ ! -d "$ORT_DIR" ]; then
      echo "Downloading ONNX Runtime v$ORT_VERSION..."
      curl -fsSL "https://github.com/microsoft/onnxruntime/releases/download/v$ORT_VERSION/$ORT_DIR.tgz" -o onnxruntime.tgz
      tar -xzf onnxruntime.tgz
      rm onnxruntime.tgz
    fi

    # Clean old CMake and Flutter build caches to prevent path mismatch errors
    echo 'Cleaning old build caches...'
    rm -rf service/build
    rm -rf build/linux

    # Build C++ backend
    echo 'Building beenutd native backend...'
    cmake -S service -B service/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$PWD/$ORT_DIR"
    cmake --build service/build -j$(nproc)

    # Build Flutter Linux app
    echo 'Building Flutter Linux app...'
    flutter pub get
    flutter build linux --release

    # Assemble Debian package
    echo 'Assembling Debian package...'
    mkdir -p build
    export BEENUT_VERSION='0.2.0'
    export BEENUT_ARCH="$DEB_ARCH"
    export BEENUT_PACKAGE_PROFILE='appliance-linux'
    export BEENUT_KIOSK_MODE='linux'
    export BEENUTD_BIN="$PWD/service/build/src/beenutd/beenutd"
    export FLUTTER_LINUX_BUNDLE_DIR="$PWD/build/linux/$FLUTTER_ARCH_DIR/release/bundle"
    export ONNXRUNTIME_LIB_DIR="$PWD/$ORT_DIR/lib"
    export OUTPUT_DIR="$PWD/build"

    ./scripts/build-debian.sh
EOF

echo "Docker build finished successfully!"
