# BeeNut Operations, Builds & Deployment

This section describes how to compile the native daemon, package the software into Debian bundles, configure target hosts using provisioning setup scripts, and recover systems after accidental lockouts.

---

## 🛠️ Native Compilation Guide

The native daemon is built using a CMake configuration (`/service/CMakeLists.txt`) which links GStreamer files against the ONNX Runtime library engine:

```bash
# Prepare paths and build the native service
cd service
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
```

The compiled binary (`beenutd`) is outputted to `service/build/src/beenutd`.

---

## 📦 Debian Package Generation

A standard Debian installer bundle is assembled using a helper shell script (`/scripts/build-debian.sh`). 

### Assembling Package Assets
The packager compiles the native service, compiles the source Flutter UI assets, and aggregates them under a structured Debian path prefix:
*   **System Binaries**: Mapped directly to `/opt/beenut/bin/beenutd`.
*   **UI Bundles**: Written to `/opt/beenut/share/beenut-ui/`.
*   **Systemd Configurations**: Exported and registered directly inside `/lib/systemd/system/`.
*   **Control Scripts**: Configures lifecycle scripts (like `postinst` and `postrm`) that automate package registers and setup dependencies on target devices.

---

## ⚙️ Post-Install Configuration Profiles

Once the `.deb` file is installed on a host system, developers can configure the local device profile using the Python-based utility **`beenut-setup`** (`/packaging/setup/beenut_setup.py`):

```bash
# Interactively detect hardware and select runtime profile
sudo beenut-setup
```

### Profile Behaviors

| Profile Mode | Graphical Target | Core Responsibility & Hardening Level |
| :--- | :--- | :--- |
| **`desktop`** | Standard Desktop (X11) | Normal app installation. Registers standard application launcher files under `/usr/share/applications` without limiting display targets. |
| **`appliance-linux`** | Cage Wayland Compositor | High hardening. Installs the light Wayland compositor **Cage**, binds the display to TTY7, and starts a full-screen kiosk process automatically. |
| **`appliance-pi`** | Direct KMS/DRM (flutter-pi) | Maximum hardening. Disables common display managers, configures autologin parameters to skip desktop systems, and boots the kiosk on raw framebuffers. |
| **`dev-service`** | No GUI | Headless debugging. Runs the daemon service `/opt/beenut/bin/beenutd` directly without launching a graphical frontend UI. |

---

## 🔒 Appliance Hardening Security Policies

When an **Appliance** profile (`appliance-linux` or `appliance-pi`) is selected, `beenut-setup` applies security restrictions to turn the host operating system into a dedicated industrial appliance:
*   **Shell Restriction**: Changes the system users' login shells to `/sbin/nologin` or equivalent restricted environments.
*   **No TTY Consoles**: Disables physical terminal login lines (`getty@tty1`).
*   **No SSH Shells**: Halts and disables standard SSH interfaces to lock out remote manual modifications.
*   **Silent Boot Logo**: Configures GRUB configs and applies a custom **Plymouth boot splash theme** to mask kernel diagnostic outputs behind a branded splash screen.

---

## 🛡️ Emergency Desktop Recovery

Because Appliance profiles lock the host device into high-contrast kiosk mode, **never apply appliance profiles directly on a personal development machine**. 

If a computer gets unexpectedly locked into the appliance loop, developers can boot with a fallback terminal or SSH session to restore the standard graphical desktop stack:

```bash
# Execute recovery script (restores display managers and window managers)
sudo beenut-recover-desktop

# Alternative direct shell command
sudo beenut-setup --recover-desktop
```

### Recovery Steps
1.  Stops the background services `beenut-service.service` and `beenut-kiosk.service`.
2.  Disables the kiosk service from the boot startup registry.
3.  Re-enables the system's standard display managers (like GDM, SDDM, or LightDM).
4.  Restores systemd's default target back to `graphical.target`.
5.  Reboots the device into the standard graphical desktop.
