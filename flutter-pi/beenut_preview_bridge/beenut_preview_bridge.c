#include "beenut_preview_bridge.h"

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include <drm_fourcc.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#include "flutter-pi.h"
#include "pluginregistry.h"
#include "platformchannel.h"
#include "texture_registry.h"

#ifndef GL_TEXTURE_EXTERNAL_OES
#define GL_TEXTURE_EXTERNAL_OES 0x8D65
#endif

struct bridge_frame {
    struct beenut_dmabuf_frame meta;
    int fds[BEENUT_DMABUF_MAX_PLANES];
};

struct resolved_frame {
    EGLDisplay display;
    EGLImageKHR image;
    GLuint texture;
};

struct bridge_state {
    struct flutterpi *flutterpi;
    struct texture *texture;
    pthread_t thread;
    bool running;
    int socket_fd;
    char *socket_path;
    uint64_t pushed_frame_index;
};

static void close_frame_fds(struct bridge_frame *frame) {
    for (uint32_t i = 0; i < BEENUT_DMABUF_MAX_PLANES; i++) {
        if (frame->fds[i] >= 0) {
            close(frame->fds[i]);
            frame->fds[i] = -1;
        }
    }
}

static void destroy_bridge_frame(void *userdata) {
    struct bridge_frame *frame = userdata;
    if (frame != NULL) {
        close_frame_fds(frame);
        free(frame);
    }
}

static void destroy_resolved_frame(const struct texture_frame *frame, void *userdata) {
    (void) frame;
    struct resolved_frame *resolved = userdata;
    if (resolved == NULL) {
        return;
    }
    if (resolved->texture != 0) {
        glDeleteTextures(1, &resolved->texture);
    }
    if (resolved->image != EGL_NO_IMAGE_KHR) {
        PFNEGLDESTROYIMAGEKHRPROC destroy_image =
            (PFNEGLDESTROYIMAGEKHRPROC) eglGetProcAddress("eglDestroyImageKHR");
        if (destroy_image != NULL) {
            destroy_image(resolved->display, resolved->image);
        }
    }
    free(resolved);
}

static int resolve_dmabuf_frame(size_t width, size_t height, void *userdata, struct texture_frame *frame_out) {
    (void) width;
    (void) height;
    struct bridge_frame *frame = userdata;
    PFNEGLCREATEIMAGEKHRPROC create_image = (PFNEGLCREATEIMAGEKHRPROC) eglGetProcAddress("eglCreateImageKHR");
    PFNGLEGLIMAGETARGETTEXTURE2DOESPROC image_target =
        (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC) eglGetProcAddress("glEGLImageTargetTexture2DOES");
    if (create_image == NULL || image_target == NULL || frame == NULL) {
        return ENOSYS;
    }

    EGLDisplay display = eglGetCurrentDisplay();
    if (display == EGL_NO_DISPLAY) {
        return ENODEV;
    }

    EGLint attrs[64];
    int idx = 0;
    attrs[idx++] = EGL_WIDTH;
    attrs[idx++] = (EGLint) frame->meta.width;
    attrs[idx++] = EGL_HEIGHT;
    attrs[idx++] = (EGLint) frame->meta.height;
    attrs[idx++] = EGL_LINUX_DRM_FOURCC_EXT;
    attrs[idx++] = (EGLint) frame->meta.fourcc;

    for (uint32_t plane = 0; plane < frame->meta.n_planes && plane < BEENUT_DMABUF_MAX_PLANES; plane++) {
        static const EGLint fd_attrs[] = {
            EGL_DMA_BUF_PLANE0_FD_EXT,
            EGL_DMA_BUF_PLANE1_FD_EXT,
            EGL_DMA_BUF_PLANE2_FD_EXT,
            EGL_DMA_BUF_PLANE3_FD_EXT,
        };
        static const EGLint offset_attrs[] = {
            EGL_DMA_BUF_PLANE0_OFFSET_EXT,
            EGL_DMA_BUF_PLANE1_OFFSET_EXT,
            EGL_DMA_BUF_PLANE2_OFFSET_EXT,
            EGL_DMA_BUF_PLANE3_OFFSET_EXT,
        };
        static const EGLint pitch_attrs[] = {
            EGL_DMA_BUF_PLANE0_PITCH_EXT,
            EGL_DMA_BUF_PLANE1_PITCH_EXT,
            EGL_DMA_BUF_PLANE2_PITCH_EXT,
            EGL_DMA_BUF_PLANE3_PITCH_EXT,
        };
        attrs[idx++] = fd_attrs[plane];
        attrs[idx++] = frame->fds[plane];
        attrs[idx++] = offset_attrs[plane];
        attrs[idx++] = (EGLint) frame->meta.offsets[plane];
        attrs[idx++] = pitch_attrs[plane];
        attrs[idx++] = (EGLint) frame->meta.strides[plane];
    }
    attrs[idx++] = EGL_NONE;

    EGLImageKHR image = create_image(display, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, NULL, attrs);
    if (image == EGL_NO_IMAGE_KHR) {
        return EIO;
    }

    GLuint texture = 0;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, texture);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    image_target(GL_TEXTURE_EXTERNAL_OES, image);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, 0);

    struct resolved_frame *resolved = calloc(1, sizeof *resolved);
    if (resolved == NULL) {
        glDeleteTextures(1, &texture);
        PFNEGLDESTROYIMAGEKHRPROC destroy_image =
            (PFNEGLDESTROYIMAGEKHRPROC) eglGetProcAddress("eglDestroyImageKHR");
        if (destroy_image != NULL) {
            destroy_image(display, image);
        }
        return ENOMEM;
    }

    resolved->display = display;
    resolved->image = image;
    resolved->texture = texture;

    frame_out->gl.target = GL_TEXTURE_EXTERNAL_OES;
    frame_out->gl.name = texture;
    frame_out->gl.format = GL_RGBA8_OES;
    frame_out->gl.width = frame->meta.width;
    frame_out->gl.height = frame->meta.height;
    frame_out->userdata = resolved;
    frame_out->destroy = destroy_resolved_frame;

    close_frame_fds(frame);
    return 0;
}

static int receive_frame(int fd, struct bridge_frame **frame_out) {
    struct bridge_frame *frame = calloc(1, sizeof *frame);
    if (frame == NULL) {
        return ENOMEM;
    }
    for (uint32_t i = 0; i < BEENUT_DMABUF_MAX_PLANES; i++) {
        frame->fds[i] = -1;
    }

    char control[CMSG_SPACE(sizeof(int) * BEENUT_DMABUF_MAX_PLANES)];
    struct iovec iov = {
        .iov_base = &frame->meta,
        .iov_len = sizeof frame->meta,
    };
    struct msghdr msg = {
        .msg_iov = &iov,
        .msg_iovlen = 1,
        .msg_control = control,
        .msg_controllen = sizeof control,
    };
    ssize_t n = recvmsg(fd, &msg, 0);
    if (n <= 0) {
        free(frame);
        return n == 0 ? ECONNRESET : errno;
    }
    if ((size_t) n != sizeof frame->meta ||
        frame->meta.magic != BEENUT_DMABUF_MAGIC ||
        frame->meta.version != BEENUT_DMABUF_VERSION ||
        frame->meta.n_planes == 0 ||
        frame->meta.n_planes > BEENUT_DMABUF_MAX_PLANES) {
        free(frame);
        return EPROTO;
    }

    struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
    if (cmsg == NULL || cmsg->cmsg_level != SOL_SOCKET || cmsg->cmsg_type != SCM_RIGHTS) {
        free(frame);
        return EPROTO;
    }

    size_t fd_count = (cmsg->cmsg_len - CMSG_LEN(0)) / sizeof(int);
    if (fd_count < frame->meta.n_planes) {
        free(frame);
        return EPROTO;
    }
    memcpy(frame->fds, CMSG_DATA(cmsg), sizeof(int) * frame->meta.n_planes);
    *frame_out = frame;
    return 0;
}

static void *receiver_main(void *userdata) {
    struct bridge_state *state = userdata;
    while (state->running) {
        struct bridge_frame *frame = NULL;
        int ok = receive_frame(state->socket_fd, &frame);
        if (ok != 0) {
            if (ok != EAGAIN && ok != EINTR && state->running) {
                usleep(10000);
            }
            continue;
        }
        state->pushed_frame_index = frame->meta.frame_index;
        texture_push_unresolved_frame(
            state->texture,
            &(const struct unresolved_texture_frame){
                .resolve = resolve_dmabuf_frame,
                .destroy = destroy_bridge_frame,
                .userdata = frame,
            }
        );
    }
    return NULL;
}

static const char *stdmap_string_arg(struct std_value *map, const char *key) {
    struct std_value *value = stdmap_get_str(map, (char *) key);
    if (value == NULL || !STDVALUE_IS_STRING(*value)) {
        return NULL;
    }
    return STDVALUE_AS_STRING(*value);
}

static int connect_socket(const char *path) {
    int fd = socket(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0);
    if (fd < 0) {
        return -1;
    }
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof addr);
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
    if (connect(fd, (struct sockaddr *) &addr, sizeof addr) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static int on_method_call(char *channel, struct platch_obj *object, FlutterPlatformMessageResponseHandle *responsehandle) {
    (void) channel;
    struct bridge_state *state = plugin_registry_get_plugin_userdata(flutterpi_get_plugin_registry(flutterpi), "beenut_preview_bridge");
    if (state == NULL || object->method == NULL) {
        return platch_respond_illegal_arg_std(responsehandle, "Bridge is not initialized.");
    }

    if (strcmp(object->method, "create") == 0) {
        if (!STDVALUE_IS_MAP(object->std_arg)) {
            return platch_respond_illegal_arg_std(responsehandle, "Expected map args.");
        }
        const char *path = stdmap_string_arg(&object->std_arg, "path");
        if (path == NULL) {
            return platch_respond_illegal_arg_std(responsehandle, "Missing socket path.");
        }

        if (state->texture == NULL) {
            state->texture = flutterpi_create_texture(state->flutterpi);
            if (state->texture == NULL) {
                return platch_respond_native_error_std(responsehandle, ENOMEM);
            }
        }
        if (state->socket_fd >= 0) {
            close(state->socket_fd);
            state->socket_fd = -1;
        }
        state->socket_fd = connect_socket(path);
        if (state->socket_fd < 0) {
            return platch_respond_native_error_std(responsehandle, errno);
        }
        state->running = true;
        pthread_create(&state->thread, NULL, receiver_main, state);

        struct std_value result = STDINT64(texture_get_id(state->texture));
        return platch_respond_success_std(responsehandle, &result);
    }

    if (strcmp(object->method, "dispose") == 0) {
        state->running = false;
        if (state->socket_fd >= 0) {
            shutdown(state->socket_fd, SHUT_RDWR);
        }
        if (state->thread) {
            pthread_join(state->thread, NULL);
            state->thread = 0;
        }
        if (state->socket_fd >= 0) {
            close(state->socket_fd);
            state->socket_fd = -1;
        }
        if (state->texture != NULL) {
            texture_destroy(state->texture);
            state->texture = NULL;
        }
        return platch_respond_success_std(responsehandle, &STDNULL);
    }

    return platch_respond_not_implemented(responsehandle);
}

static enum plugin_init_result bridge_init(struct flutterpi *flutterpi_instance, void **userdata_out) {
    struct bridge_state *state = calloc(1, sizeof *state);
    if (state == NULL) {
        return PLUGIN_INIT_RESULT_ERROR;
    }
    state->flutterpi = flutterpi_instance;
    state->socket_fd = -1;
    int ok = plugin_registry_set_receiver(BEENUT_PREVIEW_CHANNEL, kStandardMethodCall, on_method_call);
    if (ok != 0) {
        free(state);
        return PLUGIN_INIT_RESULT_ERROR;
    }
    *userdata_out = state;
    return PLUGIN_INIT_RESULT_INITIALIZED;
}

static void bridge_deinit(struct flutterpi *flutterpi_instance, void *userdata) {
    (void) flutterpi_instance;
    struct bridge_state *state = userdata;
    if (state == NULL) {
        return;
    }
    state->running = false;
    if (state->socket_fd >= 0) {
        shutdown(state->socket_fd, SHUT_RDWR);
    }
    if (state->thread) {
        pthread_join(state->thread, NULL);
    }
    if (state->socket_fd >= 0) {
        close(state->socket_fd);
    }
    if (state->texture != NULL) {
        texture_destroy(state->texture);
    }
    free(state->socket_path);
    free(state);
}

FLUTTERPI_PLUGIN("beenut_preview_bridge", beenut_preview_bridge, bridge_init, bridge_deinit)

