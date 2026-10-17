#include "ffi_api.h"
#include "engine_factory.h"
#include "app_config.h"

#ifndef ANDROID
#include <QString>
#include <QStringList>
#endif
#include <cstring>

extern "C" {

BEENUT_EXPORT void* beenut_engine_init(const char* model_path, const char* labels_path, float confidence_threshold, float iou_threshold)
{
    beenut::ModelConfig config;
    config.modelPath = QString::fromUtf8(model_path);
    if (config.modelPath.endsWith(".param", Qt::CaseInsensitive) || config.modelPath.endsWith(".bin", Qt::CaseInsensitive)) {
        config.engine = "ncnn";
    } else {
        config.engine = "onnx";
    }
    config.labelsMode = labels_path && strlen(labels_path) > 0 ? "custom" : "auto";
    config.labelsPath = QString::fromUtf8(labels_path ? labels_path : "");
    config.confidenceThreshold = confidence_threshold;
    config.nmsThreshold = iou_threshold;

    auto engine = beenut::createInferenceEngine(config);
    return static_cast<void*>(engine.release());
}

BEENUT_EXPORT bool beenut_engine_is_ready(void* engine_handle)
{
    if (engine_handle == nullptr) {
        return false;
    }
    auto* engine = static_cast<beenut::IInferenceEngine*>(engine_handle);
    return engine->isReady();
}

BEENUT_EXPORT const char* beenut_engine_get_detail(void* engine_handle)
{
    if (engine_handle == nullptr) {
        return "Engine handle is null";
    }
    auto* engine = static_cast<beenut::IInferenceEngine*>(engine_handle);
    // Return a thread-safe static string or buffer for detail info
    static char detail_buffer[512];
    const QByteArray utf8 = engine->detail().toUtf8();
    std::strncpy(detail_buffer, utf8.constData(), sizeof(detail_buffer) - 1);
    detail_buffer[sizeof(detail_buffer) - 1] = '\0';
    return detail_buffer;
}

BEENUT_EXPORT const char* beenut_engine_get_labels_json(void* engine_handle)
{
    if (engine_handle == nullptr) {
        return "[]";
    }
    auto* engine = static_cast<beenut::IInferenceEngine*>(engine_handle);
    const auto labels = engine->labels();

    static char labels_buffer[8192];
    std::string json = "[";
    for (size_t i = 0; i < static_cast<size_t>(labels.size()); ++i) {
        json += "\"";
        const std::string s = labels[i].toUtf8().constData();
        for (char c : s) {
            if (c == '"') json += "\\\"";
            else if (c == '\\') json += "\\\\";
            else json += c;
        }
        json += "\"";
        if (i + 1 < static_cast<size_t>(labels.size())) json += ",";
    }
    json += "]";

    std::strncpy(labels_buffer, json.c_str(), sizeof(labels_buffer) - 1);
    labels_buffer[sizeof(labels_buffer) - 1] = '\0';
    return labels_buffer;
}

BEENUT_EXPORT FFIInferenceResult beenut_engine_run(void* engine_handle, const unsigned char* rgb_data, int width, int height, const char* part_type, const char* keywords)
{
    FFIInferenceResult ffi_result = {};
    if (engine_handle == nullptr) {
        ffi_result.processingMs = 0;
        return ffi_result;
    }

    auto* engine = static_cast<beenut::IInferenceEngine*>(engine_handle);
    const QString q_part_type = QString::fromUtf8(part_type ? part_type : "");

    QStringList q_keywords;
    if (keywords && strlen(keywords) > 0) {
        const QString keywords_str = QString::fromUtf8(keywords);
        q_keywords = keywords_str.split(',', Qt::SkipEmptyParts);
    }

    const beenut::InferenceResult result = engine->run(rgb_data, width, height, q_part_type, q_keywords);

    ffi_result.count = result.count;
    ffi_result.processingMs = result.processingMs;
    ffi_result.detectionsCount = std::min(static_cast<int>(result.detections.size()), 128);

    for (int i = 0; i < ffi_result.detectionsCount; ++i) {
        const auto& det = result.detections[i];
        FFIDetection& ffi_det = ffi_result.detections[i];

        const QByteArray label_utf8 = det.label.toUtf8();
        std::strncpy(ffi_det.label, label_utf8.constData(), sizeof(ffi_det.label) - 1);
        ffi_det.label[sizeof(ffi_det.label) - 1] = '\0';

        ffi_det.confidence = det.confidence;
        ffi_det.x = det.x;
        ffi_det.y = det.y;
        ffi_det.w = det.w;
        ffi_det.h = det.h;
    }

    return ffi_result;
}

BEENUT_EXPORT void beenut_yuv420_to_rgb(
    const unsigned char* y_plane,
    const unsigned char* u_plane,
    const unsigned char* v_plane,
    int y_row_stride,
    int uv_row_stride,
    int uv_pixel_stride,
    int width,
    int height,
    unsigned char* rgb_out
) {
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            int y_index = y * y_row_stride + x;
            int uv_index = (y / 2) * uv_row_stride + (x / 2) * uv_pixel_stride;

            int Y = y_plane[y_index];
            int U = u_plane[uv_index] - 128;
            int V = v_plane[uv_index] - 128;

            int R = Y + 1.402 * V;
            int G = Y - 0.344 * U - 0.714 * V;
            int B = Y + 1.772 * U;

            int r_idx = (y * width + x) * 3;
            rgb_out[r_idx]     = R < 0 ? 0 : (R > 255 ? 255 : R);
            rgb_out[r_idx + 1] = G < 0 ? 0 : (G > 255 ? 255 : G);
            rgb_out[r_idx + 2] = B < 0 ? 0 : (B > 255 ? 255 : B);
        }
    }
}

BEENUT_EXPORT void beenut_engine_free(void* engine_handle)
{
    if (engine_handle != nullptr) {
        auto* engine = static_cast<beenut::IInferenceEngine*>(engine_handle);
        delete engine;
    }
}

}
