#pragma once

#include <jni.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <camera/NdkCameraManager.h>
#include <camera/NdkCameraDevice.h>
#include <camera/NdkCameraMetadata.h>
#include <camera/NdkCaptureRequest.h>
#include <camera/NdkCameraCaptureSession.h>
#include <media/NdkImageReader.h>

#include <atomic>
#include <condition_variable>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace beenut {

// Struct to hold raw plane data for background worker thread
struct PendingFrame {
    std::vector<uint8_t> yData;
    std::vector<uint8_t> uData;
    std::vector<uint8_t> vData;
    int32_t width = 0;
    int32_t height = 0;
    int32_t yRowStride = 0;
    int32_t uvRowStride = 0;
    int32_t uvPixelStride = 0;
    int64_t timestamp = 0;
    bool hasData = false;
};

// Singleton Native Camera manager for Android NDK
class NdkCameraEngine {
public:
    static NdkCameraEngine& instance();

    void setPreviewSurface(JNIEnv* env, jobject surface);
    void clearPreviewSurface();
    bool startCamera(JNIEnv* env, jobject pluginObj, const char* cameraId = nullptr);
    void stopCamera();
    void updateEngineSettings(void* engineHandle, const char* partType, const char* keywords, double maxFps = 6.0);

    // Callbacks for JNI
    void onImageAvailable(AImageReader* reader);

private:
    NdkCameraEngine() = default;
    ~NdkCameraEngine();

    void closeCamera();
    void restartCaptureSessionLocked();
    void inferenceWorkerLoop();
    void stopWorkerThread();

    // JNI Callback reference
    JavaVM* javaVM_ = nullptr;
    jobject pluginGlobalRef_ = nullptr;
    jmethodID onDetectionsAvailableMethod_ = nullptr;

    // ACamera NDK members
    ACameraManager* cameraManager_ = nullptr;
    ACameraDevice* cameraDevice_ = nullptr;
    ACameraOutputTarget* previewTarget_ = nullptr;
    ACameraOutputTarget* inferenceTarget_ = nullptr;
    ACaptureRequest* captureRequest_ = nullptr;
    ACameraCaptureSession* captureSession_ = nullptr;
    ACaptureSessionOutputContainer* outputsContainer_ = nullptr;
    ACaptureSessionOutput* previewOutput_ = nullptr;
    ACaptureSessionOutput* inferenceOutput_ = nullptr;

    ANativeWindow* previewWindow_ = nullptr;
    AImageReader* imageReader_ = nullptr;
    ANativeWindow* imageReaderWindow_ = nullptr;

    std::string cameraId_;

    // Settings
    std::mutex engineMutex_;
    void* activeEngineHandle_ = nullptr;
    std::string activePartType_;
    std::vector<std::string> activeKeywords_;
    double activeMaxFps_ = 6.0;

    // Background inference worker thread & decoupling queue
    std::thread inferenceThread_;
    std::mutex frameMutex_;
    std::condition_variable frameCv_;
    std::atomic<bool> workerRunning_{false};
    std::atomic<bool> inferenceBusy_{false};
    PendingFrame pendingFrame_;

    // FPS Throttling & Reusable Preprocessing Buffer
    int64_t lastInferenceTimeNs_ = 0;
    std::vector<uint8_t> rgbBuffer_;
    std::atomic<bool> isCameraRunning_{false};
};

} // namespace beenut
