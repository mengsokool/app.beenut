#pragma once

#include <stdint.h>

#define BEENUT_PREVIEW_CHANNEL "beenut/preview_texture"
#define BEENUT_DMABUF_MAGIC 0x31464244u /* DBF1 */
#define BEENUT_DMABUF_VERSION 1u
#define BEENUT_DMABUF_MAX_PLANES 4u

struct beenut_dmabuf_frame {
    uint32_t magic;
    uint32_t version;
    uint32_t width;
    uint32_t height;
    uint32_t fourcc;
    uint32_t n_planes;
    uint64_t modifier;
    uint64_t frame_index;
    uint32_t offsets[BEENUT_DMABUF_MAX_PLANES];
    uint32_t strides[BEENUT_DMABUF_MAX_PLANES];
};

