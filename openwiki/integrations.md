# BeeNut Hardware & OS Integrations

This document describes how BeeNut interfaces with physical sensors, controls system-level GPIO lines, collects hardware telemetry, and configures graphical compositors under hardened appliance OS builds.

---

## 🔌 Dual-Backend GPIO Control Architecture

To support physical testing on developer environments alongside live runs on factory workbenches, the hardware manager (`/service/src/core/gpio_controller.cpp`) implements a dual-backend hardware abstraction layer:

```text
 ┌────────────────────────────────────────────────────────┐
 │                   GPIO Controller                      │
 └─────────────────────────┬──────────────────────────────┘
                           │
       Does RPi firmware signature match in /proc?
         ├─► YES ──► Enforce Real Hardware Adapters (Libgpiod / Sysfs)
         └─► NO  ──► Is BEENUT_GPIO_ALLOW=1 set?
                       ├─► YES ──► Attempt Sysfs exports
                       └─► NO  ──► Default to Virtual Mocks
```

### 1. Hardware Backends
*   **Libgpiod Adapter**: Recommended for modern ARM64 kernels. Communicates with system GPIO chips using process-level calling commands (`gpioget`/`gpioset`).
*   **Sysfs Adapter**: Traditional fallback mode. Maps pin registers through the system file trees located at `/sys/class/gpio`. It exports pins programmatically to verify line readiness.
*   **Virtual Mock Adapter**: Safely activates on developer macOS or non-Pi Linux desktops. Simulates sensor transitions (like tray attachment or light toggle commands) directly in software.

### 2. Safeguards & Emergency Interventions
*   **Hardware Model Locks**: To protect non-target platforms from hardware commands, physical GPIO interactions are strictly locked out on non-Raspberry Pi hardware unless explicitly bypassed using the developer shell flag `BEENUT_GPIO_ALLOW=1`.
*   **Relay Safe-Mode Isolation**: If the system detects thermal throttling warnings or experiences process-level communication failures, the controller triggers **Safe Mode**. This forcibly disables power to LED illumination relays and lowers digital pins to isolate target boards.

---

## 🌡️ Host Telemetry & Environmental Queries

The performance monitor (`/service/src/core/hardware_discovery.cpp`) implements high-resolution hooks to report native device metrics back to the Flutter diagnostic panels:

### 1. GStreamer Codec Verification
Before initializing the camera capture pipeline, the service probes the operating system to confirm the presence of required encoder elements and plugin suites (like `libcamera` codecs or `v4l2src` devices):
```cpp
bool gstElementAvailable(const char* name) {
    auto* feature = gst_element_factory_find(name);
    if (feature == nullptr) return false;
    gst_object_unref(feature);
    return true;
}
```

### 2. Multi-Platform Telemetry Extractors
*   **Darwin (macOS)**: Decodes processor usage by mapping kernel statistics (`host_statistics64`) and executes OS-specific `powermetrics` commands to log the operating temperatures of GPU/NPU silicon cores.
*   **Linux (Desktop/Pi)**: Calculates CPU load by measuring processing ticks from `/proc/stat`, tracks RAM allocations from `/proc/meminfo`, and captures hardware temperatures by polling sysfs thermal zone modules (`/sys/class/thermal/thermal_zone*/temp`).
*   **Supervisor Diagnostics**: Tracks the isolated performance footprint of backend and frontend processes. It maps values by crawling active system files under `/proc/<pid>/stat`.

---

## 🖥️ Boot Compositors & Systemd Services

BeeNut is designed to run as a dedicated physical appliance. Once a setup profile is applied, the host OS's default desktop interface is disabled to run the specialized kiosk rendering engine:

```text
           [ Host System Power-On ]
                      │
                      ▼
         (Systemd Service Scheduler)
                      │
      ┌───────────────┴───────────────┐
      ▼                               ▼
[beenut-service.service]     [beenut-kiosk-linux.service]
Starts /opt/beenut/beenutd    Waits for socket -> Launches compositor
      │                               │
      ▼                               ▼
 Opens socket at              Launches Cage (Wayland) or
 /tmp/beenutd.sock            direct flutter-pi DRM/KMS outputs
```

### 1. Service Definitions (`/packaging/systemd/`)
*   **`beenut-service.service`**: Systemd unit that boots the back-end service `/opt/beenut/bin/beenutd`. It manages log rotation and sets execution restart parameters.
*   **`beenut-kiosk-linux.service`**: Systemd unit that waits for `/tmp/beenutd.sock` to become active, initializes the screen composer target, and loads the Flutter application on TTY7.

### 2. Embedded Compositors
*   **Standard Kiosk (`appliance-linux`)**: Employs the **Cage Wayland Compositor** as a minimal backdrop. Cage takes over the hardware display and forces the Flutter application window to run as a full-screen, unbundled graphical kiosk.
*   **Pi Kiosk (`appliance-pi`)**: Designed for lightweight setups. Runs the application directly on top of the Linux DRM/KMS graphics stack using **`flutter-pi`** to achieve maximum fluid performance. This bypasses the memory overhead of standard X11 or Wayland display servers entirely.
