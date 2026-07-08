# BeeNut Architecture & Design Guide

This document describes the high-level system architecture, codebase structure, design principles, and preview transport flows of the BeeNut counting appliance.

---

## 1. System Architecture

BeeNut is structured to keep performance-heavy operations native. The Flutter UI is metadata-only; it does not decode or process raw video frames in Dart.

```
+-------------------------------------------------------------+
|                     Native Daemon (beenutd)                 |
|                                                             |
|  [Camera] -> [GStreamer Pipeline]                           |
|                    |--> AI Branch: ONNX Runtime (YOLO)      |
|                    |--> Preview Branch: Shared Memory / EGL  |
|                    +--> GPIO Controller (Tray & Light)       |
+-------------------------------------------------------------+
                               |
            [Unix Socket JSON-Lines Control Protocol]
                               |
+-------------------------------------------------------------+
|                      Flutter Kiosk App                      |
|                                                             |
|  - Renders native external preview texture                 |
|  - Displays part catalogs, stable counts, & state statuses  |
|  - Configures settings and diagnostics                      |
+-------------------------------------------------------------+
```

### Communication Protocol
The Flutter app and `beenutd` communicate via a Unix domain socket using a JSON-Lines protocol:
* **Status Updates**: The native daemon sends real-time status packets containing the current count, detected bounding boxes, tray presence, model status, and diagnostics.
* **Commands**: Flutter sends command packets to select part types, trigger manual recounts, update configurations, or request hardware reboots/shutdowns.

---

## 2. Codebase Structure

The project repository is split into two primary components:

### Flutter Client (`lib/`)
* **`lib/core/`**: Application state, data models, and services.
  * `models.dart`: JSON-serializable status, configuration, and part catalog structures.
  * `service_client.dart`: High-level interface managing the daemon connection state.
  * `service_protocol.dart`: Serializer/deserializer for socket messages.
  * `service_transport.dart`: Socket and connection handling wrapper.
* **`lib/ui/`**: Kiosk and setting views.
  * `ui/kiosk/`: The operator touchscreen panel (`kiosk_page.dart`), count display, and part selector.
  * `ui/settings/`: Tabbed configuration panel (`settings_page.dart`) for camera, models, GPIO, and part catalogs.

### Native Daemon (`service/`)
* **`service/src/beenutd/`**: Main entrypoint and overall daemon controller (`app_runtime.cpp`).
* **`service/src/core/`**: Core native modules.
  * `gstreamer_camera.cpp`: Manages camera discovery, capture pipelines, and frame splitting.
  * `onnx_yolo_engine.cpp`: Loads YOLO model session, runs inference, and performs Non-Maximum Suppression (NMS).
  * `gpio_controller.cpp`: Controls physical indicators and tray sensors using `libgpiod` or mock drivers.
  * `control_server.cpp`: Handles Unix socket connections and JSON-Lines messaging.

---

## 3. UI/UX Design System

The operator interface is designed to look like a trustworthy, high-contrast industrial appliance readable under harsh workbench lighting.

### Color Palette
* **Shell background**: `#f4f6f8` (restrained, non-distracting)
* **Surface elements**: `#ffffff`
* **Text / Primary Ink**: `#222222`
* **Primary Accent**: `#2563eb` (used only for selections and primary actions)
* **State Colors**:
  * **Success/Ready**: `#168a4a` (indicates a stable count or healthy system)
  * **Warning**: `#b7791f` (warns about temporary state, e.g., tray removed)
  * **Danger/Fault**: `#c92a2a` (indicates hardware or connection failure)

### Layout & Component Rules
* **Operator Kiosk Layout**: The kiosk page uses a split screen. The left side is reserved for the live native camera preview, and the right side houses the big count digits, status chip, and part catalog selection.
* **Settings Panel**: Uses a compact side-nav menu with dense form rows for steppers, file pickers, and toggle switches.
* **Touch Targets**: All interactive buttons must have a minimum touch size of `48x48 dp` to ensure reliable operation by users wearing work gloves.
* **Animations**: Limited to short transitions (150-220ms) for critical state updates (e.g. count changes) to avoid visual fatigue.

---

## 4. Native Preview Transport Flow

To keep CPU/GPU utilization low, frames are shared directly from the C++ video pipeline using a native texture plugin:

* **macOS Development**: Uses the `IOSurface` framework to wrap native CoreVideo textures, importing them directly into Flutter's texture registry.
* **Linux Desktop (GTK)**: Shares NV12/RGB frames via GTK's pixel buffer texture registry.
* **Raspberry Pi (DRM/GBM)**: Uses a custom `beenut_preview_bridge` plugin that imports DMA-BUF file descriptors directly as EGL external textures, avoiding any CPU copy overhead:
  ```
  DMA-BUF fd -> EGLImageKHR(EGL_LINUX_DMA_BUF_EXT) -> GL Texture -> Flutter Texture ID
  ```
