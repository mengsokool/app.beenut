#include "shm_preview.h"
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

struct beenut_shm_frame *beenut_read_shm_frame(const char *path, uint64_t last_index) {
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return NULL;
    struct stat st;
    if (fstat(fd, &st) || st.st_size < (off_t) sizeof(struct beenut_shm_header) ||
        st.st_size > 128 * 1024 * 1024) { close(fd); return NULL; }
    size_t length = (size_t) st.st_size;
    const unsigned char *map = mmap(NULL, length, PROT_READ, MAP_SHARED, fd, 0);
    close(fd);
    if (map == MAP_FAILED) return NULL;
    struct beenut_shm_header h;
    memcpy(&h, map, sizeof h);
    struct beenut_shm_frame *frame = NULL;
    if (h.magic != 0x31565342 || h.version != 1 || h.storage_mode != 0 ||
        h.header_size < sizeof h || h.width == 0 || h.height == 0 ||
        (h.width & 1) || (h.height & 1) || h.width > 8192 || h.height > 8192 ||
        h.frame_index == 0 || (h.frame_index & 1) || h.frame_index == last_index ||
        h.y_stride < h.width || h.uv_stride < h.width ||
        h.y_offset < h.header_size || h.uv_offset < h.header_size ||
        (uint64_t) h.y_offset + (uint64_t) h.y_stride * h.height > length ||
        (uint64_t) h.uv_offset + (uint64_t) h.uv_stride * (h.height/2) > length) goto done;
    size_t y_size = (size_t) h.width * h.height;
    frame = malloc(sizeof *frame + y_size + y_size/2);
    if (!frame) goto done;
    frame->width = h.width; frame->height = h.height; frame->index = h.frame_index;
    for (uint32_t row = 0; row < h.height; row++)
        memcpy(frame->pixels + (size_t) row*h.width, map + h.y_offset + (size_t) row*h.y_stride, h.width);
    for (uint32_t row = 0; row < h.height/2; row++)
        memcpy(frame->pixels + y_size + (size_t) row*h.width, map + h.uv_offset + (size_t) row*h.uv_stride, h.width);
    atomic_thread_fence(memory_order_acquire);
    uint64_t after;
    memcpy(&after, map + offsetof(struct beenut_shm_header, frame_index), sizeof after);
    if (after != h.frame_index) { free(frame); frame = NULL; }
done:
    munmap((void *) map, length);
    return frame;
}

static GLuint shader(GLenum type, const char *source) {
    GLuint id = glCreateShader(type);
    glShaderSource(id, 1, &source, NULL); glCompileShader(id);
    GLint ok; glGetShaderiv(id, GL_COMPILE_STATUS, &ok);
    if (!ok) { glDeleteShader(id); return 0; }
    return id;
}
static void destroy_rgba(const struct texture_frame *frame, void *userdata) {
    (void) userdata;
    GLuint texture = frame->gl.name;
    glDeleteTextures(1, &texture);
}
int beenut_resolve_shm_frame(size_t width, size_t height, void *data, struct texture_frame *out) {
    (void) width; (void) height;
    struct beenut_shm_frame *frame = data;
    const char *vert = "attribute vec2 position; varying vec2 uv; void main(){uv=position*.5+.5;gl_Position=vec4(position,0.,1.);}";
    const char *frag = "precision mediump float; varying vec2 uv; uniform sampler2D ytex; uniform sampler2D uvtex;"
        "void main(){float y=1.164383*(texture2D(ytex,uv).r-16./255.);vec2 c=texture2D(uvtex,uv).ra-vec2(128./255.);"
        "gl_FragColor=vec4(y+1.596027*c.y,y-.391762*c.x-.812968*c.y,y+2.017232*c.x,1.);}";
    // Resolve runs on Flutter's GL thread. Compile once per EGL context.
    static _Thread_local EGLContext program_context;
    static _Thread_local GLuint program;
    EGLContext current = eglGetCurrentContext();
    if (current == EGL_NO_CONTEXT) return ENODEV;
    if (program_context != current) { program = 0; program_context = current; }
    if (!program) {
        GLuint vs = shader(GL_VERTEX_SHADER, vert), fs = shader(GL_FRAGMENT_SHADER, frag);
        if (!vs || !fs) { glDeleteShader(vs); glDeleteShader(fs); return EIO; }
        program = glCreateProgram();
        glAttachShader(program, vs); glAttachShader(program, fs);
        glBindAttribLocation(program, 0, "position"); glLinkProgram(program);
        glDeleteShader(vs); glDeleteShader(fs);
        GLint linked; glGetProgramiv(program, GL_LINK_STATUS, &linked);
        if (!linked) { glDeleteProgram(program); program = 0; return EIO; }
    }

    GLint old_fbo, old_program, old_viewport[4], old_active, old_array, old_alignment;
    GLint old_attrib_enabled, old_attrib_size, old_attrib_type, old_attrib_normalized, old_attrib_stride, old_attrib_buffer;
    void *old_attrib_pointer;
    glGetVertexAttribiv(0, GL_VERTEX_ATTRIB_ARRAY_ENABLED, &old_attrib_enabled);
    glGetVertexAttribiv(0, GL_VERTEX_ATTRIB_ARRAY_SIZE, &old_attrib_size);
    glGetVertexAttribiv(0, GL_VERTEX_ATTRIB_ARRAY_TYPE, &old_attrib_type);
    glGetVertexAttribiv(0, GL_VERTEX_ATTRIB_ARRAY_NORMALIZED, &old_attrib_normalized);
    glGetVertexAttribiv(0, GL_VERTEX_ATTRIB_ARRAY_STRIDE, &old_attrib_stride);
    glGetVertexAttribiv(0, GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING, &old_attrib_buffer);
    glGetVertexAttribPointerv(0, GL_VERTEX_ATTRIB_ARRAY_POINTER, &old_attrib_pointer);
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &old_fbo); glGetIntegerv(GL_CURRENT_PROGRAM, &old_program);
    glGetIntegerv(GL_VIEWPORT, old_viewport); glGetIntegerv(GL_ACTIVE_TEXTURE, &old_active);
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &old_array); glGetIntegerv(GL_UNPACK_ALIGNMENT, &old_alignment);
    GLboolean blend = glIsEnabled(GL_BLEND), scissor = glIsEnabled(GL_SCISSOR_TEST);
    GLboolean depth = glIsEnabled(GL_DEPTH_TEST), cull = glIsEnabled(GL_CULL_FACE), color_mask[4];
    glGetBooleanv(GL_COLOR_WRITEMASK, color_mask);
    glDisable(GL_DEPTH_TEST); glDisable(GL_CULL_FACE); glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glDisable(GL_BLEND); glDisable(GL_SCISSOR_TEST); glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    GLuint textures[3], fbo, vbo;
    glGenTextures(3, textures);
    GLint old_bindings[2];
    for (int i = 0; i < 2; i++) {
        glActiveTexture(GL_TEXTURE0+i); glGetIntegerv(GL_TEXTURE_BINDING_2D, &old_bindings[i]);
        glBindTexture(GL_TEXTURE_2D, textures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        GLenum format = i ? GL_LUMINANCE_ALPHA : GL_LUMINANCE;
        glTexImage2D(GL_TEXTURE_2D, 0, format, i ? frame->width/2 : frame->width,
            i ? frame->height/2 : frame->height, 0, format, GL_UNSIGNED_BYTE,
            frame->pixels + (i ? (size_t) frame->width*frame->height : 0));
    }
    glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, textures[2]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, frame->width, frame->height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glGenFramebuffers(1, &fbo); glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textures[2], 0);
    bool ok = glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
    if (ok) {
        glBindTexture(GL_TEXTURE_2D, textures[0]); glUseProgram(program);
        glUniform1i(glGetUniformLocation(program, "ytex"), 0);
        glUniform1i(glGetUniformLocation(program, "uvtex"), 1);
        const float vertices[] = {-1,-1, 1,-1, -1,1, 1,1};
        glGenBuffers(1, &vbo); glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, sizeof vertices, vertices, GL_STATIC_DRAW);
        glEnableVertexAttribArray(0); glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, NULL);
        glViewport(0, 0, frame->width, frame->height); glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        glDisableVertexAttribArray(0); glDeleteBuffers(1, &vbo);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, old_fbo); glUseProgram(old_program);
    glViewport(old_viewport[0], old_viewport[1], old_viewport[2], old_viewport[3]);
    glBindBuffer(GL_ARRAY_BUFFER, old_attrib_buffer);
    glVertexAttribPointer(0, old_attrib_size, old_attrib_type, old_attrib_normalized, old_attrib_stride, old_attrib_pointer);
    if (old_attrib_enabled) glEnableVertexAttribArray(0); else glDisableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, old_array); glPixelStorei(GL_UNPACK_ALIGNMENT, old_alignment);
    if (blend) glEnable(GL_BLEND);
    if (scissor) glEnable(GL_SCISSOR_TEST);
    if (depth) glEnable(GL_DEPTH_TEST);
    if (cull) glEnable(GL_CULL_FACE);
    glColorMask(color_mask[0], color_mask[1], color_mask[2], color_mask[3]);
    for (int i = 0; i < 2; i++) { glActiveTexture(GL_TEXTURE0+i); glBindTexture(GL_TEXTURE_2D, old_bindings[i]); }
    glActiveTexture(old_active);
    glDeleteFramebuffers(1, &fbo); glDeleteTextures(2, textures);
    if (!ok) { glDeleteTextures(1, &textures[2]); return EIO; }
    out->gl = (struct gl_texture_frame){GL_TEXTURE_2D, textures[2], GL_RGBA8_OES, frame->width, frame->height};
    out->userdata = NULL; out->destroy = destroy_rgba;
    return 0;
}
