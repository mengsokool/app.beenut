#pragma once

#ifdef _WIN32
#define BEENUT_EXPORT __declspec(dllexport)
#else
#define BEENUT_EXPORT __attribute__((visibility("default")))
#endif

extern "C" {

struct FFIDetection {
    char label[128];
    float confidence;
    float x;
    float y;
    float w;
    float h;
};

struct FFIInferenceResult {
    int count;
    int processingMs;
    int detectionsCount;
    FFIDetection detections[128];
};

BEENUT_EXPORT void* beenut_engine_init(const char* model_path, const char* labels_path, float confidence_threshold, float iou_threshold);

BEENUT_EXPORT bool beenut_engine_is_ready(void* engine_handle);

BEENUT_EXPORT const char* beenut_engine_get_detail(void* engine_handle);

BEENUT_EXPORT const char* beenut_engine_get_labels_json(void* engine_handle);

BEENUT_EXPORT FFIInferenceResult beenut_engine_run(void* engine_handle, const unsigned char* rgb_data, int width, int height, const char* part_type, const char* keywords);

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
);

BEENUT_EXPORT void beenut_engine_free(void* engine_handle);

}
