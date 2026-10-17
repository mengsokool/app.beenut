#include "ncnn_yolo_engine.h"
#include "ncnn_decode.h"

#ifdef ANDROID
#include "qt_compat.h"
#else
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QThread>
#include <QDebug>
#include <gst/video/video.h>
#endif

#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

namespace beenut {

bool NcnnYoloEngine::runtimeAvailable()
{
#if defined(BEENUT_HAS_NCNN)
    return true;
#else
    return false;
#endif
}

bool NcnnYoloEngine::gpuAvailable()
{
#if defined(BEENUT_HAS_NCNN) && NCNN_VULKAN
    return ncnn::get_gpu_count() > 0;
#else
    return false;
#endif
}

QString NcnnYoloEngine::resolvedBinPath(const ModelConfig& config)
{
    if (!config.ncnnBinPath.trimmed().isEmpty()) {
        return config.ncnnBinPath;
    }
    std::string path = config.modelPath.toUtf8().constData();
    if (path.size() >= 6 && path.substr(path.size() - 6) == ".param") {
        path.replace(path.size() - 6, 6, ".bin");
        return QString(path.c_str());
    }
    return {};
}

NcnnYoloEngine::NcnnYoloEngine(ModelConfig config, QObject* parent)
    : IInferenceEngine(parent),
      config_(std::move(config))
{
    qRegisterMetaType<beenut::Detection>("beenut::Detection");
    qRegisterMetaType<QVector<beenut::Detection>>("QVector<beenut::Detection>");
    qRegisterMetaType<beenut::InferenceResult>("beenut::InferenceResult");
    qRegisterMetaType<beenut::ModelConfig>("beenut::ModelConfig");

    reload(config_);
}

NcnnYoloEngine::~NcnnYoloEngine()
{
    std::lock_guard<std::mutex> lock(engineMutex_);
#if defined(BEENUT_HAS_NCNN)
    net_.clear();
#endif
}

bool NcnnYoloEngine::reload(ModelConfig config)
{
    std::lock_guard<std::mutex> lock(engineMutex_);
    config_ = std::move(config);
    labels_.clear();
    mockTick_ = 0;
    ready_ = false;
    detail_ = "not initialized";
    runtimeNotes_.clear();

#if defined(BEENUT_HAS_NCNN)
    net_.clear();
#endif

    if (config_.engine == "mock") {
        labels_ = {"target"};
        ready_ = true;
        detail_ = "mock inference active (NCNN engine profile)";
        return true;
    }

    if (config_.engine != "ncnn") {
        detail_ = QString("%1 engine requested, NcnnYoloEngine handles 'ncnn'").arg(config_.engine);
        return false;
    }

    if (!runtimeAvailable()) {
        detail_ = "NCNN runtime is not linked in this build";
        return false;
    }
    if (config_.ncnnDevice != "cpu" && config_.ncnnDevice != "gpu") {
        detail_ = "NCNN device must be cpu or gpu";
        return false;
    }
    if (config_.ncnnThreads < 1 || config_.ncnnThreads > 32) {
        detail_ = "NCNN threads must be between 1 and 32";
        return false;
    }
    if (config_.ncnnDevice == "gpu" && !gpuAvailable()) {
        detail_ = "NCNN GPU requested but Vulkan compute is unavailable";
        return false;
    }
    const QString paramPath = config_.modelPath;
    const QString binPath = resolvedBinPath(config_);
    if (!paramPath.endsWith(".param") || binPath.isEmpty()) {
        detail_ = "NCNN requires a .param model and .bin weights";
        return false;
    }
    const QFileInfo paramFile(paramPath);
    const QFileInfo binFile(binPath);

    // Attempt to load labels
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
    if (labels_.isEmpty()) {
        labels_ = {"target"};
    }

#if defined(BEENUT_HAS_NCNN)
    if (paramFile.exists() && binFile.exists()) {
        net_.opt.use_vulkan_compute = config_.ncnnDevice == "gpu";
        net_.opt.num_threads = std::clamp(config_.ncnnThreads, 1, std::max(1, QThread::idealThreadCount()));
        net_.opt.use_packing_layout = false;

        int retParam = net_.load_param(paramPath.toUtf8().constData());
        int retBin = net_.load_model(binPath.toUtf8().constData());

        if (retParam == 0 && retBin == 0) {
            ready_ = true;
            detail_ = QString("NCNN ready: %1 · %2 · %3 threads")
                          .arg(paramFile.fileName())
                          .arg(config_.ncnnDevice)
                          .arg(net_.opt.num_threads);
            return true;
        } else {
            detail_ = QString("NCNN load error (param: %1, bin: %2)").arg(retParam).arg(retBin);
            return false;
        }
    } else {
        detail_ = QString("NCNN model files missing (.param: %1, .bin: %2)").arg(paramFile.exists()).arg(binFile.exists());
        return false;
    }
#else
    detail_ = "NCNN runtime is not linked in this build";
    return false;
#endif
}

bool NcnnYoloEngine::isReady() const { return ready_; }
QString NcnnYoloEngine::detail() const { return detail_; }
QStringList NcnnYoloEngine::labels() const { return labels_; }

#ifndef ANDROID
InferenceResult NcnnYoloEngine::run(GstSample* sample, const QString& partType, const QStringList& keywords)
{
    QElapsedTimer timer;
    timer.start();

    InferenceResult result;
    if (!ready_ || sample == nullptr) {
        result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
        return result;
    }

    auto* buffer = gst_sample_get_buffer(sample);
    auto* caps = gst_sample_get_caps(sample);
    GstVideoInfo info;
    GstVideoFrame frame;
    if (!buffer || !caps || !gst_video_info_from_caps(&info, caps) ||
        GST_VIDEO_INFO_FORMAT(&info) != GST_VIDEO_FORMAT_RGB ||
        !gst_video_frame_map(&frame, &info, buffer, GST_MAP_READ)) return result;
    const int width = GST_VIDEO_FRAME_WIDTH(&frame), height = GST_VIDEO_FRAME_HEIGHT(&frame);
    const int stride = GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 0);
    const auto* src = static_cast<const unsigned char*>(GST_VIDEO_FRAME_PLANE_DATA(&frame, 0));
    if (stride < width * 3) {
        gst_video_frame_unmap(&frame);
        return result;
    }
    if (stride == width * 3) {
        result = run(src, width, height, partType, keywords);
    } else {
        rgbScratch_.resize(static_cast<size_t>(width) * height * 3);
        for (int y = 0; y < height; ++y)
            std::memcpy(rgbScratch_.data() + static_cast<size_t>(y)*width*3, src + static_cast<size_t>(y)*stride, width*3);
        result = run(rgbScratch_.data(), width, height, partType, keywords);
    }
    gst_video_frame_unmap(&frame);
    return result;
}
#endif

InferenceResult NcnnYoloEngine::run(const unsigned char* rgbData, int width, int height, const QString& partType, const QStringList& keywords)
{
    std::lock_guard<std::mutex> lock(engineMutex_);
    QElapsedTimer timer;
    timer.start();

    InferenceResult result;
    if (!ready_ || rgbData == nullptr) {
        result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
        return result;
    }

    if (config_.engine == "mock") {
        ++mockTick_;
        const int count = 8;
        const auto label = partType.isEmpty() ? labels_.value(0, "target") : partType;
        result.count = count;
        result.processingMs = 3;
        result.detections.reserve(count);
        for (int i = 0; i < count; ++i) {
            const double jitter = ((mockTick_ + i) % 5) * 0.002;
            result.detections.append({
                .label = label,
                .confidence = 0.88 + (i % 3) * 0.03,
                .x = 0.15 + (i % 4) * 0.18 + jitter,
                .y = 0.20 + (i / 4) * 0.25 + jitter,
                .w = 0.08,
                .h = 0.08,
            });
        }
        return result;
    }

#if defined(BEENUT_HAS_NCNN)
    ncnn::Mat in = ncnn::Mat::from_pixels_resize(rgbData, ncnn::Mat::PIXEL_RGB, width, height, config_.inputSize, config_.inputSize);
    const float norm_vals[3] = {1 / 255.f, 1 / 255.f, 1 / 255.f};
    in.substract_mean_normalize(0, norm_vals);

    ncnn::Extractor ex = net_.create_extractor();
    ncnn::Mat out;
    if (ex.input("in0", in) != 0 || ex.extract("out0", out) != 0 ||
        out.empty() || out.elempack != 1 || out.elemsize != sizeof(float) ||
        (out.dims != 2 && !(out.dims == 3 && out.c == 1))) {
        ready_ = false;
        detail_ = "NCNN inference failed: expected in0/out0 and a float YOLO output tensor";
#ifndef ANDROID
        emit statusChanged(false, detail_, labels_);
#endif
        result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
        return result;
    }
    QString error;
    result = decodeNcnnYolo(static_cast<const float*>(out.data), out.h, out.w,
                            config_, labels_, partType, keywords, &error);
    if (!error.isEmpty()) {
        ready_ = false;
        detail_ = error;
#ifndef ANDROID
        emit statusChanged(false, detail_, labels_);
#endif
    }
#else

#endif

    result.processingMs = qMax(1, static_cast<int>(timer.elapsed()));
    return result;
}

#ifndef ANDROID
void NcnnYoloEngine::runInference(void* sample, const QString& partType, const QStringList& keywords)
{
    if (sample == nullptr) {
        return;
    }
    auto* gstSample = static_cast<GstSample*>(sample);
    const auto result = run(gstSample, partType, keywords);
    gst_sample_unref(gstSample);
    emit inferenceFinished(result);
}

void NcnnYoloEngine::reloadEngine(beenut::ModelConfig config)
{
    const bool success = reload(std::move(config));
    emit statusChanged(success, detail_, labels_);
}
#endif

}  // namespace beenut
