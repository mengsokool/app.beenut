#include "beenut_shm_texture.h"

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

namespace {

constexpr uint32_t kPreviewMagic = 0x31565342;
constexpr uint32_t kPreviewVersion = 1;
constexpr size_t kPreviewHeaderSize = 56;
constexpr uint32_t kMaxPreviewDimension = 8192;

uint32_t read_u32(const uint8_t* base, size_t offset) {
  uint32_t value = 0;
  std::memcpy(&value, base + offset, sizeof(value));
  return value;
}

uint64_t read_u64(const uint8_t* base, size_t offset) {
  uint64_t value = 0;
  std::memcpy(&value, base + offset, sizeof(value));
  return value;
}

uint8_t clamp_byte(int value) {
  return static_cast<uint8_t>(std::max(0, std::min(255, value)));
}

bool checked_range(size_t offset,
                   size_t stride,
                   size_t rows,
                   size_t mapped_size) {
  if (offset > mapped_size) {
    return false;
  }
  if (rows == 0) {
    return true;
  }
  if (stride > (mapped_size - offset) / rows) {
    return false;
  }
  return offset + stride * rows <= mapped_size;
}

}  // namespace

struct _BeenutShmTexture {
  FlPixelBufferTexture parent_instance;
  char* path;
  int fd;
  uint8_t* mapped;
  size_t mapped_size;
  uint8_t* rgba;
  uint8_t* staging_rgba;
  uint8_t blank_rgba[4];
  uint32_t width;
  uint32_t height;
  uint32_t staging_width;
  uint32_t staging_height;
  uint64_t notified_frame_index;
  uint64_t copied_frame_index;
};

G_DEFINE_TYPE(BeenutShmTexture,
              beenut_shm_texture,
              fl_pixel_buffer_texture_get_type())

static gboolean return_blank_pixel(BeenutShmTexture* self,
                                   const uint8_t** out_buffer,
                                   uint32_t* width,
                                   uint32_t* height) {
  self->blank_rgba[0] = 0;
  self->blank_rgba[1] = 0;
  self->blank_rgba[2] = 0;
  self->blank_rgba[3] = 255;
  *out_buffer = self->blank_rgba;
  *width = 1;
  *height = 1;
  return TRUE;
}

static gboolean return_last_good_or_blank(BeenutShmTexture* self,
                                          const uint8_t** out_buffer,
                                          uint32_t* width,
                                          uint32_t* height) {
  if (self->rgba != nullptr && self->width > 0 && self->height > 0) {
    *out_buffer = self->rgba;
    *width = self->width;
    *height = self->height;
    return TRUE;
  }
  return return_blank_pixel(self, out_buffer, width, height);
}

static void close_mapping(BeenutShmTexture* self) {
  if (self->mapped != nullptr) {
    munmap(self->mapped, self->mapped_size);
    self->mapped = nullptr;
  }
  if (self->fd >= 0) {
    close(self->fd);
    self->fd = -1;
  }
  self->mapped_size = 0;
  self->notified_frame_index = 0;
}

static void beenut_shm_texture_dispose(GObject* object) {
  auto* self = BEENUT_SHM_TEXTURE(object);
  beenut_shm_texture_close(self);
  g_clear_pointer(&self->path, g_free);
  G_OBJECT_CLASS(beenut_shm_texture_parent_class)->dispose(object);
}

static bool ensure_mapped(BeenutShmTexture* self) {
  if (self->path == nullptr || self->path[0] == '\0') {
    return false;
  }
  if (self->fd >= 0 && self->mapped != nullptr) {
    struct stat stat_info {};
    if (fstat(self->fd, &stat_info) == 0 &&
        stat_info.st_size >= static_cast<off_t>(kPreviewHeaderSize) &&
        static_cast<size_t>(stat_info.st_size) == self->mapped_size) {
      return true;
    }
    close_mapping(self);
  }
  self->fd = open(self->path, O_RDONLY);
  if (self->fd < 0) {
    return false;
  }
  struct stat stat_info {};
  if (fstat(self->fd, &stat_info) != 0 ||
      stat_info.st_size < static_cast<off_t>(kPreviewHeaderSize)) {
    close_mapping(self);
    return false;
  }
  self->mapped_size = static_cast<size_t>(stat_info.st_size);
  auto* mapped = mmap(nullptr, self->mapped_size, PROT_READ, MAP_SHARED, self->fd, 0);
  if (mapped == MAP_FAILED) {
    close_mapping(self);
    return false;
  }
  self->mapped = static_cast<uint8_t*>(mapped);
  return true;
}

static gboolean beenut_shm_texture_copy_pixels(FlPixelBufferTexture* texture,
                                               const uint8_t** out_buffer,
                                               uint32_t* width,
                                               uint32_t* height,
                                               GError** error) {
  auto* self = BEENUT_SHM_TEXTURE(texture);
  if (!ensure_mapped(self)) {
    return return_last_good_or_blank(self, out_buffer, width, height);
  }

  const auto magic = read_u32(self->mapped, 0);
  const auto version = read_u32(self->mapped, 4);
  const auto frame_width = read_u32(self->mapped, 12);
  const auto frame_height = read_u32(self->mapped, 16);
  const auto y_stride = read_u32(self->mapped, 20);
  const auto uv_stride = read_u32(self->mapped, 24);
  const auto y_offset = read_u32(self->mapped, 28);
  const auto uv_offset = read_u32(self->mapped, 32);
  const auto frame_index = read_u64(self->mapped, 48);
  const auto uv_height = static_cast<size_t>(frame_height + 1) / 2;
  const auto minimum_uv_stride = static_cast<size_t>((frame_width + 1) / 2) * 2;
  if (magic != kPreviewMagic || version != kPreviewVersion || frame_index == 0 ||
      (frame_index % 2) != 0 ||
      frame_width == 0 || frame_width > kMaxPreviewDimension ||
      frame_height == 0 || frame_height > kMaxPreviewDimension ||
      y_stride < frame_width || uv_stride < minimum_uv_stride ||
      y_offset < kPreviewHeaderSize ||
      uv_offset <= y_offset ||
      !checked_range(static_cast<size_t>(y_offset), static_cast<size_t>(y_stride),
                     static_cast<size_t>(frame_height), self->mapped_size) ||
      !checked_range(static_cast<size_t>(uv_offset), static_cast<size_t>(uv_stride),
                     uv_height, self->mapped_size)) {
    return return_last_good_or_blank(self, out_buffer, width, height);
  }
  if (self->copied_frame_index == frame_index) {
    return return_last_good_or_blank(self, out_buffer, width, height);
  }

  if (self->staging_width != frame_width || self->staging_height != frame_height ||
      self->staging_rgba == nullptr) {
    const auto pixel_count = static_cast<size_t>(frame_width) * frame_height;
    if (pixel_count > std::numeric_limits<size_t>::max() / 4) {
      return return_last_good_or_blank(self, out_buffer, width, height);
    }
    auto* next_staging = static_cast<uint8_t*>(
        std::realloc(self->staging_rgba, pixel_count * 4));
    if (next_staging == nullptr) {
      return return_last_good_or_blank(self, out_buffer, width, height);
    }
    self->staging_rgba = next_staging;
    self->staging_width = frame_width;
    self->staging_height = frame_height;
  }

  const auto* y_plane = self->mapped + y_offset;
  const auto* uv_plane = self->mapped + uv_offset;
  for (uint32_t row = 0; row < frame_height; ++row) {
    const auto* y_row = y_plane + row * y_stride;
    const auto* uv_row = uv_plane + (row / 2) * uv_stride;
    auto* dst = self->staging_rgba + static_cast<size_t>(row) * frame_width * 4;
    for (uint32_t col = 0; col < frame_width; ++col) {
      const int y = static_cast<int>(y_row[col]);
      const int u = static_cast<int>(uv_row[(col / 2) * 2]) - 128;
      const int v = static_cast<int>(uv_row[(col / 2) * 2 + 1]) - 128;
      dst[col * 4 + 0] = clamp_byte(y + ((359 * v) >> 8));
      dst[col * 4 + 1] = clamp_byte(y - ((88 * u + 183 * v) >> 8));
      dst[col * 4 + 2] = clamp_byte(y + ((454 * u) >> 8));
      dst[col * 4 + 3] = 255;
    }
  }

  const auto post_frame_index = read_u64(self->mapped, 48);
  if (post_frame_index == frame_index) {
    const auto pixel_count = static_cast<size_t>(frame_width) * frame_height;
    if (self->width != frame_width || self->height != frame_height ||
        self->rgba == nullptr) {
      auto* next_rgba = static_cast<uint8_t*>(
          std::realloc(self->rgba, pixel_count * 4));
      if (next_rgba == nullptr) {
        return return_last_good_or_blank(self, out_buffer, width, height);
      }
      self->rgba = next_rgba;
    }
    std::memcpy(self->rgba, self->staging_rgba, pixel_count * 4);
    self->width = frame_width;
    self->height = frame_height;
    self->copied_frame_index = frame_index;
  }

  if (self->rgba == nullptr || self->width == 0 || self->height == 0) {
    return return_last_good_or_blank(self, out_buffer, width, height);
  }
  *out_buffer = self->rgba;
  *width = self->width;
  *height = self->height;
  return TRUE;
}

static void beenut_shm_texture_class_init(BeenutShmTextureClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = beenut_shm_texture_dispose;
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = beenut_shm_texture_copy_pixels;
}

static void beenut_shm_texture_init(BeenutShmTexture* self) {
  self->fd = -1;
}

BeenutShmTexture* beenut_shm_texture_new(const char* path) {
  auto* self = BEENUT_SHM_TEXTURE(g_object_new(beenut_shm_texture_get_type(), nullptr));
  self->path = g_strdup(path == nullptr ? "" : path);
  return self;
}

void beenut_shm_texture_close(BeenutShmTexture* self) {
  close_mapping(self);
  if (self->rgba != nullptr) {
    std::free(self->rgba);
    self->rgba = nullptr;
  }
  if (self->staging_rgba != nullptr) {
    std::free(self->staging_rgba);
    self->staging_rgba = nullptr;
  }
  self->width = 0;
  self->height = 0;
  self->staging_width = 0;
  self->staging_height = 0;
  self->copied_frame_index = 0;
}

bool beenut_shm_texture_has_new_frame(BeenutShmTexture* self) {
  g_return_val_if_fail(BEENUT_IS_SHM_TEXTURE(self), false);
  if (!ensure_mapped(self)) {
    return false;
  }
  const auto magic = read_u32(self->mapped, 0);
  const auto version = read_u32(self->mapped, 4);
  const auto frame_index = read_u64(self->mapped, 48);
  if (magic != kPreviewMagic || version != kPreviewVersion || frame_index == 0 ||
      (frame_index % 2) != 0) {
    return false;
  }
  if (frame_index == self->notified_frame_index) {
    return false;
  }
  self->notified_frame_index = frame_index;
  return true;
}
