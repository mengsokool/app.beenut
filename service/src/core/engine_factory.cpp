#include "engine_factory.h"

namespace beenut {
namespace {
std::unique_ptr<IInferenceEngine> makeEngine(const ModelConfig& config)
{
    if (config.engine == "ncnn") {
        return std::make_unique<NcnnYoloEngine>(config);
    }
    return std::make_unique<OnnxYoloEngine>(config);
}

#ifndef ANDROID
// Keep signal connections and thread affinity stable when changing runtimes.
class RuntimeEngine final : public IInferenceEngine {
public:
    RuntimeEngine(const ModelConfig& config, QObject* parent)
        : IInferenceEngine(parent)
    {
        reload(config);
    }

    bool reload(ModelConfig config) override
    {
        if (!engine_ || runtime_ != config.engine) {
            engine_ = makeEngine(config);
            runtime_ = config.engine;
            engine_->setParent(this);
#ifndef ANDROID
            QObject::connect(engine_.get(), &IInferenceEngine::inferenceFinished,
                             this, &IInferenceEngine::inferenceFinished);
            QObject::connect(engine_.get(), &IInferenceEngine::statusChanged,
                             this, &IInferenceEngine::statusChanged);
#endif
            return engine_->isReady();
        }
        return engine_->reload(std::move(config));
    }

    bool isReady() const override { return engine_->isReady(); }
    QString detail() const override { return engine_->detail(); }
    QStringList labels() const override { return engine_->labels(); }
    InferenceResult run(const unsigned char* rgb, int width, int height,
                        const QString& part, const QStringList& keywords) override
    {
        return engine_->run(rgb, width, height, part, keywords);
    }
#ifndef ANDROID
    InferenceResult run(GstSample* sample, const QString& part, const QStringList& keywords) override
    {
        return engine_->run(sample, part, keywords);
    }
    void runInference(void* sample, const QString& part, const QStringList& keywords) override
    {
        engine_->runInference(sample, part, keywords);
    }
    void reloadEngine(ModelConfig config) override
    {
        const bool ready = reload(std::move(config));
        emit statusChanged(ready, detail(), labels());
    }
#endif
private:
    QString runtime_;
    std::unique_ptr<IInferenceEngine> engine_;
};
#endif
}  // namespace

std::unique_ptr<IInferenceEngine> createInferenceEngine(const ModelConfig& config, QObject* parent)
{
#ifdef ANDROID
    // The lightweight Android shim has no QObject thread or signal machinery.
    auto engine = makeEngine(config);
    (void) parent;
    return engine;
#else
    return std::make_unique<RuntimeEngine>(config, parent);
#endif
}
}  // namespace beenut
