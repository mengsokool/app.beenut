#include "shm_preview_plugin.h"

#include <iostream>

namespace beenut {

namespace {
constexpr uint32_t kPreviewMagic = 0x31565342; // BSV1
constexpr uint32_t kPreviewVersion = 1;

struct PreviewShmHeader {
    uint32_t magic;
    uint32_t version;
    uint32_t headerSize;
    uint32_t width;
    uint32_t height;
    uint32_t yStride;
    uint32_t uvStride;
    uint32_t yOffset;
    uint32_t uvOffset;
    uint32_t pad[3];
    uint64_t frameIndex;
};
}

ShmTexture::ShmTexture(const std::string& path, flutter::TextureRegistrar* registrar)
    : path_(path),
      registrar_(registrar),
      texture_variant_(flutter::PixelBufferTexture(
          [this](size_t width, size_t height) -> const FlutterDesktopPixelBuffer* {
              return this->CopyPixelBuffer(width, height);
          })) {
    flutter_pixel_buffer_ = std::make_unique<FlutterDesktopPixelBuffer>();
    flutter_pixel_buffer_->buffer = nullptr;
    flutter_pixel_buffer_->width = 0;
    flutter_pixel_buffer_->height = 0;
}

ShmTexture::~ShmTexture() {
    Stop();
}

bool ShmTexture::Start() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (timer_queue_ != nullptr) return true;

    timer_queue_ = CreateTimerQueue();
    if (!timer_queue_) return false;

    // Poll every 16ms
    if (!CreateTimerQueueTimer(&timer_, timer_queue_,
        (WAITORTIMERCALLBACK)TimerCallback, this, 0, 16, WT_EXECUTEDEFAULT)) {
        DeleteTimerQueue(timer_queue_);
        timer_queue_ = nullptr;
        return false;
    }
    return true;
}

void ShmTexture::Stop() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (timer_queue_ != nullptr) {
        DeleteTimerQueueTimer(timer_queue_, timer_, INVALID_HANDLE_VALUE);
        DeleteTimerQueue(timer_queue_);
        timer_ = nullptr;
        timer_queue_ = nullptr;
    }
    Unmap();
}

void ShmTexture::Attach(int64_t texture_id) {
    texture_id_ = texture_id;
}

void CALLBACK ShmTexture::TimerCallback(void* lpParam, BOOLEAN TimerOrWaitFired) {
    auto* self = static_cast<ShmTexture*>(lpParam);
    self->PollFrame();
}

void ShmTexture::PollFrame() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!EnsureMapped() || !mapped_) return;

    auto* header = reinterpret_cast<PreviewShmHeader*>(mapped_);
    if (header->magic != kPreviewMagic || header->version != kPreviewVersion) return;

    uint64_t frame_index = header->frameIndex;
    if (frame_index > 0 && frame_index != notified_frame_index_) {
        notified_frame_index_ = frame_index;
        if (texture_id_ != -1 && registrar_ != nullptr) {
            registrar_->MarkTextureFrameAvailable(texture_id_);
        }
    }
}

const FlutterDesktopPixelBuffer* ShmTexture::CopyPixelBuffer(size_t width, size_t height) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!EnsureMapped() || !mapped_) return nullptr;

    auto* header = reinterpret_cast<PreviewShmHeader*>(mapped_);
    if (header->magic != kPreviewMagic || header->version != kPreviewVersion) return nullptr;

    uint32_t frame_width = header->width;
    uint32_t frame_height = header->height;
    uint32_t y_offset = header->yOffset;
    uint32_t y_stride = header->yStride;
    uint64_t frame_index = header->frameIndex;

    if (frame_width == 0 || frame_height == 0 || y_offset == 0) return nullptr;

    // Reallocate local buffer if frame size changed
    if (pixel_buffer_width_ != frame_width || pixel_buffer_height_ != frame_height) {
        pixel_buffer_width_ = frame_width;
        pixel_buffer_height_ = frame_height;
        // GStreamer outputs BGRA (4 bytes per pixel) on Windows for simple copy
        pixel_buffer_ = std::make_unique<uint8_t[]>(frame_width * frame_height * 4);
        copied_frame_index_ = 0;
    }

    if (frame_index != copied_frame_index_) {
        uint8_t* src = static_cast<uint8_t*>(mapped_) + y_offset;
        uint8_t* dst = pixel_buffer_.get();
        // Copy line by line accounting for strides
        for (uint32_t row = 0; row < frame_height; ++row) {
            memcpy(dst + (row * frame_width * 4), src + (row * y_stride), frame_width * 4);
        }
        copied_frame_index_ = frame_index;
    }

    flutter_pixel_buffer_->width = pixel_buffer_width_;
    flutter_pixel_buffer_->height = pixel_buffer_height_;
    flutter_pixel_buffer_->buffer = pixel_buffer_.get();

    return flutter_pixel_buffer_.get();
}

bool ShmTexture::EnsureMapped() {
    if (mapped_ != nullptr) return true;

    // Translate POSIX path format (e.g. "/tmp/beenut_preview") to Win32 Local mapping name
    std::wstring map_name = L"Local\\";
    size_t last_slash = path_.find_last_of("/\\");
    std::string base_name = (last_slash == std::string::npos) ? path_ : path_.substr(last_slash + 1);
    map_name += std::wstring(base_name.begin(), base_name.end());

    file_mapping_ = OpenFileMappingW(FILE_MAP_READ, FALSE, map_name.c_str());
    if (!file_mapping_) return false;

    mapped_ = MapViewOfFile(file_mapping_, FILE_MAP_READ, 0, 0, 0);
    if (!mapped_) {
        CloseHandle(file_mapping_);
        file_mapping_ = nullptr;
        return false;
    }

    return true;
}

void ShmTexture::Unmap() {
    if (mapped_ != nullptr) {
        UnmapViewOfFile(mapped_);
        mapped_ = nullptr;
    }
    if (file_mapping_ != nullptr) {
        CloseHandle(file_mapping_);
        file_mapping_ = nullptr;
    }
    notified_frame_index_ = 0;
    copied_frame_index_ = 0;
    pixel_buffer_width_ = 0;
    pixel_buffer_height_ = 0;
    pixel_buffer_.reset();
}

// ==========================================
// ShmPreviewPlugin
// ==========================================

void ShmPreviewPlugin::RegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
    auto* plugin_registrar =
        flutter::PluginRegistrarManager::GetInstance()
            ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
    auto plugin = std::make_unique<ShmPreviewPlugin>(plugin_registrar);
    plugin_registrar->AddPlugin(std::move(plugin));
}

ShmPreviewPlugin::ShmPreviewPlugin(flutter::PluginRegistrarWindows* registrar)
    : texture_registrar_(registrar->texture_registrar()) {
    channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(), "beenut/preview_texture",
        &flutter::StandardMethodCodec::GetInstance());

    channel_->SetMethodCallHandler(
        [this](const auto& call, auto result) {
            this->HandleMethodCall(call, std::move(result));
        });
}

ShmPreviewPlugin::~ShmPreviewPlugin() {
    textures_.clear();
}

void ShmPreviewPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    const auto& method_name = method_call.method_name();

    if (method_name == "create") {
        const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!arguments) {
            result->Error("bad_args", "Missing arguments map");
            return;
        }

        auto path_iter = arguments->find(flutter::EncodableValue("path"));
        if (path_iter == arguments->end()) {
            result->Error("bad_args", "Missing path argument");
            return;
        }

        std::string path = std::get<std::string>(path_iter->second);
        if (path.empty()) {
            result->Error("bad_args", "Path argument is empty");
            return;
        }

        auto texture = std::make_shared<ShmTexture>(path, texture_registrar_);
        int64_t texture_id = texture_registrar_->RegisterTexture(texture->texture_variant());
        texture->Attach(texture_id);

        if (!texture->Start()) {
            texture_registrar_->UnregisterTexture(texture_id);
            result->Error("failed", "Failed to start frame polling timer");
            return;
        }

        textures_[texture_id] = texture;
        result->Success(flutter::EncodableValue(texture_id));

    } else if (method_name == "dispose") {
        const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!arguments) {
            result->Error("bad_args", "Missing arguments map");
            return;
        }

        auto id_iter = arguments->find(flutter::EncodableValue("textureId"));
        if (id_iter == arguments->end()) {
            result->Error("bad_args", "Missing textureId argument");
            return;
        }

        int64_t texture_id = id_iter->second.LongValue();
        auto texture_iter = textures_.find(texture_id);
        if (texture_iter != textures_.end()) {
            texture_iter->second->Stop();
            texture_registrar_->UnregisterTexture(texture_id);
            textures_.erase(texture_iter);
        }
        result->Success();
    } else {
        result->NotImplemented();
    }
}

}  // namespace beenut
