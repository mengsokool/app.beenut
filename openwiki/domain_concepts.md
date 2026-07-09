# BeeNut Domain Concepts, YOLO Engine & AI Pipelines

This section explains the AI processing pipelines, real-time object detection models, temporal stabilization filters, and catalog logic of the BeeNut software suite.

---

## 🧠 YOLO Object Detection Pipelines

BeeNut features native deep-learning inferencing through **ONNX Runtime (C++)**, feeding directly from GStreamer pipelines (`/service/src/core/onnx_yolo_engine.cpp`). It supports two primary processing modes:

### 1. End-to-End NMS-Free YOLO Parsing
BeeNut can run YOLO-style ONNX models with End-to-End (E2E) heads that generate non-redundant predictions, enabling a streamlined parsing pipeline:
*   **Predictive Shape**: `(1, num_boxes, 6)`
*   **Elements**: Each box row correlates to `[x1, y1, x2, y2, score, classId]`.
*   **Optimization**: Because overlapping box suppression is handled directly inside the model graph, the engine skips CPU-bound Non-Maximum Suppression (NMS) checks entirely, instantly mapping outputs:

```cpp
const float score = out[i * 6 + 4];
if (score < config_.confidenceThreshold) continue;

kept.push_back({
    .classId = static_cast<int>(out[i * 6 + 5]),
    .score = score,
    .x1 = std::clamp(out[i * 6 + 0] / width, 0.0F, 1.0F),
    .y1 = std::clamp(out[i * 6 + 1] / height, 0.0F, 1.0F),
    .x2 = std::clamp(out[i * 6 + 2] / width, 0.0F, 1.0F),
    .y2 = std::clamp(out[i * 6 + 3] / height, 0.0F, 1.0F),
});
```

### 2. Standard YOLO Pipeline (v8/v11)
When deploying older models, the engine maps outputs shaped `(1, channels, boxes)` (where channels represent $4 + C_{\text{classes}}$) and executes Non-Maximum Suppression (IoU) inside memory:
*   **Cache-Friendly Data Extraction**: Instead of looping columns (which causes CPU cache misses), the loop scans contiguous class score rows:
    ```cpp
    for (int c = 4; c < channels; ++c) {
        const float* classRow = out + c * boxes;
        for (int box = 0; box < boxes; ++box) {
            const float score = classRow[box];
            if (score > bestScores[box]) {
                bestScores[box] = score;
                bestClasses[box] = c - 4;
            }
        }
    }
    ```

---

## ⏱️ Gated Counting & Output Stabilization

Raw predictions from object-detection models naturally contain transient fluctuations (e.g., items shadow-blocking each other, camera sensor noise, specular glare, or parts shuffling on the tray). 

To prevent display flickering, BeeNut implements a multi-tiered signal stabilizer (`/service/src/core/counting_tracker.cpp`):

```text
       On Camera Frame Captured:
                  │
                  ▼
       [ ONNX Inference Model ] ──► Extracts raw detection candidates
                  │
                  ▼
   Is Physical Tray Present? (Sensor Gate)
          ├─► NO  ──► [Immediate Reset] Clean tracking history & zero count.
          └─► YES ──► Append detection count to sliding window queue.
                  │
                  ▼
       [ Lower Median Filter ] ──► Calculates stable count
                  │
                  ▼
       Is stable count flat for X frames? ──► [READY State] Green overlay.
```

### 1. Hardware Tray-Gate Reset
The physical presence sensor in the hardware tray functions as a master reset. If a user removes the tray to dump counted parts:
*   `trayPresent` toggles to `false`.
*   The stabilizer instantly empties its sliding history queue (`samples_.clear()`).
*   The active display collapses to `0` immediately, bypassing the stabilization delay.

### 2. Lower Median Smoothing
To smooth out transient spikes while part containers are settling, BeeNut applies a **Lower Median Filter** over a configurable sliding window of frames (configured as `stableFrames`, defaulting to $5$):
*   By sorting the sliding list of part counts and extracting the **lower index** on even lists, the system prevents temporary glare or bounding box overlaps from skewing output numbers upward:
    ```cpp
    std::sort(counts.begin(), counts.end());
    const int medianIndex = (counts.size() - 1) / 2;
    const int medianCount = counts.at(medianIndex);
    ```

### 3. Idle Purge Counter
If the inference stream is interrupted (due to camera errors or system configuration changes) and the time delta between incoming frame detections exceeds `timeoutMs` ($100\text{ms}$), the stabilizer automatically purges the state, resetting the tracking counter.

---

## 🏷️ Parts Catalog & Model Labels

The local target catalog maps object detections to operator-facing targets.

### Model Files
BeeNut does not require bundled sample models. A custom model can be as small as a single `yolo.onnx` file. When the ONNX file does not include class names in metadata, place a `labels.txt` file next to it using the same class order as the model output.

### Parts Database Registry (`lib/core/models.dart`)
Within the operator interface, parts catalogs correlate the machine's detected class indexes to real industrial items (sku codes, physical weights, packaging counts, and customer labels). 
*   **Dynamic UI Calibration**: Users can calibrate unit-weight metrics directly from the settings page. 
*   **Zero-Calibration Fallback**: If an item in the live stream matches a non-registered index, the core maps standard generic categories to prevent application crashes.
