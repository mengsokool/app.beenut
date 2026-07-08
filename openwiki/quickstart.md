# BeeNut OpenWiki Quickstart

Welcome to **BeeNut**, an open-source, general-purpose Computer Vision (CV) Object Counting Kiosk. It is designed to turn standard machines or single-board computers (like Raspberry Pi) into dedicated counting appliances: simply drop in a custom YOLO ONNX model, and BeeNut handles the user interface and high-performance native inference out-of-the-box. It integrates a lightweight, hardware-accelerated **Flutter UI Operator Dashboard** with a robust **Native C++ Daemon (`beenutd`)** that leverages GStreamer for camera management and ONNX Runtime for deep learning-based object detection.

---

## 📖 Table of Contents
1. [Repository & System Overview](#-repository--system-overview)
2. [Wiki Section Guides](broken-link-prevention)
    * 🏗️ [System Architecture & IPC](architecture.md)
    * ⚙️ [Domain Concepts & YOLO AI Engine](domain_concepts.md)
    * 🔌 [Hardware & OS Integrations](integrations.md)
    * 🚀 [Operations, Build, & Deployment](operations.md)
3. [Developer Onboarding & Setup](#-developer-onboarding--setup)
4. [Testing & Quality Gates](#-testing--quality-gates)
5. [Essential Known Caveats](#-essential-known-caveats)

---

## 🔍 Repository & System Overview

The codebase is split clean down the center into a native high-performance engine and a reactive frontend UI:

```text
 camera input -> [ GStreamer AppSrc/V4L2 Pipeline ]
                     |
                     +---> Preview Frame Buffer -> Native OS Textures (Shared Memory / IOSurface / DMA-BUF)
                     |
                     +---> AI Inference Channel -> ONNX Runtime (YOLO Engine) -> NMS / Gated Counts
                     |
                     +---> Hardware Controller -> Physical LED and Tray GPIOs
                                |
                   [Unix Domain Socket control lines]
                                |
                             Flutter UI
```

### Key Source Locations
* **Frontend UI (`/lib`)**: Written in Flutter. Manages parts catalogs, settings forms, high-DPI scaling, and renders live C++ camera streams using low-overhead native hooks.
* **Backend Daemon (`/service`)**: Native C++ service compiled via CMake. Performs media pipeline processing, temperature tracking, ONNX execution, and handles real-world GPIO triggers.
* **Infrastructure Scripts (`/scripts`)**: Validation and testing scripts, Debian pacakge generation tools, deployment recovery loops, and field simulators.
* **Appliance OS Image (`/os`)**: Holds configurations, package lists, and bootstrap scripts to generate bootable Debian appliance images for standard machines or Raspberry Pi.

---

## 🚀 Wiki Section Guides

To fully understand and navigate this repository, please start on this landing page and follow these structured sections:

*   🏗️ **[System Architecture & IPC](architecture.md)**
    *   Learn how the native daemon processes GStreamer pipelines and pipes video frame sequences with zero-copy using macOS `IOSurface`, Linux Shared Memory, and DRM/KMS `DMA-BUF`.
    *   Examine Unix-domain Socket JSON-Lines streams (`/lib/core/service_protocol.dart` & `/service/src/core/control_server.cpp`).
*   ⚙️ **[Domain Concepts & YOLO/AI Inference Engine](domain_concepts.md)**
    *   Dive into YOLO26n NMS-free network execution, ONNX models, and bounding box mapping.
    *   Explore gated counting algorithms, noise filtering (median filters), parts catalogs, and tray detection state machines.
*   🔌 **[Hardware & OS Integrations](integrations.md)**
    *   Understand real physical hardware versus mock execution on developer environments (Raspberry Pi `libgpiod` vs. CPU testing).
    *   Review appliance startup scripts and display servers (`cage` Wayland compositor / `flutter-pi`).
*   🚀 **[Operations, Build, & Deployment](operations.md)**
    *   Build standard `.deb` Debian assets or full customized appliance OS images.
    *   Discover the one-command installer configuration lines, the `beenut-setup` helper, and system recovery procedures.

---

## 💻 Developer Onboarding & Setup

### 1. Prerequisites
Make sure your workstation has Flutter installed (iOS/macOS or Linux desktop targets) and CMake (for building the native service).
```bash
# Register correct GStreamer dependencies
# macOS: brew install gstreamer
# Ubuntu/Debian:
sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
                 gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
                 gstreamer1.0-plugins-ugly gstreamer1.0-libcamera
```

### 2. Sandbox Development environment
You can run a local helper script to launch the native service in "mock mode" (simulating camera and sensor interactions) and debug the Flutter interface side-by-side:
```bash
# Starts development environment with mocks enabled
./scripts/dev-env.sh
```

---

## 🧪 Testing & Quality Gates

Our codebase implements three tiers of verification to ensure both hardware and software boundaries stay healthy:

1.  **Code Analyzer & Logic Tests**:
    ```bash
    # Static checking and analyzer tests
    flutter analyze
    flutter test
    
    # Run service level unit tests (native C++)
    cd service/build
    ctest --output-on-failure
    ```
2.  **Autonomous QA Gates**:
    We have fully script-driven quality sweeps inside `/scripts`:
    *   Run static analysis + native test suites: `./scripts/validate-phase-gates.sh`
    *   Run hardware GPIO functional simulator: `./scripts/gpio-field-test.sh`
    *   Verify offline/USB updates & OS packaging: `./scripts/usb-update-field-validation.sh`

---

## ⚠️ Essential Known Caveats

*   **Appliance Hardening Blocks Desktop**: Choosing an `appliance-linux` or `appliance-pi` profile locks display-output and boot scripts to the Kiosk daemon. **Do not run this on your local development machine** without expecting a CLI takeover. Use the recovery path instantly if your GUI goes black:
    ```bash
    sudo beenut-recover-desktop # alias to beenut-setup --recover-desktop
    ```
*   **ONNX Architecture Mismatches**: Pre-compiled ONNX models run fine cross-platform, but ensure library bindings match target environments. The Raspberry Pi build bundle automatically ships optimized `onnxruntime-linux-aarch64` binaries to keep inference lag below 40ms.
