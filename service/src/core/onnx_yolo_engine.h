#pragma once

#include "inference_engine.h"
#include <onnxruntime_cxx_api.h>
#include <mutex>

class QElapsedTimer;

namespace beenut {

/**
 * @brief The OnnxYoloEngine class wraps the ONNX Runtime YOLO inference engine.
 *
 * It is responsible for loading the YOLO ONNX model, running inference on incoming
 * GStreamer video samples, parsing outputs, performing non-maximum suppression (NMS),
 * and filtering outputs by targeted part type keywords.
 */
class OnnxYoloEngine : public IInferenceEngine {
    Q_OBJECT

public:
    /**
     * @brief Constructs the YOLO engine using the provided configuration.
     * @param config Model configuration containing model path, labels path, thresholds.
     * @param parent Optional Qt parent QObject.
     */
    explicit OnnxYoloEngine(ModelConfig config, QObject* parent = nullptr);
    virtual ~OnnxYoloEngine();

    /**
     * @brief Reloads a new configuration and rebuilds the ONNX session.
     * @return true if reload succeeded, false otherwise.
     */
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
    InferenceResult runOnPreprocessedInput(int width, int height, const QString& partType, const QStringList& keywords, const QElapsedTimer& timer);

    ModelConfig config_;
    Ort::Env env_;
    Ort::SessionOptions sessionOptions_;
    std::unique_ptr<Ort::Session> session_;
    QStringList labels_;
    std::string inputName_;
    std::string outputName_;
    QString detail_ = "not initialized";
    QStringList runtimeNotes_;
    bool ready_ = false;
    int mockTick_ = 0;
    int64_t batchSize_ = 1;
    std::vector<float> inputBuffer_;
    mutable std::mutex engineMutex_;
};

}  // namespace beenut
