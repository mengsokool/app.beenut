#ifndef RUNNER_SHM_PREVIEW_PLUGIN_H_
#define RUNNER_SHM_PREVIEW_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <windows.h>

namespace beenut {

class ShmTexture {
public:
    ShmTexture(const std::string& path, flutter::TextureRegistrar* registrar);
    virtual ~ShmTexture();

    bool Start();
    void Stop();
    void Attach(int64_t texture_id);
    flutter::TextureVariant* texture_variant() { return &texture_variant_; }

    const FlutterDesktopPixelBuffer* CopyPixelBuffer(size_t width, size_t height);

private:
    void PollFrame();
    bool EnsureMapped();
    void Unmap();

    std::string path_;
    flutter::TextureRegistrar* registrar_ = nullptr;
    int64_t texture_id_ = -1;

    HANDLE file_mapping_ = nullptr;
    void* mapped_ = nullptr;
    size_t mapped_size_ = 0;

    uint64_t notified_frame_index_ = 0;
    uint64_t copied_frame_index_ = 0;

    std::unique_ptr<uint8_t[]> pixel_buffer_;
    size_t pixel_buffer_width_ = 0;
    size_t pixel_buffer_height_ = 0;
    std::unique_ptr<FlutterDesktopPixelBuffer> flutter_pixel_buffer_;
    flutter::TextureVariant texture_variant_;

    std::mutex mutex_;
    HANDLE timer_ = nullptr;
    HANDLE timer_queue_ = nullptr;

    static void CALLBACK TimerCallback(void* lpParam, BOOLEAN TimerOrWaitFired);
};

class ShmPreviewPlugin : public flutter::Plugin {
public:
    static void RegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar);

    ShmPreviewPlugin(flutter::PluginRegistrarWindows* registrar);
    virtual ~ShmPreviewPlugin();

private:
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    flutter::TextureRegistrar* texture_registrar_;
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
    std::unordered_map<int64_t, std::shared_ptr<ShmTexture>> textures_;
};

}  // namespace beenut

#endif  // RUNNER_SHM_PREVIEW_PLUGIN_H_
