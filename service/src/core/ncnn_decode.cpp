#include "ncnn_decode.h"
#include <algorithm>
#include <cmath>
#include <vector>

namespace beenut {
namespace {
struct Box { int cls; float score, x1, y1, x2, y2; };
float overlap(const Box& a, const Box& b)
{
    const float intersection = std::max(0.f, std::min(a.x2, b.x2) - std::max(a.x1, b.x1)) *
                               std::max(0.f, std::min(a.y2, b.y2) - std::max(a.y1, b.y1));
    const float total = (a.x2-a.x1)*(a.y2-a.y1) + (b.x2-b.x1)*(b.y2-b.y1) - intersection;
    return total > 0 ? intersection / total : 0;
}
}
InferenceResult decodeNcnnYolo(const float* data, int rows, int columns,
                               const ModelConfig& config, const QStringList& labels,
                               const QString& part, const QStringList& keywords, QString* error)
{
    InferenceResult result;
    if (error) *error = {};
    const bool endToEnd = columns == 6;
    if (!data || rows <= 0 || columns <= 0 || config.inputSize <= 0 ||
        (!endToEnd && (rows < 5 || rows > 512))) {
        if (error) *error = "Unsupported NCNN output; expected YOLO26 Nx6 or YOLOv8/11 channels x boxes";
        return result;
    }
    const float size = static_cast<float>(config.inputSize);
    std::vector<Box> boxes;
    auto append = [&](int cls, float score, float x1, float y1, float x2, float y2) {
        if (cls < 0 || !std::isfinite(score) || score < config.confidenceThreshold || score > 1 ||
            !std::isfinite(x1) || !std::isfinite(y1) || !std::isfinite(x2) || !std::isfinite(y2)) return;
        Box b{cls, score, std::clamp(x1/size, 0.f, 1.f), std::clamp(y1/size, 0.f, 1.f),
              std::clamp(x2/size, 0.f, 1.f), std::clamp(y2/size, 0.f, 1.f)};
        if (b.x2 > b.x1 && b.y2 > b.y1) boxes.push_back(b);
    };
    if (endToEnd) {
        for (int i = 0; i < rows; ++i) {
            const float* b = data + i*6;
            if (!std::isfinite(b[5]) || b[5] < 0 || b[5] > 100000 || b[5] != std::floor(b[5])) continue;
            append(static_cast<int>(b[5]), b[4], b[0], b[1], b[2], b[3]);
        }
    } else {
        for (int i = 0; i < columns; ++i) {
            float score = 0; int cls = -1;
            for (int c = 4; c < rows; ++c) {
                const float value = data[c*columns + i];
                if (value > score) { score = value; cls = c-4; }
            }
            const float cx = data[i], cy = data[columns+i];
            const float w = data[2*columns+i], h = data[3*columns+i];
            append(cls, score, cx-w/2, cy-h/2, cx+w/2, cy+h/2);
        }
        std::sort(boxes.begin(), boxes.end(), [](const Box& a, const Box& b) { return a.score > b.score; });
    }
    std::vector<Box> kept;
    for (const Box& b : boxes) {
        if (!endToEnd && std::any_of(kept.begin(), kept.end(), [&](const Box& k) {
            return k.cls == b.cls && overlap(k, b) > config.nmsThreshold;
        })) continue;
        kept.push_back(b);
        const QString label = b.cls < labels.size() ? labels[b.cls] : QString("class_%1").arg(b.cls);
        if (labelMatchesPart(label, part, keywords)) {
            result.detections.append({.label=label, .confidence=b.score, .x=b.x1, .y=b.y1,
                                      .w=b.x2-b.x1, .h=b.y2-b.y1});
        }
    }
    result.count = result.detections.size();
    return result;
}
}
