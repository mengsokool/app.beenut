#pragma once

#include "app_config.h"
#include "onnx_yolo_engine.h"
#include "service_state.h"

#include <QElapsedTimer>
#include <QVector>

namespace beenut {

struct CountingSnapshot {
    int count = 0;
    QVector<Detection> detections;
    bool locked = false;
    int samples = 0;
};

class CountingTracker {
public:
    explicit CountingTracker(CountingConfig config = {});

    void reload(CountingConfig config);
    void reset();
    CountingSnapshot update(bool trayPresent, const InferenceResult& result);
    CountingSnapshot snapshot() const;

private:
    struct Sample {
        int count = 0;
        QVector<Detection> detections;
        int processingMs = 0;
    };

    int stableFrames() const;
    int timeoutMs() const;
    CountingSnapshot lockFromSamples();

    CountingConfig config_;
    QVector<Sample> samples_;
    CountingSnapshot locked_;
    QElapsedTimer lastSampleAt_;
};

}  // namespace beenut
