#pragma once

#include "app_config.h"
#include "service_state.h"

#include <QObject>
#include <QStringList>

#include <gst/gstsample.h>
#include <onnxruntime_cxx_api.h>

namespace beenut {

struct InferenceResult {
    int count = 0;
    int processingMs = 0;
    QVector<Detection> detections;
};

bool labelMatchesPart(const QString& label, const QString& partType, const QStringList& keywords = {});

/**
 * @brief The OnnxYoloEngine class wraps the ONNX Runtime YOLO inference engine.
 *
 * It is responsible for loading the YOLO ONNX model, running inference on incoming
 * GStreamer video samples, parsing outputs, performing non-maximum suppression (NMS),
 * and filtering outputs by targeted part type keywords.
 */
class OnnxYoloEngine : public QObject {
    Q_OBJECT

public:
    /**
     * @brief Constructs the YOLO engine using the provided configuration.
     * @param config Model configuration containing model path, labels path, thresholds.
     * @param parent Optional Qt parent QObject.
     */
    explicit OnnxYoloEngine(ModelConfig config, QObject* parent = nullptr);

    /**
     * @brief Reloads a new configuration and rebuilds the ONNX session.
     * @return true if reload succeeded, false otherwise.
     */
    bool reload(ModelConfig config);

    /**
     * @brief Checks if the ONNX session is fully loaded and ready to process frames.
     */
    bool isReady() const;

    /**
     * @brief Gets detail information about session loading status or errors.
     */
    QString detail() const;

    /**
     * @brief Gets the list of labels loaded from the model or labels file.
     */
    QStringList labels() const;

    /**
     * @brief Runs inference synchronously on a GStreamer video sample.
     * @param sample The video frame sample.
     * @param partType The active part type ID to filter matches.
     * @param keywords List of keywords associated with the selected part.
     * @return The parsed inference results containing count and bounding boxes.
     */
    InferenceResult run(GstSample* sample, const QString& partType, const QStringList& keywords = {});

public slots:
    void runInference(void* sample, const QString& partType, const QStringList& keywords);
    void reloadEngine(beenut::ModelConfig config);

signals:
    void inferenceFinished(const beenut::InferenceResult& result);
    void statusChanged(bool ready, const QString& detail, const QStringList& labels);

private:
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
};

}  // namespace beenut

Q_DECLARE_METATYPE(beenut::Detection)
Q_DECLARE_METATYPE(beenut::InferenceResult)
Q_DECLARE_METATYPE(beenut::ModelConfig)
