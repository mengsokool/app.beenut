#pragma once

#include "app_config.h"
#include "service_state.h"

#ifdef ANDROID
#include "qt_compat.h"
#else
#include <QObject>
#include <QStringList>
#include <gst/gstsample.h>
#endif

namespace beenut {

struct InferenceResult {
    int count = 0;
    int processingMs = 0;
    QVector<Detection> detections;
};

bool labelMatchesPart(const QString& label, const QString& partType, const QStringList& keywords = {});

/**
 * @brief Abstract Base Class for YOLO / Deep Learning Inference Engines in BeeNut.
 */
class IInferenceEngine : public QObject {
    Q_OBJECT

public:
    explicit IInferenceEngine(QObject* parent = nullptr) : QObject(parent) {}
    virtual ~IInferenceEngine() = default;

    virtual bool reload(ModelConfig config) = 0;
    virtual bool isReady() const = 0;
    virtual QString detail() const = 0;
    virtual QStringList labels() const = 0;

#ifndef ANDROID
    virtual InferenceResult run(GstSample* sample, const QString& partType, const QStringList& keywords = {}) = 0;
#endif

    virtual InferenceResult run(const unsigned char* rgbData, int width, int height, const QString& partType, const QStringList& keywords = {}) = 0;

#ifndef ANDROID
public slots:
    virtual void runInference(void* sample, const QString& partType, const QStringList& keywords) = 0;
    virtual void reloadEngine(beenut::ModelConfig config) = 0;

signals:
    void inferenceFinished(const beenut::InferenceResult& result);
    void statusChanged(bool ready, const QString& detail, const QStringList& labels);
#endif
};

}  // namespace beenut

Q_DECLARE_METATYPE(beenut::Detection)
Q_DECLARE_METATYPE(beenut::InferenceResult)
Q_DECLARE_METATYPE(beenut::ModelConfig)
