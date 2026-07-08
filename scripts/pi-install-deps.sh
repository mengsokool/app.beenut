#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script is intended for Raspberry Pi OS / Debian Linux." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y \
  build-essential \
  clang \
  cmake \
  curl \
  git \
  libdrm-dev \
  libegl1-mesa-dev \
  libgl1-mesa-dev \
  libgstreamer-plugins-base1.0-dev \
  libgstreamer1.0-dev \
  libgtk-3-dev \
  libsqlite3-0 \
  libstdc++-12-dev \
  libunwind-dev \
  ninja-build \
  pkg-config \
  qt6-base-dev \
  qt6-base-dev-tools \
  gstreamer1.0-libcamera \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-tools

echo "Dependencies installed."
echo "Install Flutter separately if 'flutter --version' is not available."
echo "Provide ONNX Runtime through CMAKE_PREFIX_PATH or install it system-wide before building beenutd."
