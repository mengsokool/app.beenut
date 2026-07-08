#include "onnx_yolo_engine.h"

#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QThread>
#include <QDebug>

#if defined(Q_OS_MAC) && defined(BEENUT_HAS_ONNXRUNTIME_COREML)
#if __has_include(<onnxruntime/coreml_provider_factory.h>)
#include <onnxruntime/coreml_provider_factory.h>
#elif __has_include(<coreml_provider_factory.h>)
#include <coreml_provider_factory.h>
#else
#undef BEENUT_HAS_ONNXRUNTIME_COREML
#endif
#endif

#include <array>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <utility>
#include <vector>

namespace {

struct Candidate {
    int classId = 0;
    float score = 0.0F;
    float x1 = 0.0F;
    float y1 = 0.0F;
    float x2 = 0.0F;
    float y2 = 0.0F;
};

float intersectionOverUnion(const Candidate& a, const Candidate& b)
{
    const float x1 = std::max(a.x1, b.x1);
    const float y1 = std::max(a.y1, b.y1);
    const float x2 = std::min(a.x2, b.x2);
    const float y2 = std::min(a.y2, b.y2);
    const float w = std::max(0.0F, x2 - x1);
    const float h = std::max(0.0F, y2 - y1);
    const float inter = w * h;
    const float areaA = std::max(0.0F, a.x2 - a.x1) * std::max(0.0F, a.y2 - a.y1);
    const float areaB = std::max(0.0F, b.x2 - b.x1) * std::max(0.0F, b.y2 - b.y1);
    const float denom = areaA + areaB - inter;
    return denom <= 0.0F ? 0.0F : inter / denom;
}

QStringList labelsFromStructuredText(const QString& raw)
{
    QStringList labels;
    const auto text = raw.trimmed();
    const auto document = QJsonDocument::fromJson(text.toUtf8());
    if (document.isArray()) {
        for (const auto& item : document.array()) {
            const auto label = item.toString().trimmed();
            if (!label.isEmpty()) {
                labels.append(label);
            }
        }
        return labels;
    }
    if (document.isObject()) {
        const auto object = document.object();
        QStringList keys = object.keys();
        std::sort(keys.begin(), keys.end(), [](const QString& a, const QString& b) {
            return a.toInt() < b.toInt();
        });
        for (const auto& key : keys) {
            const auto label = object.value(key).toString().trimmed();
            if (!label.isEmpty()) {
                labels.append(label);
            }
        }
        return labels;
    }

    QRegularExpression pythonDictValue(R"((?:^|[,{\s])\d+\s*:\s*['"]([^'"]+)['"])");
    auto it = pythonDictValue.globalMatch(text);
    while (it.hasNext()) {
        labels.append(it.next().captured(1).trimmed());
    }
    if (!labels.isEmpty()) {
        return labels;
    }

    QRegularExpression quotedValue(R"(['"]([^'"]+)['"])");
    it = quotedValue.globalMatch(text);
    while (it.hasNext()) {
        labels.append(it.next().captured(1).trimmed());
    }
    return labels;
}

QStringList labelsFromMetadata(const Ort::Session& session)
{
    Ort::AllocatorWithDefaultOptions allocator;
    const auto metadata = session.GetModelMetadata();
    const QStringList preferredKeys = {"names", "labels", "classes", "class_names"};
    for (const auto& key : preferredKeys) {
        auto value = metadata.LookupCustomMetadataMapAllocated(key.toUtf8().constData(), allocator);
        if (value == nullptr) {
            continue;
        }
        const auto labels = labelsFromStructuredText(QString::fromUtf8(value.get()));
        if (!labels.isEmpty()) {
            return labels;
        }
    }
    return {};
}

}  // namespace

namespace beenut {

bool labelMatchesPart(const QString& label, const QString& partType, const QStringList& keywords)
{
    const auto haystack = label.toLower();
    const auto needle = partType.toLower();
    for (const auto& keyword : keywords) {
        const auto mapped = keyword.toLower().trimmed();
        if (!mapped.isEmpty() && haystack.contains(mapped)) {
            return true;
        }
    }
    if (needle.isEmpty()) {
        return true;
    }
    if (haystack.contains(needle)) {
        return true;
    }
    return false;
}

OnnxYoloEngine::OnnxYoloEngine(ModelConfig config, QObject* parent)
    : QObject(parent),
      config_(std::move(config)),
      env_(ORT_LOGGING_LEVEL_WARNING, "beenut"),
      sessionOptions_()
{
    qRegisterMetaType<beenut::Detection>("beenut::Detection");
    qRegisterMetaType<QVector<beenut::Detection>>("QVector<beenut::Detection>");
    qRegisterMetaType<beenut::InferenceResult>("beenut::InferenceResult");
    qRegisterMetaType<beenut::ModelConfig>("beenut::ModelConfig");

    const int totalCores = QThread::idealThreadCount();
    int intraThreads = 2;
    if (totalCores <= 2) {
        intraThreads = totalCores;
    } else if (totalCores <= 4) {
        intraThreads = totalCores - 1;
    } else {
        intraThreads = totalCores - 2;
    }
    intraThreads = std::clamp(intraThreads, 1, 8);
#ifdef Q_OS_MAC
    intraThreads = std::min(intraThreads, 4);
#endif

    sessionOptions_.SetIntraOpNumThreads(intraThreads);
    sessionOptions_.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);

    runtimeNotes_.append(QString("CPU cores %1; ONNX threads %2").arg(totalCores).arg(intraThreads));

#if defined(Q_OS_MAC) && defined(BEENUT_HAS_ONNXRUNTIME_COREML)
    {
        uint32_t flags = COREML_FLAG_ENABLE_ON_SUBGRAPH;
        OrtStatus* status = OrtSessionOptionsAppendExecutionProvider_CoreML(sessionOptions_, flags);
        if (status != nullptr) {
            const auto message = QString::fromUtf8(Ort::GetApi().GetErrorMessage(status));
            runtimeNotes_.append(QString("CoreML unavailable: %1").arg(message));
            qWarning() << "Failed to append CoreML provider:" << message;
            Ort::GetApi().ReleaseStatus(status);
        } else {
            runtimeNotes_.append("CoreML enabled");
        }
    }
#elif defined(Q_OS_MAC)
    runtimeNotes_.append("CoreML provider unavailable: ONNX Runtime provider header not found");
#endif

    reload(config_);
}

bool OnnxYoloEngine::reload(ModelConfig config)
{
    config_ = std::move(config);
    session_.reset();
    labels_.clear();
    inputName_.clear();
    outputName_.clear();
    mockTick_ = 0;
    ready_ = false;
    detail_ = "not initialized";

    if (config_.engine == "mock") {
        labels_ = {"target"};
        ready_ = true;
        detail_ = "mock inference active";
        return true;
    }

    if (config_.engine != "onnx") {
        detail_ = QString("%1 runtime is not implemented in this build").arg(config_.engine);
        return false;
    }

    const QFileInfo model(config_.modelPath);
    if (!model.exists()) {
        detail_ = QString("ONNX model missing: %1").arg(config_.modelPath);
        return false;
    }

    try {
#ifdef _WIN32
        const std::wstring modelPath = config_.modelPath.toStdWString();
        session_ = std::make_unique<Ort::Session>(env_, modelPath.c_str(), sessionOptions_);
#else
        session_ = std::make_unique<Ort::Session>(env_, config_.modelPath.toUtf8().constData(), sessionOptions_);
#endif
        Ort::AllocatorWithDefaultOptions allocator;
        inputName_ = session_->GetInputNameAllocated(0, allocator).get();
        outputName_ = session_->GetOutputNameAllocated(0, allocator).get();

        // Get expected input batch size from model input metadata
        batchSize_ = 1;
        try {
            auto inputTypeInfo = session_->GetInputTypeInfo(0);
            auto inputTensorInfo = inputTypeInfo.GetTensorTypeAndShapeInfo();
            auto inputShape = inputTensorInfo.GetShape();
            if (inputShape.size() >= 4 && inputShape[0] > 0) {
                batchSize_ = inputShape[0];
            }
        } catch (...) {
            batchSize_ = 1;
        }

        if (config_.labelsMode == "auto") {
            labels_ = labelsFromMetadata(*session_);
        } else {
            const auto labelsPath = resolvedLabelsPath(config_);
            QFile labelsFile(labelsPath);
            if (labelsFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                while (!labelsFile.atEnd()) {
                    const auto label = QString::fromUtf8(labelsFile.readLine()).trimmed();
                    if (!label.isEmpty()) {
                        labels_.append(label);
                    }
                }
            }
        }
        ready_ = true;
        detail_ = QString("ONNX Runtime ready: %1 · %2 labels · %3")
                      .arg(model.fileName())
                      .arg(labels_.size())
                      .arg(config_.labelsMode == "auto"
                               ? (labels_.isEmpty() ? "auto labels unavailable" : "auto labels from model metadata")
                               : "custom labels file");
        if (!runtimeNotes_.isEmpty()) {
            detail_.append(QString(" · %1").arg(runtimeNotes_.join(" · ")));
        }
    } catch (const Ort::Exception& error) {
        detail_ = QString("ONNX Runtime error: %1").arg(error.what());
    }
    return ready_;
}

bool OnnxYoloEngine::isReady() const { return ready_; }
QString OnnxYoloEngine::detail() const { return detail_; }
QStringList OnnxYoloEngine::labels() const { return labels_; }

InferenceResult OnnxYoloEngine::run(GstSample* sample, const QString& partType, const QStringList& keywords)
{
    QElapsedTimer timer;
    timer.start();

    InferenceResult result;
    if (config_.engine == "mock" && ready_) {
        ++mockTick_;
        const int count = 10;
        const auto label = partType.isEmpty() ? labels_.value(0, "target") : partType;
        result.count = count;
        result.processingMs = 4;
        result.detections.reserve(count);
        const int columns = 4;
        const int rows = (count + columns - 1) / columns;
        for (int i = 0; i < count; ++i) {
            const int col = i % columns;
            const int row = i / columns;
            const double jitter = ((mockTick_ + i) % 5) * 0.002;
            result.detections.append({
                .label = label,
                .confidence = 0.86 + (i % 4) * 0.02,
                .x = 0.14 + col * 0.18 + jitter,
                .y = 0.18 + row * (0.58 / std::max(1, rows)) + jitter,
                .w = 0.08,
                .h = 0.08,
            });
        }
        return result;
    }

    if (sample == nullptr || !ready_) {
        result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
        return result;
    }

    auto* buffer = gst_sample_get_buffer(sample);
    auto* caps = gst_sample_get_caps(sample);
    GstMapInfo map;
    if (buffer == nullptr || caps == nullptr || !gst_buffer_map(buffer, &map, GST_MAP_READ)) {
        result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
        return result;
    }

    const auto* structure = gst_caps_get_structure(caps, 0);
    int width = 640;
    int height = 640;
    gst_structure_get_int(structure, "width", &width);
    gst_structure_get_int(structure, "height", &height);

    const size_t singleImageSize = static_cast<size_t>(3 * width * height);
    const size_t totalSize = singleImageSize * batchSize_;
    if (inputBuffer_.size() != totalSize) {
        inputBuffer_.resize(totalSize);
    }
    const auto* src = static_cast<const unsigned char*>(map.data);
    const size_t pixels = static_cast<size_t>(width * height);
    for (size_t i = 0; i < pixels; ++i) {
        inputBuffer_[i] = static_cast<float>(src[i * 3]) / 255.0F;
        inputBuffer_[pixels + i] = static_cast<float>(src[i * 3 + 1]) / 255.0F;
        inputBuffer_[pixels * 2 + i] = static_cast<float>(src[i * 3 + 2]) / 255.0F;
    }
    // Duplicate across other batches if batchSize_ > 1
    for (int64_t b = 1; b < batchSize_; ++b) {
        std::copy(inputBuffer_.begin(), inputBuffer_.begin() + singleImageSize,
                  inputBuffer_.begin() + b * singleImageSize);
    }
    gst_buffer_unmap(buffer, &map);

    const std::array<int64_t, 4> shape{batchSize_, 3, height, width};
    Ort::MemoryInfo memory = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    auto inputTensor = Ort::Value::CreateTensor<float>(memory, inputBuffer_.data(), inputBuffer_.size(), shape.data(), shape.size());
    const char* inputNames[] = {inputName_.c_str()};
    const char* outputNames[] = {outputName_.c_str()};

    std::vector<Ort::Value> outputs;
    try {
        outputs = session_->Run(Ort::RunOptions{nullptr}, inputNames, &inputTensor, 1, outputNames, 1);
    } catch (const Ort::Exception&) {
        result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
        return result;
    }
    if (outputs.empty() || !outputs[0].IsTensor()) {
        result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
        return result;
    }

    const auto info = outputs[0].GetTensorTypeAndShapeInfo();
    const auto outShape = info.GetShape();
    if (outShape.size() != 3) {
        result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
        return result;
    }

    const float* out = outputs[0].GetTensorData<float>();
    std::vector<Candidate> kept;

    if (outShape[2] == 6) {
        // NMS-Free YOLO26 format: (1, num_boxes, 6)
        const int numBoxes = static_cast<int>(outShape[1]);
        kept.reserve(std::min<size_t>(numBoxes, 100));
        for (int i = 0; i < numBoxes; ++i) {
            const float score = out[i * 6 + 4];
            if (score < static_cast<float>(config_.confidenceThreshold)) {
                continue;
            }
            const float rx1 = out[i * 6 + 0];
            const float ry1 = out[i * 6 + 1];
            const float rx2 = out[i * 6 + 2];
            const float ry2 = out[i * 6 + 3];
            kept.push_back({
                .classId = static_cast<int>(out[i * 6 + 5]),
                .score = score,
                .x1 = std::clamp(rx1 / static_cast<float>(width), 0.0F, 1.0F),
                .y1 = std::clamp(ry1 / static_cast<float>(height), 0.0F, 1.0F),
                .x2 = std::clamp(rx2 / static_cast<float>(width), 0.0F, 1.0F),
                .y2 = std::clamp(ry2 / static_cast<float>(height), 0.0F, 1.0F),
            });
            if (kept.size() >= 100) {
                break;
            }
        }
    } else {
        // Standard YOLOv8 / YOLO11 format: (1, channels, boxes)
        const int channels = static_cast<int>(outShape[1]);
        const int boxes = static_cast<int>(outShape[2]);
        if (channels < 5 || boxes < 1) {
            result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
            return result;
        }

        // Contiguous memory optimization to prevent cache misses and enable SIMD compiler vectorization
        std::vector<float> bestScores(static_cast<size_t>(boxes), 0.0F);
        std::vector<int> bestClasses(static_cast<size_t>(boxes), 0);

        for (int c = 4; c < channels; ++c) {
            const float* classRow = out + c * boxes;
            for (int box = 0; box < boxes; ++box) {
                const float score = classRow[box];
                if (score > bestScores[static_cast<size_t>(box)]) {
                    bestScores[static_cast<size_t>(box)] = score;
                    bestClasses[static_cast<size_t>(box)] = c - 4;
                }
            }
        }

        std::vector<Candidate> candidates;
        candidates.reserve(128);
        for (int box = 0; box < boxes; ++box) {
            const float score = bestScores[static_cast<size_t>(box)];
            if (score < static_cast<float>(config_.confidenceThreshold)) {
                continue;
            }
            const float cx = out[box];
            const float cy = out[boxes + box];
            const float bw = out[boxes * 2 + box];
            const float bh = out[boxes * 3 + box];
            candidates.push_back({
                .classId = bestClasses[static_cast<size_t>(box)],
                .score = score,
                .x1 = std::clamp((cx - bw / 2.0F) / static_cast<float>(width), 0.0F, 1.0F),
                .y1 = std::clamp((cy - bh / 2.0F) / static_cast<float>(height), 0.0F, 1.0F),
                .x2 = std::clamp((cx + bw / 2.0F) / static_cast<float>(width), 0.0F, 1.0F),
                .y2 = std::clamp((cy + bh / 2.0F) / static_cast<float>(height), 0.0F, 1.0F),
            });
        }

        std::sort(candidates.begin(), candidates.end(), [](const Candidate& a, const Candidate& b) {
            return a.score > b.score;
        });
        kept.reserve(std::min<size_t>(candidates.size(), 100));
        for (const auto& candidate : candidates) {
            bool suppressed = false;
            for (const auto& existing : kept) {
                if (candidate.classId == existing.classId
                    && intersectionOverUnion(candidate, existing) > static_cast<float>(config_.nmsThreshold)) {
                    suppressed = true;
                    break;
                }
            }
            if (!suppressed) {
                kept.push_back(candidate);
            }
            if (kept.size() >= 100) {
                break;
            }
        }
    }

    int matchedCount = 0;
    for (const auto& candidate : kept) {
        const auto label = candidate.classId >= 0 && candidate.classId < labels_.size()
            ? labels_[candidate.classId]
            : QString("class_%1").arg(candidate.classId);
        const bool matches = labelMatchesPart(label, partType, keywords);
        if (matches) {
            ++matchedCount;
            result.detections.append({
                .label = label,
                .confidence = candidate.score,
                .x = candidate.x1,
                .y = candidate.y1,
                .w = std::max(0.0F, candidate.x2 - candidate.x1),
                .h = std::max(0.0F, candidate.y2 - candidate.y1),
            });
        }
    }

    result.count = matchedCount;
    result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
    return result;
}

void OnnxYoloEngine::runInference(void* sample, const QString& partType, const QStringList& keywords)
{
    if (sample == nullptr) {
        return;
    }
    auto* gstSample = static_cast<GstSample*>(sample);
    const auto result = run(gstSample, partType, keywords);
    gst_sample_unref(gstSample);
    emit inferenceFinished(result);
}

void OnnxYoloEngine::reloadEngine(beenut::ModelConfig config)
{
    const bool success = reload(std::move(config));
    emit statusChanged(success, detail_, labels_);
}

}  // namespace beenut
