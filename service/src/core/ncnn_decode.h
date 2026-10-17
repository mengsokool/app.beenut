#pragma once
#include "inference_engine.h"

namespace beenut {
// YOLO26: rows of [x1, y1, x2, y2, score, class].
// YOLOv8/11: channel-major [cx, cy, w, h, class scores...] x boxes.
InferenceResult decodeNcnnYolo(const float* data, int rows, int columns,
                               const ModelConfig& config, const QStringList& labels,
                               const QString& part, const QStringList& keywords,
                               QString* error = nullptr);
}
