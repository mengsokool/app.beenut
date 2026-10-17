#pragma once

#include "inference_engine.h"
#include <mutex>
#include <memory>
#include <vector>

#if defined(BEENUT_HAS_NCNN)
#include <net.h>
#endif

namespace beenut {

/**
 * @brief The NcnnYoloEngine class wraps the NCNN inference framework for YOLO object detection.
 *
 * Provides high-performance inference optimized for ARM, Vulkan GPU, and Mobile/SBC targets.
 */
class NcnnYoloEngine : public IInferenceEngine {
    Q_OBJECT

public:
    explicit NcnnYoloEngine(ModelConfig config, QObject* parent = nullptr);
    ~NcnnYoloEngine() override;

    static bool runtimeAvailable();
    static bool gpuAvailable();
    static QString resolvedBinPath(const ModelConfig& config);
    bool reload(ModelConfig config) override;
    bool isReady() const override;
    QString detail() const override;
    QStringList labels() const override;

#ifndef ANDROID
    InferenceResult run(GstSample* sample, const QString& partType, const QStringList& keywords = {}) override;
#endif

    InferenceResult run(const unsigned char* rgbData, int width, int height, const QString& partType, const QStringList& keywords = {}) override;

#ifndef ANDROID
public slots:
    void runInference(void* sample, const QString& partType, const QStringList& keywords) override;
    void reloadEngine(beenut::ModelConfig config) override;
#endif

private:
    ModelConfig config_;
    QStringList labels_;
    QString detail_ = "not initialized";
    QStringList runtimeNotes_;
    bool ready_ = false;
    int mockTick_ = 0;
    std::vector<unsigned char> rgbScratch_;
    mutable std::mutex engineMutex_;

#if defined(BEENUT_HAS_NCNN)
    ncnn::Net net_;
#endif
};

}  // namespace beenut
