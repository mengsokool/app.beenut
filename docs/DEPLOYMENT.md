# BeeNut Deployment & Validation Guide

This document describes how to build the custom Appliance OS, generate Debian packaging, install the system on target hardware, and verify operations using validation scripts.

---

## 1. Appliance OS Image Build

BeeNut runs as a dedicated appliance OS on target hardware. The build scripts and configurations reside under the `os/` directory.

### Configuration (`os/config/`)
Environment-specific files specify OS components, package groups, kernels, and configurations:
* `rpi4.env` / `rpi5.env`: Raspberry Pi 4 & 5 board setups.
* `x86_64.env` / `arm64.env`: Target architecture base definitions.
* `beenut.yaml`: Main configuration matrix declaring base packages, overlays, and users.

### Main OS Build Scripts
* **`os/build-beenut-image.sh`**: The main orchestrator script that pulls down base Debian images, injects dependencies, applies overlays, and compiles the final bootable image.
* **`os/configure-rpi-boot.sh`**: Configures kernel parameters, camera modules (`libcamerasrc` setup), and overlays specific to Raspberry Pi.
* **`os/enable-appliance-services.sh`**: Installs boot banners (`/etc/issue`, `/etc/motd`), configures systemd target services, and registers kiosk autostart options.

---

## 2. Debian Packaging & Services

BeeNut code, configurations, and services are packaged into a standard `.deb` file for simple distribution.

### Build Package (`scripts/build-debian.sh`)
Packs the compiled C++ daemon (`beenutd`), the Flutter bundle assets, systemd files, and CLI tools into a Debian archive.

### Systemd Service Profiles (`packaging/systemd/`)
The Debian package installs two primary service definitions:
1. **`beenut-service.service`**:
   * Starts the native backend service `/opt/beenut/bin/beenutd` with config `/etc/beenut/config.json`.
   * Listens on socket `/tmp/beenutd.sock`.
2. **`beenut-kiosk-linux.service` / `beenut-kiosk-flutter-pi.service`**:
   * Waits for the backend socket to be active.
   * Launces the frontend on TTY7 (either standard X11/GTK or raw KMS/DRM using `flutter-pi`).

### Setup Helper CLI (`packaging/setup/beenut_setup.py`)
Provides a command-line utility installed as `beenut-setup` to query connected cameras, test GPIO lines, detect system capabilities, and configure the local system profile.

---

## 3. One-Command Installer

The script **`scripts/install-linux.sh`** is designed to allow one-command installation directly from GitHub Releases:

```bash
curl -fsSL https://raw.githubusercontent.com/mengsokool/app.beenut/master/scripts/install-linux.sh | sudo bash
```

It auto-detects system architecture (ARM64 vs. AMD64), determines the target profile (`appliance-pi`, `appliance-linux`, or `desktop`), downloads the latest release `.deb`, verifies SHA256 checksums, and installs the package.

---

## 4. QA and Validation Scripts

To verify correct system operation under different configurations, the `scripts/` directory provides several QA sweeps:

* **`scripts/validate-phase-gates.sh`**:
  Performs code-level verification (runs Flutter analyzer, Dart formatting tests, and executes native service C++ unit tests).
* **`scripts/pi-field-validation.sh`**:
  Performs field verification on Raspberry Pi targets:
  - Exercises GPIO relay state toggles.
  - Simulates the first-boot setup sequence.
  - Tests the factory reset cycle.
  - Simulates systemd service crashes and recovery actions.
* **`scripts/desktop-field-validation.sh`**:
  Simulates camera permission prompts, lifecycle interrupts, and mock camera fallbacks on macOS/Linux workstations.
