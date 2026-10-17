#pragma once
#include <stdint.h>
#include <stddef.h>
#include "texture_registry.h"

struct beenut_shm_header {
    uint32_t magic, version, header_size, width, height;
    uint32_t y_stride, uv_stride, y_offset, uv_offset;
    uint64_t frame_size, frame_index, timestamp_ns;
    uint32_t storage_mode, surface_id;
};
struct beenut_shm_frame {
    uint32_t width, height;
    uint64_t index;
    unsigned char pixels[];
};
// Returns a stable, packed NV12 snapshot; caller owns it. No CPU RGB conversion.
struct beenut_shm_frame *beenut_read_shm_frame(const char *path, uint64_t last_index);
int beenut_resolve_shm_frame(size_t width, size_t height, void *data, struct texture_frame *out);
