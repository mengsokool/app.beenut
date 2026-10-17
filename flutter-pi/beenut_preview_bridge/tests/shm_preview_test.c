#include "shm_preview.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>

int main(void) {
    char path[] = "/tmp/beenut-shm-test-XXXXXX";
    int fd = mkstemp(path);
    assert(fd >= 0);
    struct beenut_shm_header h = {
        .magic=0x31565342, .version=1, .header_size=sizeof h,
        .width=2, .height=2, .y_stride=4, .uv_stride=4,
        .y_offset=sizeof h, .uv_offset=sizeof h+8,
        .frame_size=12, .frame_index=2,
    };
    // Padded rows: left pixels black, right pixels white, neutral chroma.
    const unsigned char nv12[] = {16,235,99,99,16,235,99,99,128,128,99,99};
    assert(write(fd, &h, sizeof h) == sizeof h);
    assert(write(fd, nv12, sizeof nv12) == sizeof nv12);
    struct beenut_shm_frame *snapshot = beenut_read_shm_frame(path, 0);
    assert(snapshot && snapshot->width == 2 && snapshot->index == 2);
    assert(snapshot->pixels[2] == 16 && snapshot->pixels[4] == 128);
    assert(!beenut_read_shm_frame(path, 2));
    h.frame_index = 3; // Producer is still writing.
    assert(pwrite(fd, &h, sizeof h, 0) == sizeof h);
    assert(!beenut_read_shm_frame(path, 0));
    h.frame_index = 4; h.uv_offset = 0xffffffff;
    assert(pwrite(fd, &h, sizeof h, 0) == sizeof h);
    assert(!beenut_read_shm_frame(path, 0));
    close(fd); unlink(path);

    EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    assert(eglInitialize(display, NULL, NULL));
    assert(eglBindAPI(EGL_OPENGL_ES_API));
    const EGLint attrs[] = {EGL_SURFACE_TYPE,EGL_PBUFFER_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8,EGL_NONE};
    EGLConfig config; EGLint count;
    assert(eglChooseConfig(display, attrs, &config, 1, &count) && count);
    const EGLint size[] = {EGL_WIDTH,2,EGL_HEIGHT,2,EGL_NONE};
    EGLSurface surface = eglCreatePbufferSurface(display, config, size);
    const EGLint version[] = {EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};
    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, version);
    assert(eglMakeCurrent(display, surface, surface, context));
    glEnable(GL_BLEND); glEnable(GL_SCISSOR_TEST); glEnable(GL_CULL_FACE);
    glColorMask(GL_FALSE,GL_FALSE,GL_FALSE,GL_FALSE);
    for (int pass=0; pass<3; pass++) {
        struct texture_frame out = {0};
        assert(!beenut_resolve_shm_frame(2,2,snapshot,&out));
        assert(glIsEnabled(GL_BLEND) && glIsEnabled(GL_SCISSOR_TEST) && glIsEnabled(GL_CULL_FACE));
        GLboolean mask[4]; glGetBooleanv(GL_COLOR_WRITEMASK, mask);
        assert(!mask[0] && !mask[1] && !mask[2] && !mask[3]);
        GLuint fbo; glGenFramebuffers(1,&fbo); glBindFramebuffer(GL_FRAMEBUFFER,fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,out.gl.name,0);
        unsigned char pixels[16]; glReadPixels(0,0,2,2,GL_RGBA,GL_UNSIGNED_BYTE,pixels);
        assert(pixels[0] < 3 && pixels[1] < 3 && pixels[2] < 3 && pixels[3] == 255);
        assert(pixels[4] > 252 && pixels[5] > 252 && pixels[6] > 252 && pixels[7] == 255);
        glBindFramebuffer(GL_FRAMEBUFFER,0); glDeleteFramebuffers(1,&fbo);
        out.destroy(&out,out.userdata);
        assert(glGetError() == GL_NO_ERROR);
    }
    free(snapshot);
    eglMakeCurrent(display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
    eglDestroyContext(display,context); eglDestroySurface(display,surface); eglTerminate(display);
    puts("SHM validation, NV12 GPU conversion and GL state restoration passed");
}
