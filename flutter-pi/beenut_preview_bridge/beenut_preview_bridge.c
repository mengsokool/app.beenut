#include "beenut_preview_bridge.h"

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdatomic.h>
#include "shm_preview.h"
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
    int release_fd;
};

struct resolved_frame {
    EGLDisplay display;
    EGLImageKHR image;
    GLuint texture;
    int release_fd;
    uint64_t frame_index;
};

struct bridge_state {
    struct flutterpi *flutterpi;
    struct texture *texture;
    pthread_t thread;
    atomic_bool running;
    bool thread_started;
    int socket_fd;
    char *socket_path;
    uint64_t pushed_frame_index;
};

static void release_producer(int fd, uint64_t index, bool failed) {
    if (fd < 0) return;
    struct beenut_dmabuf_release release = {.frame_index=index, .import_failed=failed};
    send(fd, &release, sizeof release, MSG_NOSIGNAL | MSG_DONTWAIT);
    close(fd);
}

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
        release_producer(frame->release_fd, frame->meta.frame_index, false);
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
    release_producer(resolved->release_fd, resolved->frame_index, false);
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
        if (frame) { release_producer(frame->release_fd, frame->meta.frame_index, true); frame->release_fd = -1; }
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
        release_producer(frame->release_fd, frame->meta.frame_index, true); frame->release_fd = -1;
        return EIO;
    }

    GLuint texture = 0;
    glGenTextures(1, &texture);
    GLint previous_texture; glGetIntegerv(GL_TEXTURE_BINDING_EXTERNAL_OES, &previous_texture);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, texture);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    image_target(GL_TEXTURE_EXTERNAL_OES, image);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, previous_texture);

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
    resolved->release_fd = frame->release_fd;
    resolved->frame_index = frame->meta.frame_index;
    frame->release_fd = -1;

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
    if (!frame) return ENOMEM;
    frame->release_fd = -1;
    for (uint32_t i = 0; i < BEENUT_DMABUF_MAX_PLANES; i++) frame->fds[i] = -1;
    char control[CMSG_SPACE(sizeof(int) * BEENUT_DMABUF_MAX_PLANES)] = {0};
    struct iovec iov = {.iov_base = &frame->meta, .iov_len = sizeof frame->meta};
    struct msghdr msg = {.msg_iov=&iov, .msg_iovlen=1, .msg_control=control, .msg_controllen=sizeof control};
    ssize_t n = recvmsg(fd, &msg, MSG_CMSG_CLOEXEC);
    if (n <= 0) { free(frame); return n == 0 ? ECONNRESET : errno; }
    size_t count = 0;
    for (struct cmsghdr *cmsg=CMSG_FIRSTHDR(&msg); cmsg; cmsg=CMSG_NXTHDR(&msg,cmsg)) {
        if (cmsg->cmsg_level != SOL_SOCKET || cmsg->cmsg_type != SCM_RIGHTS || cmsg->cmsg_len < CMSG_LEN(0)) continue;
        size_t available = (cmsg->cmsg_len-CMSG_LEN(0))/sizeof(int);
        int *fds = (int *) CMSG_DATA(cmsg);
        for (size_t i=0; i<available; i++) {
            if (count < BEENUT_DMABUF_MAX_PLANES) frame->fds[count++] = fds[i];
            else close(fds[i]);
        }
    }
    if ((msg.msg_flags & (MSG_TRUNC|MSG_CTRUNC)) || (size_t)n != sizeof frame->meta ||
        frame->meta.magic != BEENUT_DMABUF_MAGIC || frame->meta.version != BEENUT_DMABUF_VERSION ||
        frame->meta.width == 0 || frame->meta.height == 0 ||
        frame->meta.n_planes == 0 || frame->meta.n_planes > BEENUT_DMABUF_MAX_PLANES ||
        count != frame->meta.n_planes) { destroy_bridge_frame(frame); return EPROTO; }
    frame->release_fd = fcntl(fd, F_DUPFD_CLOEXEC, 0);
    if (frame->release_fd < 0) { destroy_bridge_frame(frame); return errno; }
    *frame_out = frame;
    return 0;
}

static int connect_socket(const char *path);
static void *receiver_main(void *userdata) {
    struct bridge_state *state = userdata;
    size_t length = strlen(state->socket_path);
    bool dma = length > 7 && strcmp(state->socket_path+length-7, ".dmabuf") == 0;
    char *shm_path = strdup(state->socket_path);
    if (!shm_path) return NULL;
    if (dma) shm_path[length-7] = '\0';
    unsigned retries = 0;
    while (atomic_load(&state->running)) {
        bool pushed = false;
        if (dma) {
            if (state->socket_fd < 0 && retries++ % 10 == 0) {
                state->socket_fd = connect_socket(state->socket_path);
            }
            if (state->socket_fd >= 0) {
                struct pollfd pollfd = {.fd=state->socket_fd, .events=POLLIN};
                int ready = poll(&pollfd, 1, 0);
                if (ready > 0 && (pollfd.revents & POLLIN)) {
                    struct bridge_frame *frame = NULL;
                    int ok = receive_frame(state->socket_fd, &frame);
                    if (!ok) {
                        struct unresolved_texture_frame unresolved = {
                            .resolve=resolve_dmabuf_frame, .destroy=destroy_bridge_frame, .userdata=frame};
                        if (texture_push_unresolved_frame(state->texture, &unresolved)) destroy_bridge_frame(frame);
                        pushed = true;
                    } else if (ok != EAGAIN && ok != EINTR) {
                        close(state->socket_fd); state->socket_fd = -1;
                    }
                } else if (ready > 0 && (pollfd.revents & (POLLHUP|POLLERR|POLLNVAL))) {
                    close(state->socket_fd); state->socket_fd = -1;
                }
            }
        }
        // Backend writes SHM when a camera cannot supply DMA-BUF frames.
        if (!pushed) {
            struct beenut_shm_frame *frame = beenut_read_shm_frame(shm_path, state->pushed_frame_index);
            if (frame) {
                state->pushed_frame_index = frame->index;
                struct unresolved_texture_frame unresolved = {
                    .resolve=beenut_resolve_shm_frame, .destroy=free, .userdata=frame};
                if (texture_push_unresolved_frame(state->texture, &unresolved)) free(frame);
            }
        }
        usleep(16000);
    }
    if (state->socket_fd >= 0) { close(state->socket_fd); state->socket_fd = -1; }
    free(shm_path);
    return NULL;
}

static void stop_receiver(struct bridge_state *state) {
    atomic_store(&state->running, false);
    if (state->thread_started) { pthread_join(state->thread, NULL); state->thread_started = false; }
    if (state->texture) { texture_destroy(state->texture); state->texture = NULL; }
    free(state->socket_path); state->socket_path = NULL;
    state->pushed_frame_index = 0;
}

static const char *stdmap_string_arg(struct std_value *map, const char *key) {
    struct std_value *value = stdmap_get_str(map, (char *) key);
    if (value == NULL || !STDVALUE_IS_STRING(*value)) {
        return NULL;
    }
    return STDVALUE_AS_STRING(*value);
}

static int connect_socket(const char *path) {
    int fd = socket(AF_UNIX, SOCK_SEQPACKET | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
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

        if (strlen(path) >= sizeof(((struct sockaddr_un *) 0)->sun_path)) {
            return platch_respond_illegal_arg_std(responsehandle, "Preview path is too long.");
        }
        stop_receiver(state);
        state->socket_path = strdup(path);
        state->texture = flutterpi_create_texture(state->flutterpi);
        if (!state->socket_path || !state->texture) {
            stop_receiver(state);
            return platch_respond_native_error_std(responsehandle, ENOMEM);
        }
        atomic_store(&state->running, true);
        int ok = pthread_create(&state->thread, NULL, receiver_main, state);
        if (ok) {
            stop_receiver(state);
            return platch_respond_native_error_std(responsehandle, ok);
        }
        state->thread_started = true;
        struct std_value result = STDINT64(texture_get_id(state->texture));
        return platch_respond_success_std(responsehandle, &result);
    }

    if (strcmp(object->method, "dispose") == 0) {
        struct std_value *id = stdmap_get_str(&object->std_arg, "textureId");
        if (state->texture && id) {
            int64_t requested = id->type == kStdInt64 ? id->int64_value :
                                id->type == kStdInt32 ? id->int32_value : -1;
            if (requested != texture_get_id(state->texture))
                return platch_respond_success_std(responsehandle, &STDNULL);
        }
        stop_receiver(state);
        return platch_respond_success_std(responsehandle, &STDNULL);
    }

    return platch_respond_not_implemented(responsehandle);
}

static enum plugin_init_result bridge_init(struct flutterpi *flutterpi_instance, void **userdata_out) {
    if (!flutterpi_has_gl_renderer(flutterpi_instance)) return PLUGIN_INIT_RESULT_NOT_APPLICABLE;
    struct bridge_state *state = calloc(1, sizeof *state);
    if (state == NULL) {
        return PLUGIN_INIT_RESULT_ERROR;
    }
    state->flutterpi = flutterpi_instance;
    state->socket_fd = -1;
    atomic_init(&state->running, false);
    int ok = plugin_registry_set_receiver_locked(BEENUT_PREVIEW_CHANNEL, kStandardMethodCall, on_method_call);
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
    plugin_registry_remove_receiver_locked(BEENUT_PREVIEW_CHANNEL);
    stop_receiver(state);
    free(state);
}

FLUTTERPI_PLUGIN("beenut_preview_bridge", beenut_preview_bridge, bridge_init, bridge_deinit)

