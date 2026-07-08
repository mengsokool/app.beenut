# BeeNut Runtime Architecture & IPC Specification

This document details the software architecture, lifecycle managers, communication paths, and zero-copy video frame transport mechanisms of the BeeNut system.

---

## 🏗️ System Overview & Process Isolation

BeeNut operates as two distinct, isolated processes to separate resource-intensive, real-time native computation from the UI event loop:

*   **`beenutd` (Backend)**: Runs as a high-performance C++ service daemon. It controls hardware layers (camera sensors, GPIO registers, and hardware accelerators like NPUs/GPUs) and executes continuous ONNX machine learning inference.
*   **Flutter Operator Interface (Frontend)**: Runs as a lightweight client application. It manages parts catalogs, scales high-dpi UI layouts, and handles user configurations.

```text
 ┌──────────────────────┐                     ┌──────────────────────┐
 │                      │   Unix Domain Socket│                      │
 │    Flutter Client    │ <─────────────────> │   beenutd Daemon     │
 │    (User Interface)  │    JSON-Lines IPC   │   (Native C++ Core)  │
 │                      │                     │                      │
 └──────────┬───────────┘                     └──────────┬───────────┘
            │                                            │
            ▼                                            ▼
┌───────────────────────┐                    ┌───────────────────────┐
│Renders Native Textures│                    │ GStreamer Pipelines   │
│(IOSurface / DMA-BUF / │                    │ YOLO Inference Engine │
│ Shared Memory Buffers)│                    │ Hardware GPIO Adapters│
└───────────────────────┘                    └───────────────────────┘
```

---

## 🔄 Daemon Supervision & Lifecycle Management

The lifecycle of the backend daemon is fully managed by the Dart class `DaemonManager` within the Flutter application (`/lib/core/daemon_manager.dart`). See below for key design rules:

### 1. Dynamic Binary Sourcing
The system uses platforms-specific directories relative to the application's actual directory (`Platform.resolvedExecutable`) to locate and launch the `beenutd` daemon binary:
*   On **macOS**: `../Frameworks/beenut_service`
*   On **Linux** (Desktop / Pi): `/opt/beenut/bin/beenutd`
*   On **Development machines**: Local project build paths (e.g., `service/build/src/beenutd`).

### 2. Startup Exclusivity & Safe PID Sinks
Before executing a new instance, `DaemonManager` scans for active PIDs written to `/run/beenutd.pid` or `/tmp/beenutd.pid`.
*   If a process matches, it sends `SIGTERM`, waiting up to $800\text{ms}$ before escalating to `SIGKILL`.
*   This prevents resource-intensive duplicate camera pipelines or hardware device locking.

### 3. Atomic Config Transactions
To safeguard settings profiles against power-cuts or hardware restarts, configuration edits are committed using file transactions:
1.  The target file is backed up instantly (`config.json.bak`).
2.  The updated configuration payload is written to a unique temporary file: `config.json.tmp.<time_in_micros>`.
3.  The temporary file is atomically renamed to replace the active production schema (`config.json`).

### 4. Continuous Self-Healing Loop
When `beenutd` halts unexpectedly, the Flutter client catches the exit signal and triggers a recovery routine. If the shutdown was not requested (`_stopping == false`), `DaemonManager` pauses for $2\text{seconds}$ before restarting the native execution stream.

---

## 🔌 Unix Socket JSON-Lines IPC

All structured coordination between processes passes over a local UNIX domain socket (defaulting to `/tmp/beenutd.sock`).

### A. Linear Frame Assembly
To bypass TCP/Socket buffering boundaries without splitting JSON structures, the Dart IPC client uses `Utf8LineFramer` (`/lib/core/service_protocol.dart`):
*   Accumulates incoming bytes using an uncopied `BytesBuilder(copy: false)`.
*   Locates newline delimiters (`0x0a` or `\n`), trims adjacent carriage-returns (`0x0d`), and forwards the isolated message chunk to standard UTF-8 decoders.

### B. Optimistic State Machine & IPC Debouncer
The client state machine (`/lib/core/service_client.dart`) handles config saves optimistically:
*   **Instant Updates**: Adjusting parameters in the UI (like camera exposure or target part model) updates the local `_optimisticConfig` state instantly.
*   **Save Debouncer**: A temporal timer ($220\text{ms}$) consolidates multiple sequential slider adjustments into a single IPC payload to minimize disk write cycles.
*   **Auto-Rollback**: If the daemon returns a JSON validation error, the frontend discards the pending config and rolls the UI back to the last confirmed server settings.

### C. OS-Level Socket Authentication
To prevent malicious local processes from sending hardware commands, the C++ IPC listener (`/service/src/core/control_server.cpp`) authenticates incoming socket connections at the OS kernel level:
*   **On Linux**: Uses `SO_PEERCRED` to extract the caller's unique Process ID (PID).
*   **On macOS**: Queries `LOCAL_PEERPID` via `getsockopt(SOL_LOCAL)` to verify caller identity.

---

## 🎥 Zero-Copy Video Preview Transport

The Flutter UI never decodes raw camera video in Dart. Instead, `beenutd` directly imports GPU textures into Flutter's texture registry across target platforms:

```text
 ┌──────────────┐     ┌───────────────────────┐     ┌────────────────────────┐
 │Camera Source │ ──> │GStreamer AppSink/EGL  │ ──> │Native Platform Texture │
 └──────────────┘     └───────────────────────┘     └────────────────────────┘
                                                                 │
                                                       (Texture Registration)
                                                                 ▼
                                                    ┌────────────────────────┐
                                                    │Flutter Texture Widget  │
                                                    └────────────────────────┘
```

### 1. macOS Development: IOSurface Ring Buffer
To avoid copying pixels from backends to UI memory space, `ShmNv12PreviewPlugin.swift` maps GPU-wrapped Apple CoreVideo textures through `IOSurface`:
*   A **triple-buffered ring** ensures write operations do not block ongoing reads.
*   Flutter imports the active surface ID directly as an external texture.

### 2. Linux Desktop (GTK): Shared Memory Registers
The desktop plugin (`/linux/runner/beenut_shm_texture.cc`) maps raw NV12/YUV video buffers using system-level Shared Memory segments (`shmget`/`shmat`):
*   `beenutd` writes raw frames directly to system shared memory registers.
*   The GTK pixel texture manager polls and reads the shared memory segments directly without cross-process copying.

### 3. Raspberry Pi (DRM/GBM): Direct DMA-BUF EGL Images
The embedded kiosk profile implements ultimate optimization to maximize resource constraints on Single Board Computers (like Raspberry Pi 4/5):
*   GStreamer captures frames directly into DMA-BUF GPU file handles.
*   The custom `beenut_preview_bridge` hooks the file handles straight into GL textures via EGL:
    $$\text{DMA-BUF fd} \longrightarrow \text{EGLImageKHR(EGL\_LINUX\_DMA\_BUF\_EXT)} \longrightarrow \text{GL Texture} \longrightarrow \text{Flutter Texture ID}$$
*   This zero-copy pipeline maintains 60 FPS previews with negligible CPU overhead on embedded devices.
