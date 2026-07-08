#ifndef BEENUT_SHM_TEXTURE_H_
#define BEENUT_SHM_TEXTURE_H_

#include <flutter_linux/flutter_linux.h>

G_DECLARE_FINAL_TYPE(BeenutShmTexture,
                     beenut_shm_texture,
                     BEENUT,
                     SHM_TEXTURE,
                     FlPixelBufferTexture)

BeenutShmTexture* beenut_shm_texture_new(const char* path);

void beenut_shm_texture_close(BeenutShmTexture* self);

bool beenut_shm_texture_has_new_frame(BeenutShmTexture* self);

#endif  // BEENUT_SHM_TEXTURE_H_
