#include "ndk_camera_engine.h"
#include "inference_engine.h"
#include <android/log.h>
#include <chrono>
#include <climits>
#include <cstdlib>
#include <sys/resource.h>
#if defined(__ARM_NEON) || defined(__aarch64__)
#include <arm_neon.h>
#endif

#define LOG_TAG "BeenutCameraEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace beenut {

// Global bindings structure
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

}

NdkCameraEngine& NdkCameraEngine::instance() {
    static NdkCameraEngine inst;
    return inst;
}

NdkCameraEngine::~NdkCameraEngine() {
    stopCamera();
    clearPreviewSurface();
}

static void onDeviceDisconnected(void* /*context*/, ACameraDevice* /*device*/) {
    LOGI("Camera device disconnected");
}

static void onDeviceError(void* /*context*/, ACameraDevice* /*device*/, int error) {
    LOGE("Camera device error: %d", error);
}

static void onSessionActive(void* /*context*/, ACameraCaptureSession* /*session*/) {
    LOGI("Session active");
}

static void onSessionReady(void* /*context*/, ACameraCaptureSession* /*session*/) {
    LOGI("Session ready");
}

static void onSessionClosed(void* /*context*/, ACameraCaptureSession* /*session*/) {
    LOGI("Session closed");
}

static void chooseSupportedFpsRange(
    ACameraManager* manager,
    const std::string& cameraId,
    int32_t range[2]
) {
    ACameraMetadata* metadata = nullptr;
    if (ACameraManager_getCameraCharacteristics(manager, cameraId.c_str(), &metadata) != ACAMERA_OK ||
        metadata == nullptr) {
        return;
    }

    ACameraMetadata_const_entry entry;
    if (ACameraMetadata_getConstEntry(
            metadata,
            ACAMERA_CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES,
            &entry
        ) == ACAMERA_OK) {
        int bestScore = INT_MAX;
        for (uint32_t i = 0; i + 1 < entry.count; i += 2) {
            const int32_t minimum = entry.data.i32[i];
            const int32_t maximum = entry.data.i32[i + 1];
            if (minimum <= 0 || maximum < minimum) continue;
            // Prefer a range containing 30fps, otherwise the closest usable max.
            const int score = (minimum <= 30 && maximum >= 30)
                ? 0
                : std::abs(maximum - 30) + 100;
            if (score < bestScore) {
                bestScore = score;
                range[0] = minimum;
                range[1] = maximum;
            }
        }
    }
    ACameraMetadata_free(metadata);
}

void NdkCameraEngine::setPreviewSurface(JNIEnv* env, jobject surface) {
    std::lock_guard<std::mutex> lock(engineMutex_);
    if (previewWindow_ != nullptr) {
        ANativeWindow_release(previewWindow_);
        previewWindow_ = nullptr;
    }
    if (surface != nullptr) {
        previewWindow_ = ANativeWindow_fromSurface(env, surface);
        LOGI("Native preview window set successfully from Surface");
        if (isCameraRunning_.load() && cameraDevice_ != nullptr) {
            restartCaptureSessionLocked();
        }
    }
}

void NdkCameraEngine::restartCaptureSessionLocked() {
    if (cameraDevice_ == nullptr) return;

    if (captureSession_ != nullptr) {
        ACameraCaptureSession_stopRepeating(captureSession_);
        ACameraCaptureSession_close(captureSession_);
        captureSession_ = nullptr;
    }

    if (captureRequest_ != nullptr) {
        if (previewTarget_ != nullptr) {
            ACaptureRequest_removeTarget(captureRequest_, previewTarget_);
            ACameraOutputTarget_free(previewTarget_);
            previewTarget_ = nullptr;
        }
        if (inferenceTarget_ != nullptr) {
            ACaptureRequest_removeTarget(captureRequest_, inferenceTarget_);
            ACameraOutputTarget_free(inferenceTarget_);
            inferenceTarget_ = nullptr;
        }
        ACaptureRequest_free(captureRequest_);
        captureRequest_ = nullptr;
    }

    if (outputsContainer_ != nullptr) {
        if (previewOutput_ != nullptr) {
            ACaptureSessionOutputContainer_remove(outputsContainer_, previewOutput_);
            ACaptureSessionOutput_free(previewOutput_);
            previewOutput_ = nullptr;
        }
        if (inferenceOutput_ != nullptr) {
            ACaptureSessionOutputContainer_remove(outputsContainer_, inferenceOutput_);
            ACaptureSessionOutput_free(inferenceOutput_);
            inferenceOutput_ = nullptr;
        }
        ACaptureSessionOutputContainer_free(outputsContainer_);
        outputsContainer_ = nullptr;
    }

    ACaptureSessionOutputContainer_create(&outputsContainer_);

    if (previewWindow_ != nullptr) {
        ACaptureSessionOutput_create(previewWindow_, &previewOutput_);
        ACaptureSessionOutputContainer_add(outputsContainer_, previewOutput_);
    }

    if (imageReaderWindow_ != nullptr) {
        ACaptureSessionOutput_create(imageReaderWindow_, &inferenceOutput_);
        ACaptureSessionOutputContainer_add(outputsContainer_, inferenceOutput_);
    }

    ACameraDevice_createCaptureRequest(cameraDevice_, TEMPLATE_PREVIEW, &captureRequest_);

    if (previewWindow_ != nullptr) {
        ACameraOutputTarget_create(previewWindow_, &previewTarget_);
        ACaptureRequest_addTarget(captureRequest_, previewTarget_);
    }

    if (imageReaderWindow_ != nullptr) {
        ACameraOutputTarget_create(imageReaderWindow_, &inferenceTarget_);
        ACaptureRequest_addTarget(captureRequest_, inferenceTarget_);
    }

    int32_t fpsRange[2] = {15, 30};
    chooseSupportedFpsRange(cameraManager_, cameraId_, fpsRange);
    ACaptureRequest_setEntry_i32(captureRequest_, ACAMERA_CONTROL_AE_TARGET_FPS_RANGE, 2, fpsRange);
    const uint8_t afMode = ACAMERA_CONTROL_AF_MODE_CONTINUOUS_PICTURE;
    const uint8_t aeMode = ACAMERA_CONTROL_AE_MODE_ON;
    const uint8_t awbMode = ACAMERA_CONTROL_AWB_MODE_AUTO;
    ACaptureRequest_setEntry_u8(captureRequest_, ACAMERA_CONTROL_AF_MODE, 1, &afMode);
    ACaptureRequest_setEntry_u8(captureRequest_, ACAMERA_CONTROL_AE_MODE, 1, &aeMode);
    ACaptureRequest_setEntry_u8(captureRequest_, ACAMERA_CONTROL_AWB_MODE, 1, &awbMode);

    ACameraCaptureSession_stateCallbacks sessionCallbacks = {
        .context = this,
        .onClosed = onSessionClosed,
        .onReady = onSessionReady,
        .onActive = onSessionActive,
    };

    camera_status_t status = ACameraDevice_createCaptureSession(
        cameraDevice_,
        outputsContainer_,
        &sessionCallbacks,
        &captureSession_
    );

    if (status == ACAMERA_OK && captureSession_ != nullptr) {
        ACameraCaptureSession_setRepeatingRequest(
            captureSession_,
            nullptr,
            1,
            &captureRequest_,
            nullptr
        );
        LOGI("Native NDK camera capture session restarted with preview surface");
    }
}

void NdkCameraEngine::clearPreviewSurface() {
    std::lock_guard<std::mutex> lock(engineMutex_);
    if (previewWindow_ != nullptr) {
        ANativeWindow_release(previewWindow_);
        previewWindow_ = nullptr;
        LOGI("Native preview window cleared");
        // Do not keep Camera2 repeating into a released Flutter surface.
        if (isCameraRunning_.load() && cameraDevice_ != nullptr) {
            restartCaptureSessionLocked();
        }
    }
}

void NdkCameraEngine::updateEngineSettings(void* engineHandle, const char* partType, const char* keywords, double maxFps) {
    std::lock_guard<std::mutex> lock(engineMutex_);
    activeEngineHandle_ = engineHandle;
    activePartType_ = partType ? partType : "";
    activeMaxFps_ = maxFps > 0.0 ? maxFps : 15.0;

    activeKeywords_.clear();
    if (keywords && strlen(keywords) > 0) {
        std::string kwStr(keywords);
        size_t start = 0;
        size_t end = kwStr.find(',');
        while (end != std::string::npos) {
            activeKeywords_.push_back(kwStr.substr(start, end - start));
            start = end + 1;
            end = kwStr.find(',', start);
        }
        activeKeywords_.push_back(kwStr.substr(start));
    }
    LOGI("Engine settings updated: handle=%p, partType=%s, maxFps=%.1f", activeEngineHandle_, activePartType_.c_str(), activeMaxFps_);
}

bool NdkCameraEngine::startCamera(JNIEnv* env, jobject pluginObj, const char* cameraId) {
    stopCamera();

    std::lock_guard<std::mutex> lock(engineMutex_);

    // Set thread priority to high-performance media processing
    setpriority(PRIO_PROCESS, 0, -8);

    env->GetJavaVM(&javaVM_);
    pluginGlobalRef_ = env->NewGlobalRef(pluginObj);
    jclass pluginClass = env->GetObjectClass(pluginObj);
    onDetectionsAvailableMethod_ = env->GetMethodID(
        pluginClass,
        "onDetectionsAvailable",
        "(II[D[Ljava/lang/String;)V"
    );

    if (onDetectionsAvailableMethod_ == nullptr) {
        LOGE("Could not find onDetectionsAvailable callback on plugin object");
        return false;
    }

    cameraManager_ = ACameraManager_create();
    if (cameraManager_ == nullptr) {
        LOGE("Failed to create ACameraManager");
        return false;
    }

    ACameraIdList* idList = nullptr;
    ACameraManager_getCameraIdList(cameraManager_, &idList);
    if (idList == nullptr || idList->numCameras == 0) {
        LOGE("No cameras found on device");
        if (idList) ACameraManager_deleteCameraIdList(idList);
        return false;
    }

    if (cameraId != nullptr && std::strlen(cameraId) > 0) {
        cameraId_ = cameraId;
    } else {
        // Fallback: Select the back camera
        cameraId_ = idList->cameraIds[0];
        for (int i = 0; i < idList->numCameras; ++i) {
            const char* id = idList->cameraIds[i];
            ACameraMetadata* metadata = nullptr;
            ACameraManager_getCameraCharacteristics(cameraManager_, id, &metadata);
            if (metadata != nullptr) {
                acamera_metadata_tag_t lensTag = ACAMERA_LENS_FACING;
                ACameraMetadata_const_entry entry;
                ACameraMetadata_getConstEntry(metadata, lensTag, &entry);
                if (entry.data.u8[0] == ACAMERA_LENS_FACING_BACK) {
                    cameraId_ = id;
                    ACameraMetadata_free(metadata);
                    break;
                }
                ACameraMetadata_free(metadata);
            }
        }
    }
    ACameraManager_deleteCameraIdList(idList);

    // Set up camera state callbacks
    ACameraDevice_StateCallbacks deviceCallbacks = {
        .context = this,
        .onDisconnected = onDeviceDisconnected,
        .onError = onDeviceError,
    };

    camera_status_t status = ACameraManager_openCamera(
        cameraManager_,
        cameraId_.c_str(),
        &deviceCallbacks,
        &cameraDevice_
    );

    if (status != ACAMERA_OK || cameraDevice_ == nullptr) {
        LOGE("Failed to open camera: %d", status);
        return false;
    }

    // Create ImageReader for inference at 640x480 (4:3 aspect ratio)
    media_status_t mStatus = AImageReader_new(
        640,
        480,
        AIMAGE_FORMAT_YUV_420_888,
        3,
        &imageReader_
    );

    if (mStatus != AMEDIA_OK || imageReader_ == nullptr) {
        LOGE("Failed to create AImageReader: %d", mStatus);
        return false;
    }

    // Set ImageReader Listener callback
    AImageReader_ImageListener listener = {
        .context = this,
        .onImageAvailable = [](void* context, AImageReader* reader) {
            static_cast<NdkCameraEngine*>(context)->onImageAvailable(reader);
        }
    };
    AImageReader_setImageListener(imageReader_, &listener);

    AImageReader_getWindow(imageReader_, &imageReaderWindow_);

    // Prepare outputs container
    ACaptureSessionOutputContainer_create(&outputsContainer_);

    // 1. Add preview output if surface is ready
    if (previewWindow_ != nullptr) {
        ACaptureSessionOutput_create(previewWindow_, &previewOutput_);
        ACaptureSessionOutputContainer_add(outputsContainer_, previewOutput_);
    }

    // 2. Add inference output
    ACaptureSessionOutput_create(imageReaderWindow_, &inferenceOutput_);
    ACaptureSessionOutputContainer_add(outputsContainer_, inferenceOutput_);

    // Create Capture request
    ACameraDevice_createCaptureRequest(
        cameraDevice_,
        TEMPLATE_PREVIEW,
        &captureRequest_
    );

    if (previewWindow_ != nullptr) {
        ACameraOutputTarget_create(previewWindow_, &previewTarget_);
        ACaptureRequest_addTarget(captureRequest_, previewTarget_);
    }

    ACameraOutputTarget_create(imageReaderWindow_, &inferenceTarget_);
    ACaptureRequest_addTarget(captureRequest_, inferenceTarget_);

    // Camera2 frame-rate ranges vary across devices; use an advertised range.
    int32_t fpsRange[2] = {15, 30};
    chooseSupportedFpsRange(cameraManager_, cameraId_, fpsRange);
    ACaptureRequest_setEntry_i32(captureRequest_, ACAMERA_CONTROL_AE_TARGET_FPS_RANGE, 2, fpsRange);
    const uint8_t afMode = ACAMERA_CONTROL_AF_MODE_CONTINUOUS_PICTURE;
    const uint8_t aeMode = ACAMERA_CONTROL_AE_MODE_ON;
    const uint8_t awbMode = ACAMERA_CONTROL_AWB_MODE_AUTO;
    ACaptureRequest_setEntry_u8(captureRequest_, ACAMERA_CONTROL_AF_MODE, 1, &afMode);
    ACaptureRequest_setEntry_u8(captureRequest_, ACAMERA_CONTROL_AE_MODE, 1, &aeMode);
    ACaptureRequest_setEntry_u8(captureRequest_, ACAMERA_CONTROL_AWB_MODE, 1, &awbMode);

    // Create Session
    ACameraCaptureSession_stateCallbacks sessionCallbacks = {
        .context = this,
        .onClosed = onSessionClosed,
        .onReady = onSessionReady,
        .onActive = onSessionActive,
    };

    status = ACameraDevice_createCaptureSession(
        cameraDevice_,
        outputsContainer_,
        &sessionCallbacks,
        &captureSession_
    );

    if (status != ACAMERA_OK) {
        LOGE("Failed to create camera capture session: %d", status);
        return false;
    }

    // Start repeating request
    ACameraCaptureSession_setRepeatingRequest(
        captureSession_,
        nullptr,
        1,
        &captureRequest_,
        nullptr
    );

    isCameraRunning_.store(true);
    workerRunning_.store(true);
    inferenceThread_ = std::thread(&NdkCameraEngine::inferenceWorkerLoop, this);
    LOGI("Native NDK camera session started successfully with background worker");
    return true;
}

void NdkCameraEngine::stopCamera() {
    closeCamera();
}

void NdkCameraEngine::stopWorkerThread() {
    workerRunning_.store(false);
    frameCv_.notify_all();
    if (inferenceThread_.joinable()) {
        inferenceThread_.join();
    }
}

void NdkCameraEngine::closeCamera() {
    stopWorkerThread();

    ACameraCaptureSession* session = nullptr;
    ACaptureRequest* request = nullptr;
    ACaptureSessionOutputContainer* container = nullptr;
    ACaptureSessionOutput* prevOutput = nullptr;
    ACaptureSessionOutput* infOutput = nullptr;
    ACameraOutputTarget* prevTarget = nullptr;
    ACameraOutputTarget* infTarget = nullptr;
    AImageReader* reader = nullptr;
    ACameraDevice* device = nullptr;
    ACameraManager* manager = nullptr;
    JavaVM* jvm = nullptr;
    jobject pluginRef = nullptr;

    {
        std::lock_guard<std::mutex> lock(engineMutex_);
        isCameraRunning_.store(false);

        session = captureSession_; captureSession_ = nullptr;
        request = captureRequest_; captureRequest_ = nullptr;
        container = outputsContainer_; outputsContainer_ = nullptr;
        prevOutput = previewOutput_; previewOutput_ = nullptr;
        infOutput = inferenceOutput_; inferenceOutput_ = nullptr;
        prevTarget = previewTarget_; previewTarget_ = nullptr;
        infTarget = inferenceTarget_; inferenceTarget_ = nullptr;
        reader = imageReader_; imageReader_ = nullptr;
        imageReaderWindow_ = nullptr;
        device = cameraDevice_; cameraDevice_ = nullptr;
        manager = cameraManager_; cameraManager_ = nullptr;
        jvm = javaVM_; javaVM_ = nullptr;
        pluginRef = pluginGlobalRef_; pluginGlobalRef_ = nullptr;
        onDetectionsAvailableMethod_ = nullptr;
    }

    if (reader != nullptr) {
        AImageReader_setImageListener(reader, nullptr);
    }

    if (session != nullptr) {
        ACameraCaptureSession_stopRepeating(session);
        ACameraCaptureSession_close(session);
    }

    if (request != nullptr) {
        if (prevTarget != nullptr) {
            ACaptureRequest_removeTarget(request, prevTarget);
            ACameraOutputTarget_free(prevTarget);
        }
        if (infTarget != nullptr) {
            ACaptureRequest_removeTarget(request, infTarget);
            ACameraOutputTarget_free(infTarget);
        }
        ACaptureRequest_free(request);
    }

    if (container != nullptr) {
        if (prevOutput != nullptr) {
            ACaptureSessionOutputContainer_remove(container, prevOutput);
            ACaptureSessionOutput_free(prevOutput);
        }
        if (infOutput != nullptr) {
            ACaptureSessionOutputContainer_remove(container, infOutput);
            ACaptureSessionOutput_free(infOutput);
        }
        ACaptureSessionOutputContainer_free(container);
    }

    if (reader != nullptr) {
        AImageReader_delete(reader);
    }

    if (device != nullptr) {
        ACameraDevice_close(device);
    }

    if (manager != nullptr) {
        ACameraManager_delete(manager);
    }

    if (jvm != nullptr && pluginRef != nullptr) {
        JNIEnv* env = nullptr;
        if (jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_OK && env != nullptr) {
            env->DeleteGlobalRef(pluginRef);
        }
    }

    LOGI("Native NDK camera resources released safely");
}

void NdkCameraEngine::onImageAvailable(AImageReader* reader) {
    if (!isCameraRunning_.load() || !workerRunning_.load()) {
        return;
    }
    AImage* image = nullptr;
    media_status_t status = AImageReader_acquireLatestImage(reader, &image);
    if (status != AMEDIA_OK || image == nullptr) {
        return;
    }

    // Wrap resources in RAII style to release the image buffer back to Camera2 HAL immediately
    struct ImageAutoReleaser {
        AImage* img;
        ~ImageAutoReleaser() { if (img) AImage_delete(img); }
    } releaser{image};

    // Quick check to skip processing if engine isn't ready
    {
        std::lock_guard<std::mutex> lock(engineMutex_);
        if (activeEngineHandle_ == nullptr) {
            return;
        }
    }

    int64_t timestamp = 0;
    AImage_getTimestamp(image, &timestamp);

    // Respect max_fps throttle configuration
    const double maxFps = activeMaxFps_;
    const int64_t intervalNs = static_cast<int64_t>(1000000000.0 / (maxFps > 0.0 ? maxFps : 6.0));
    if (lastInferenceTimeNs_ > 0 && (timestamp - lastInferenceTimeNs_) < intervalNs) {
        return;
    }

    // If the background worker is still busy processing a previous frame,
    // drop this frame immediately to keep zero-latency freshness.
    if (inferenceBusy_.load()) {
        return;
    }

    // Retrieve YUV plane details
    int32_t yLen = 0, uLen = 0, vLen = 0;
    uint8_t *yData = nullptr, *uData = nullptr, *vData = nullptr;
    AImage_getPlaneData(image, 0, &yData, &yLen);
    AImage_getPlaneData(image, 1, &uData, &uLen);
    AImage_getPlaneData(image, 2, &vData, &vLen);

    int32_t yRowStride = 0, uvRowStride = 0, uvPixelStride = 0;
    AImage_getPlaneRowStride(image, 0, &yRowStride);
    AImage_getPlaneRowStride(image, 1, &uvRowStride);
    AImage_getPlanePixelStride(image, 1, &uvPixelStride);

    int32_t width = 0, height = 0;
    AImage_getWidth(image, &width);
    AImage_getHeight(image, &height);

    if (width <= 0 || height <= 0 || yData == nullptr || uData == nullptr || vData == nullptr ||
        yLen <= 0 || uLen <= 0 || vLen <= 0) {
        return;
    }

    // Fast memory copy into pendingFrame_ (< 0.5ms) so AImage can be deleted immediately
    {
        std::lock_guard<std::mutex> lock(frameMutex_);
        if (pendingFrame_.yData.size() != static_cast<size_t>(yLen)) {
            pendingFrame_.yData.resize(yLen);
        }
        if (pendingFrame_.uData.size() != static_cast<size_t>(uLen)) {
            pendingFrame_.uData.resize(uLen);
        }
        if (pendingFrame_.vData.size() != static_cast<size_t>(vLen)) {
            pendingFrame_.vData.resize(vLen);
        }
        std::memcpy(pendingFrame_.yData.data(), yData, yLen);
        std::memcpy(pendingFrame_.uData.data(), uData, uLen);
        std::memcpy(pendingFrame_.vData.data(), vData, vLen);
        pendingFrame_.width = width;
        pendingFrame_.height = height;
        pendingFrame_.yRowStride = yRowStride;
        pendingFrame_.uvRowStride = uvRowStride;
        pendingFrame_.uvPixelStride = uvPixelStride;
        pendingFrame_.timestamp = timestamp;
        pendingFrame_.hasData = true;
    }

    lastInferenceTimeNs_ = timestamp;
    frameCv_.notify_one();
    // releaser destructor deletes AImage immediately, releasing buffer back to camera HAL
}

void NdkCameraEngine::inferenceWorkerLoop() {
    JNIEnv* env = nullptr;
    bool attached = false;
    if (javaVM_ != nullptr) {
        jint res = javaVM_->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
        if (res == JNI_EDETACHED) {
            if (javaVM_->AttachCurrentThread(&env, nullptr) == 0) {
                attached = true;
            }
        }
    }

    PendingFrame localFrame;
    int xLookup[640];
    int uvXLookup[640];
    int lastCropSize = 0;
    int lastStartX = -1;

    while (workerRunning_.load()) {
        {
            std::unique_lock<std::mutex> lock(frameMutex_);
            frameCv_.wait(lock, [this]() {
                return !workerRunning_.load() || pendingFrame_.hasData;
            });
            if (!workerRunning_.load()) {
                break;
            }
            localFrame = std::move(pendingFrame_);
            pendingFrame_.hasData = false;
        }

        inferenceBusy_.store(true);

        void* engine = nullptr;
        std::string partType;
        std::vector<std::string> keywords;
        {
            std::lock_guard<std::mutex> lock(engineMutex_);
            engine = activeEngineHandle_;
            partType = activePartType_;
            keywords = activeKeywords_;
        }

        if (engine == nullptr || !workerRunning_.load()) {
            inferenceBusy_.store(false);
            continue;
        }

        const int width = localFrame.width;
        const int height = localFrame.height;
        const int cropSize = std::min(width, height);
        const int startX = (width - cropSize) / 2;
        const int startY = (height - cropSize) / 2;

        if (cropSize != lastCropSize || startX != lastStartX) {
            lastCropSize = cropSize;
            lastStartX = startX;
            for (int outX = 0; outX < 640; ++outX) {
                const int srcX = (outX * cropSize / 640) + startX;
                xLookup[outX] = srcX;
                uvXLookup[outX] = (srcX / 2) * localFrame.uvPixelStride;
            }
        }

        if (rgbBuffer_.size() != 640 * 640 * 3) {
            rgbBuffer_.resize(640 * 640 * 3);
        }

        const uint8_t* yData = localFrame.yData.data();
        const uint8_t* uData = localFrame.uData.data();
        const uint8_t* vData = localFrame.vData.data();
        const int yRowStride = localFrame.yRowStride;
        const int uvRowStride = localFrame.uvRowStride;

        for (int outY = 0; outY < 640; ++outY) {
            const int inY_cropped = outY * cropSize / 640;
            const int srcY = inY_cropped + startY;
            const uint8_t* yRow = yData + (srcY * yRowStride);
            const uint8_t* uRow = uData + ((srcY / 2) * uvRowStride);
            const uint8_t* vRow = vData + ((srcY / 2) * uvRowStride);
            uint8_t* outRgb = rgbBuffer_.data() + (outY * 640 * 3);

            for (int outX = 0; outX < 640; ++outX) {
                const int srcX = xLookup[outX];
                const int uvOff = uvXLookup[outX];

                const int Y = static_cast<int>(yRow[srcX]);
                const int U = static_cast<int>(uRow[uvOff]) - 128;
                const int V = static_cast<int>(vRow[uvOff]) - 128;

                // 16-bit fixed-point YUV -> RGB conversion
                const int rVal = Y + ((359 * V) >> 8);
                const int gVal = Y - ((88 * U + 183 * V) >> 8);
                const int bVal = Y + ((454 * U) >> 8);

                outRgb[0] = static_cast<uint8_t>(std::clamp(rVal, 0, 255));
                outRgb[1] = static_cast<uint8_t>(std::clamp(gVal, 0, 255));
                outRgb[2] = static_cast<uint8_t>(std::clamp(bVal, 0, 255));
                outRgb += 3;
            }
        }

        // Execute YOLO ONNX model
        QString qPart(partType);
        QStringList qKeywords;
        for (const auto& kw : keywords) {
            qKeywords.append(QString(kw));
        }

        // Validate engine handle under lock before running
        {
            std::lock_guard<std::mutex> lock(engineMutex_);
            if (activeEngineHandle_ != engine) {
                inferenceBusy_.store(false);
                continue;
            }
        }

        auto* yoloEngine = static_cast<IInferenceEngine*>(engine);
        auto result = yoloEngine->run(rgbBuffer_.data(), 640, 640, qPart, qKeywords);

        // Dispatch JNI callback safely using global reference
        if (env != nullptr && workerRunning_.load()) {
            jobject pluginRef = nullptr;
            jmethodID methodId = nullptr;
            {
                std::lock_guard<std::mutex> lock(engineMutex_);
                pluginRef = pluginGlobalRef_;
                methodId = onDetectionsAvailableMethod_;
            }

            if (pluginRef != nullptr && methodId != nullptr) {
                const size_t numDetections = result.detections.size();
                jdoubleArray flatArray = env->NewDoubleArray(numDetections * 5);
                if (flatArray != nullptr && numDetections > 0) {
                    std::vector<jdouble> flatBuf(numDetections * 5);
                    for (size_t i = 0; i < numDetections; ++i) {
                        const auto& det = result.detections[i];
                        flatBuf[i * 5 + 0] = static_cast<jdouble>(det.x);
                        flatBuf[i * 5 + 1] = static_cast<jdouble>(det.y);
                        flatBuf[i * 5 + 2] = static_cast<jdouble>(det.w);
                        flatBuf[i * 5 + 3] = static_cast<jdouble>(det.h);
                        flatBuf[i * 5 + 4] = static_cast<jdouble>(det.confidence);
                    }
                    env->SetDoubleArrayRegion(flatArray, 0, numDetections * 5, flatBuf.data());
                }

                jclass stringClass = env->FindClass("java/lang/String");
                jobjectArray labelsArray = env->NewObjectArray(numDetections, stringClass, nullptr);
                for (size_t i = 0; i < numDetections; ++i) {
                    jstring labelStr = env->NewStringUTF(result.detections[i].label.toUtf8().constData());
                    env->SetObjectArrayElement(labelsArray, i, labelStr);
                    env->DeleteLocalRef(labelStr);
                }
                env->DeleteLocalRef(stringClass);

                env->CallVoidMethod(
                    pluginRef,
                    methodId,
                    static_cast<jint>(result.count),
                    static_cast<jint>(result.processingMs),
                    flatArray,
                    labelsArray
                );

                if (flatArray) env->DeleteLocalRef(flatArray);
                if (labelsArray) env->DeleteLocalRef(labelsArray);
            }
        }

        inferenceBusy_.store(false);
    }

    if (attached && javaVM_ != nullptr) {
        javaVM_->DetachCurrentThread();
    }
}

} // namespace beenut

extern "C" {

JNIEXPORT void JNICALL
Java_com_example_beenut_NativeCameraPlugin_nativeSetPreviewSurface(
    JNIEnv* env,
    jobject /* this */,
    jobject surface
) {
    beenut::NdkCameraEngine::instance().setPreviewSurface(env, surface);
}

JNIEXPORT void JNICALL
Java_com_example_beenut_NativeCameraPlugin_nativeClearPreviewSurface(
    JNIEnv* /* env */,
    jobject /* this */
) {
    beenut::NdkCameraEngine::instance().clearPreviewSurface();
}

JNIEXPORT jboolean JNICALL
Java_com_example_beenut_NativeCameraPlugin_nativeStartCamera(
    JNIEnv* env,
    jobject thiz,
    jstring cameraId
) {
    const char* nativeCameraId = cameraId ? env->GetStringUTFChars(cameraId, nullptr) : nullptr;
    bool success = beenut::NdkCameraEngine::instance().startCamera(env, thiz, nativeCameraId);
    if (nativeCameraId) env->ReleaseStringUTFChars(cameraId, nativeCameraId);
    return success ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_example_beenut_NativeCameraPlugin_nativeStopCamera(
    JNIEnv* /* env */,
    jobject /* this */
) {
    beenut::NdkCameraEngine::instance().stopCamera();
}

JNIEXPORT void JNICALL
Java_com_example_beenut_NativeCameraPlugin_nativeUpdateEngineSettings(
    JNIEnv* env,
    jobject /* thiz */,
    jlong engineHandle,
    jstring partType,
    jstring keywords,
    jdouble maxFps
) {
    const char* nativePartType = partType ? env->GetStringUTFChars(partType, nullptr) : nullptr;
    const char* nativeKeywords = keywords ? env->GetStringUTFChars(keywords, nullptr) : nullptr;

    beenut::NdkCameraEngine::instance().updateEngineSettings(
        reinterpret_cast<void*>(engineHandle),
        nativePartType,
        nativeKeywords,
        static_cast<double>(maxFps)
    );

    if (nativePartType) env->ReleaseStringUTFChars(partType, nativePartType);
    if (nativeKeywords) env->ReleaseStringUTFChars(keywords, nativeKeywords);
}

}
