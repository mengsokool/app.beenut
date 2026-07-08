#include "gstreamer_camera.h"
#include "hardware_discovery.h"

#include <QFile>
#include <QFileInfo>
#include <QHostAddress>
#include <QStringList>
#include <QtGlobal>

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstring>
#include <utility>

#ifndef Q_OS_WIN
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#else
#include <windows.h>
#endif

#ifdef __linux__
#include <gst/allocators/gstdmabuf.h>
#include <sys/socket.h>
#include <sys/un.h>
#endif

#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <CoreVideo/CoreVideo.h>
#include <IOSurface/IOSurface.h>
#endif

namespace {

constexpr quint32 kPreviewMagic = 0x31565342;  // BSV1
constexpr quint32 kPreviewVersion = 1;
constexpr quint32 kStorageShmNv12 = 0;
constexpr quint32 kStorageIoSurfaceNv12 = 1;
constexpr int kIoSurfacePreviewBufferCount = 3;

struct PreviewShmHeader {
    quint32 magic = kPreviewMagic;
    quint32 version = kPreviewVersion;
    quint32 headerSize = sizeof(PreviewShmHeader);
    quint32 width = 0;
    quint32 height = 0;
    quint32 yStride = 0;
    quint32 uvStride = 0;
    quint32 yOffset = sizeof(PreviewShmHeader);
    quint32 uvOffset = 0;
    quint64 frameSize = 0;
    quint64 frameIndex = 0;
    quint64 timestampNs = 0;
    quint32 storageMode = kStorageShmNv12;
    quint32 surfaceId = 0;
};

GstPadProbeReturn countFrameProbe(GstPad*, GstPadProbeInfo* info, gpointer userData)
{
    if ((GST_PAD_PROBE_INFO_TYPE(info) & GST_PAD_PROBE_TYPE_BUFFER) != 0) {
        static_cast<beenut::GStreamerCamera*>(userData)->noteCapturedFrame();
    }
    return GST_PAD_PROBE_OK;
}

}  // namespace

namespace beenut {

GStreamerCamera::GStreamerCamera(CameraConfig config, QString previewSocket, int aiInputSize, double aiMaxFps, QObject* parent)
    : QObject(parent),
      config_(std::move(config)),
      previewSocket_(std::move(previewSocket)),
      aiInputSize_(aiInputSize),
      aiMaxFps_(std::max(1.0, aiMaxFps)),
      effectiveFps_(std::max(1, config_.fps))
{
    statsTimer_.setInterval(1000);
    connect(&statsTimer_, &QTimer::timeout, this, &GStreamerCamera::refreshStats);
    previewTimer_.setTimerType(Qt::PreciseTimer);
    connect(&previewTimer_, &QTimer::timeout, this, &GStreamerCamera::publishPreviewFrame);
    connect(&previewServer_, &QTcpServer::newConnection, this, &GStreamerCamera::acceptPreviewClient);
}

GStreamerCamera::~GStreamerCamera()
{
    stop();
}

bool GStreamerCamera::start()
{
    stop();
    effectiveFps_ = std::max(1, lowPowerMode_ ? std::min(config_.fps, std::max(1, config_.idleFps)) : config_.fps);
    framesSeen_ = 0;
    lastFramesSeen_ = 0;
    captureFps_ = 0.0;

    GError* error = nullptr;
    const auto description = pipelineDescription();
    pipeline_ = gst_parse_launch(description.toUtf8().constData(), &error);
    if (error != nullptr) {
        detail_ = QString::fromUtf8(error->message);
        g_error_free(error);
        ready_ = false;
        return false;
    }

    aiSink_ = GST_APP_SINK(gst_bin_get_by_name(GST_BIN(pipeline_), "ai_sink"));
    if (aiSink_ == nullptr) {
        detail_ = "ai_sink not found";
        stop();
        return false;
    }
    gst_app_sink_set_drop(aiSink_, true);
    gst_app_sink_set_max_buffers(aiSink_, 1);

    previewSink_ = GST_APP_SINK(gst_bin_get_by_name(GST_BIN(pipeline_), "preview_sink"));
    if (previewSink_ == nullptr) {
        detail_ = "preview_sink not found";
        stop();
        return false;
    }
    gst_app_sink_set_drop(previewSink_, true);
    gst_app_sink_set_max_buffers(previewSink_, 1);

    if (auto* counter = gst_bin_get_by_name(GST_BIN(pipeline_), "frame_counter")) {
        if (auto* pad = gst_element_get_static_pad(counter, "src")) {
            gst_pad_add_probe(pad, GST_PAD_PROBE_TYPE_BUFFER, countFrameProbe, this, nullptr);
            gst_object_unref(pad);
        }
        gst_object_unref(counter);
    }

    ready_ = gst_element_set_state(pipeline_, GST_STATE_PLAYING) != GST_STATE_CHANGE_FAILURE;
    detail_ = ready_ ? description : "failed to start GStreamer pipeline";
    if (ready_) {
        previewTimer_.setInterval(std::max(1, 1000 / effectiveFps_));
        startDmaBufServer();
        statsTimer_.start();
        previewTimer_.start();
    }
    return ready_;
}

bool GStreamerCamera::reload(CameraConfig config)
{
    config_ = std::move(config);
    lowPowerMode_ = false;
    return start();
}

bool GStreamerCamera::setAiMaxFps(double fps)
{
    const double nextFps = std::max(1.0, fps);
    if (qFuzzyCompare(aiMaxFps_, nextFps)) {
        return ready_;
    }
    aiMaxFps_ = nextFps;
    if (!ready_) {
        return start();
    }
    return start();
}

bool GStreamerCamera::setLowPowerMode(bool enabled)
{
    if (lowPowerMode_ == enabled) {
        return ready_;
    }
    lowPowerMode_ = enabled;
    if (!ready_) {
        return start();
    }
    return start();
}

void GStreamerCamera::stop()
{
    statsTimer_.stop();
    previewTimer_.stop();
    for (auto* client : std::as_const(previewClients_)) {
        client->disconnectFromHost();
        client->deleteLater();
    }
    previewClients_.clear();
    previewServer_.close();
    stopDmaBufServer();
    closePreviewMapping();
    if (pipeline_ != nullptr) {
        gst_element_set_state(pipeline_, GST_STATE_NULL);
    }
    if (aiSink_ != nullptr) {
        gst_object_unref(aiSink_);
        aiSink_ = nullptr;
    }
    if (previewSink_ != nullptr) {
        gst_object_unref(previewSink_);
        previewSink_ = nullptr;
    }
    if (pipeline_ != nullptr) {
        gst_object_unref(pipeline_);
        pipeline_ = nullptr;
    }
    ready_ = false;
}

bool GStreamerCamera::isReady() const { return ready_; }
QString GStreamerCamera::detail() const { return detail_; }
QString GStreamerCamera::previewCaps() const { return QString("%1,format=NV12").arg(previewCapsDescription()); }
QString GStreamerCamera::previewTransport() const
{
#ifdef __linux__
    if (useDmaBufPreview()) {
        return "dmabuf_egl";
    }
#endif
#ifdef __APPLE__
    if (useIoSurfacePreview()) {
        return "iosurface_nv12";
    }
#endif
    return "shm_nv12";
}

bool GStreamerCamera::useDmaBufPreview() const
{
#ifdef __linux__
    if (config_.previewTransport == "dmabuf_egl") {
        return true;
    }
    if (config_.previewTransport == "shm_nv12") {
        return false;
    }
    return (config_.source == "libcamera" || config_.source == "picamera2") && QFileInfo::exists("/dev/dri");
#else
    return false;
#endif
}

bool GStreamerCamera::useIoSurfacePreview() const
{
#ifdef __APPLE__
    if (config_.previewTransport == "iosurface_nv12") {
        return true;
    }
    if (config_.previewTransport == "shm_nv12") {
        return false;
    }
    return qEnvironmentVariable("BEENUT_PREVIEW_IOSURFACE") == "1";
#else
    return false;
#endif
}

QString GStreamerCamera::previewUrl() const
{
#ifdef __linux__
    if (useDmaBufPreview()) {
        return QString("%1.dmabuf").arg(previewSocket_);
    }
#endif
    return previewSocket_;
}
double GStreamerCamera::captureFps() const { return captureFps_; }

GstSample* GStreamerCamera::pullAiSample()
{
    return aiSink_ == nullptr ? nullptr : gst_app_sink_try_pull_sample(aiSink_, 0);
}

void GStreamerCamera::noteCapturedFrame()
{
    ++framesSeen_;
}

void GStreamerCamera::refreshStats()
{
    captureFps_ = static_cast<double>(framesSeen_ - lastFramesSeen_);
    lastFramesSeen_ = framesSeen_;
}

void GStreamerCamera::acceptPreviewClient()
{
    while (previewServer_.hasPendingConnections()) {
        auto* client = previewServer_.nextPendingConnection();
        previewClients_.insert(client);
        connect(client, &QTcpSocket::disconnected, this, &GStreamerCamera::removePreviewClient);
        client->write("HTTP/1.1 200 OK\r\n"
                      "Connection: close\r\n"
                      "Cache-Control: no-cache, no-store, must-revalidate\r\n"
                      "Pragma: no-cache\r\n"
                      "Content-Type: multipart/x-mixed-replace; boundary=beenut\r\n\r\n");
        client->flush();
    }
}

void GStreamerCamera::removePreviewClient()
{
    auto* client = qobject_cast<QTcpSocket*>(sender());
    if (client == nullptr) {
        return;
    }
    previewClients_.remove(client);
    client->deleteLater();
}

void GStreamerCamera::publishPreviewFrame()
{
    if (previewSink_ == nullptr) {
        return;
    }
    auto* sample = gst_app_sink_try_pull_sample(previewSink_, 0);
    if (sample == nullptr) {
        return;
    }

    auto* buffer = gst_sample_get_buffer(sample);
    auto* caps = gst_sample_get_caps(sample);
    if (buffer == nullptr || caps == nullptr) {
        gst_sample_unref(sample);
        return;
    }

    GstVideoInfo info;
    if (!gst_video_info_from_caps(&info, caps)) {
        gst_sample_unref(sample);
        return;
    }
    
    if (auto* meta = gst_buffer_get_video_meta(buffer)) {
        info.width = meta->width;
        info.height = meta->height;
    }

    if (GST_VIDEO_INFO_FORMAT(&info) != GST_VIDEO_FORMAT_NV12 || GST_VIDEO_INFO_N_PLANES(&info) < 2) {
        gst_sample_unref(sample);
        return;
    }

    if (publishDmaBufFrame(sample, info)) {
        gst_sample_unref(sample);
        return;
    }

    GstVideoFrame frame;
    if (!gst_video_frame_map(&frame, &info, buffer, GST_MAP_READ)) {
        gst_sample_unref(sample);
        return;
    }

    const auto width = static_cast<int>(GST_VIDEO_INFO_WIDTH(&info));
    const auto height = static_cast<int>(GST_VIDEO_INFO_HEIGHT(&info));
    const auto yStride = width;
    const auto uvStride = width;
    const auto yBytes = static_cast<qsizetype>(yStride) * height;
    const auto uvBytes = static_cast<qsizetype>(uvStride) * ((height + 1) / 2);
    const auto frameSize = yBytes + uvBytes;

    if (ensurePreviewMapping(width, height, yStride, uvStride, frameSize) && previewMap_ != nullptr) {
        auto* header = reinterpret_cast<PreviewShmHeader*>(previewMap_);
        const auto nextFrameIndex = previewFrameIndex_ + 2;
        header->frameIndex = nextFrameIndex - 1;
        const auto* ySrc = static_cast<const uchar*>(GST_VIDEO_FRAME_PLANE_DATA(&frame, 0));
        const auto* uvSrc = static_cast<const uchar*>(GST_VIDEO_FRAME_PLANE_DATA(&frame, 1));
        const auto srcYStride = GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 0);
        const auto srcUvStride = GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 1);

#ifdef __APPLE__
        CVPixelBufferRef previewPixelBuffer = nullptr;
        quint32 previewSurfaceId = 0;
        if (previewUsesIoSurface_ && !previewPixelBuffers_.isEmpty()) {
            previewSurfaceCursor_ = (previewSurfaceCursor_ + 1) % previewPixelBuffers_.size();
            previewPixelBuffer = static_cast<CVPixelBufferRef>(previewPixelBuffers_.at(previewSurfaceCursor_));
            previewSurfaceId = previewSurfaceIds_.at(previewSurfaceCursor_);
        }
        if (previewPixelBuffer != nullptr && previewSurfaceId != 0) {
            auto* pixelBuffer = previewPixelBuffer;
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            auto* yDst = static_cast<uchar*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
            auto* uvDst = static_cast<uchar*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
            const auto dstYStride = static_cast<int>(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0));
            const auto dstUvStride = static_cast<int>(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1));
            if (yDst != nullptr && uvDst != nullptr) {
                for (int row = 0; row < height; ++row) {
                    std::memcpy(yDst + row * dstYStride, ySrc + row * srcYStride, static_cast<size_t>(width));
                }
                for (int row = 0; row < (height + 1) / 2; ++row) {
                    std::memcpy(uvDst + row * dstUvStride, uvSrc + row * srcUvStride, static_cast<size_t>(width));
                }
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        }
#endif
        {
            auto* yDst = previewMap_ + header->yOffset;
            auto* uvDst = previewMap_ + header->uvOffset;
            for (int row = 0; row < height; ++row) {
                std::memcpy(yDst + row * yStride, ySrc + row * srcYStride, static_cast<size_t>(width));
            }
            for (int row = 0; row < (height + 1) / 2; ++row) {
                std::memcpy(uvDst + row * uvStride, uvSrc + row * srcUvStride, static_cast<size_t>(width));
            }
        }
        header->timestampNs = static_cast<quint64>(GST_BUFFER_PTS_IS_VALID(buffer) ? GST_BUFFER_PTS(buffer) : 0);
#ifdef __APPLE__
        if (previewPixelBuffer != nullptr && previewSurfaceId != 0) {
            header->storageMode = kStorageIoSurfaceNv12;
            header->surfaceId = previewSurfaceId;
        } else {
            header->storageMode = kStorageShmNv12;
            header->surfaceId = 0;
        }
#endif
        previewFrameIndex_ = nextFrameIndex;
        header->frameIndex = previewFrameIndex_;
    }

    gst_video_frame_unmap(&frame);
    gst_sample_unref(sample);
}

bool GStreamerCamera::publishDmaBufFrame(GstSample* sample, const GstVideoInfo& info)
{
#ifdef __linux__
    if (!useDmaBufPreview()) {
        return false;
    }
    auto* buffer = gst_sample_get_buffer(sample);
    if (buffer == nullptr) {
        return false;
    }
    acceptDmaBufClients();
    if (dmaBufClientFds_.isEmpty()) {
        return false;
    }

    const auto memoryCount = gst_buffer_n_memory(buffer);
    if (memoryCount == 0 || memoryCount > 4) {
        return false;
    }

    struct DmaBufFrameWire {
        quint32 magic;
        quint32 version;
        quint32 width;
        quint32 height;
        quint32 fourcc;
        quint32 nPlanes;
        quint64 modifier;
        quint64 frameIndex;
        quint32 offsets[4];
        quint32 strides[4];
    } wire {};
    wire.magic = 0x31464244u;
    wire.version = 1;
    wire.width = static_cast<quint32>(GST_VIDEO_INFO_WIDTH(&info));
    wire.height = static_cast<quint32>(GST_VIDEO_INFO_HEIGHT(&info));
    wire.fourcc = 0x3231564Eu;  // DRM_FORMAT_NV12
    wire.nPlanes = static_cast<quint32>(GST_VIDEO_INFO_N_PLANES(&info));
    wire.modifier = 0;
    wire.frameIndex = previewFrameIndex_ + 2;
    for (quint32 plane = 0; plane < wire.nPlanes; ++plane) {
        wire.offsets[plane] = static_cast<quint32>(GST_VIDEO_INFO_PLANE_OFFSET(&info, plane));
        wire.strides[plane] = static_cast<quint32>(GST_VIDEO_INFO_PLANE_STRIDE(&info, plane));
    }

    int fds[4] = {-1, -1, -1, -1};
    for (quint32 plane = 0; plane < wire.nPlanes; ++plane) {
        GstMemory* memory = gst_buffer_peek_memory(buffer, plane < memoryCount ? plane : 0);
        if (memory == nullptr || !gst_is_dmabuf_memory(memory)) {
            for (int fd : fds) {
                if (fd >= 0) {
                    ::close(fd);
                }
            }
            return false;
        }
        const int fd = gst_dmabuf_memory_get_fd(memory);
        fds[plane] = ::dup(fd);
        if (fds[plane] < 0) {
            for (int existing : fds) {
                if (existing >= 0) {
                    ::close(existing);
                }
            }
            return false;
        }
    }

    char control[CMSG_SPACE(sizeof(int) * 4)] {};
    struct iovec iov {
        .iov_base = &wire,
        .iov_len = sizeof(wire),
    };
    struct msghdr msg {};
    msg.msg_iov = &iov;
    msg.msg_iovlen = 1;
    msg.msg_control = control;
    msg.msg_controllen = CMSG_SPACE(sizeof(int) * wire.nPlanes);
    auto* cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    cmsg->cmsg_len = CMSG_LEN(sizeof(int) * wire.nPlanes);
    std::memcpy(CMSG_DATA(cmsg), fds, sizeof(int) * wire.nPlanes);

    QVector<int> alive;
    for (int clientFd : std::as_const(dmaBufClientFds_)) {
        if (::sendmsg(clientFd, &msg, MSG_NOSIGNAL) >= 0) {
            alive.append(clientFd);
        } else {
            ::close(clientFd);
        }
    }
    dmaBufClientFds_ = alive;
    for (int fd : fds) {
        if (fd >= 0) {
            ::close(fd);
        }
    }
    previewFrameIndex_ = wire.frameIndex;
    return !dmaBufClientFds_.isEmpty();
#else
    Q_UNUSED(sample);
    Q_UNUSED(info);
    return false;
#endif
}

void GStreamerCamera::startDmaBufServer()
{
#ifdef __linux__
    if (!useDmaBufPreview()) {
        return;
    }
    if (dmaBufServerFd_ >= 0) {
        return;
    }
    const auto socketPath = previewUrl();
    QFile::remove(socketPath);
    dmaBufServerFd_ = ::socket(AF_UNIX, SOCK_SEQPACKET | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
    if (dmaBufServerFd_ < 0) {
        return;
    }
    struct sockaddr_un addr {};
    addr.sun_family = AF_UNIX;
    const auto pathBytes = socketPath.toUtf8();
    std::strncpy(addr.sun_path, pathBytes.constData(), sizeof(addr.sun_path) - 1);
    if (::bind(dmaBufServerFd_, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) != 0
        || ::listen(dmaBufServerFd_, 2) != 0) {
        ::close(dmaBufServerFd_);
        dmaBufServerFd_ = -1;
    }
#endif
}

void GStreamerCamera::stopDmaBufServer()
{
#ifdef __linux__
    for (int fd : std::as_const(dmaBufClientFds_)) {
        ::close(fd);
    }
    dmaBufClientFds_.clear();
    if (dmaBufServerFd_ >= 0) {
        ::close(dmaBufServerFd_);
        dmaBufServerFd_ = -1;
    }
    QFile::remove(QString("%1.dmabuf").arg(previewSocket_));
#endif
}

void GStreamerCamera::acceptDmaBufClients()
{
#ifdef __linux__
    if (dmaBufServerFd_ < 0) {
        startDmaBufServer();
    }
    if (dmaBufServerFd_ < 0) {
        return;
    }
    while (true) {
        const int fd = ::accept4(dmaBufServerFd_, nullptr, nullptr, SOCK_NONBLOCK | SOCK_CLOEXEC);
        if (fd < 0) {
            break;
        }
        dmaBufClientFds_.append(fd);
    }
#endif
}

QString GStreamerCamera::sourcePipeline() const
{
    if (config_.source == "mock") {
        return "videotestsrc is-live=true pattern=ball";
    }
    if (config_.source == "avfoundation") {
        const int index = resolveAVFoundationDeviceIndex(config_.device);
        const int w = config_.width > 0 ? config_.width : 1280;
        const int h = config_.height > 0 ? config_.height : 720;
        return QString("avfvideosrc device-index=%1 ! video/x-raw,width=%2,height=%3").arg(index).arg(w).arg(h);
    }
    if (config_.source == "dshow" || config_.source == "directshow") {
        const auto device = config_.device.isEmpty() ? "0" : config_.device;
        bool isIndex = false;
        device.toInt(&isIndex);
        if (isIndex) {
            return QString("dshowvideosrc device-index=%1").arg(device);
        } else {
            return QString("dshowvideosrc device-name=\"%1\"").arg(device);
        }
    }
    if (config_.source == "picamera2" || config_.source == "libcamera") {
        if (config_.device.isEmpty()) {
            return "libcamerasrc";
        }
        return QString("libcamerasrc camera-name=%1").arg(config_.device);
    }
    if (config_.source == "v4l2" && !config_.device.isEmpty()) {
        return QString("v4l2src device=%1").arg(config_.device);
    }
    return "autovideosrc";
}

QString GStreamerCamera::previewCapsDescription() const
{
    const int w = config_.width > 0 ? config_.width : 1280;
    const int h = config_.height > 0 ? config_.height : 720;
    const int size = std::min(w, h);
    return QString("video/x-raw,width=%1,height=%2,framerate=%3/1")
        .arg(size)
        .arg(size)
        .arg(effectiveFps_);
}

QString GStreamerCamera::pipelineDescription() const
{
    const int aiFps = std::max(1, std::min(effectiveFps_, static_cast<int>(std::ceil(aiMaxFps_))));
    QStringList sharedTransforms;
    if (config_.flipHorizontal) {
        sharedTransforms << "videoflip method=horizontal-flip";
    }
    if (config_.flipVertical) {
        sharedTransforms << "videoflip method=vertical-flip";
    }

    QStringList aiTransforms = sharedTransforms;
    aiTransforms << "videoconvert"
                 << "videoscale"
                 << "videorate"
                 << QString("video/x-raw,format=RGB,width=%1,height=%1,framerate=%2/1")
                        .arg(aiInputSize_)
                        .arg(aiFps);

    QStringList previewTransforms = sharedTransforms;
    previewTransforms << "videoscale"
                      << "videorate"
                      << "videoconvert"
                      << QString("%1,format=NV12").arg(previewCapsDescription());

    const int w = config_.width > 0 ? config_.width : 1280;
    const int h = config_.height > 0 ? config_.height : 720;
    int cropLeft = 0;
    int cropRight = 0;
    int cropTop = 0;
    int cropBottom = 0;
    if (w > h) {
        cropLeft = (w - h) / 2;
        cropRight = (w - h) / 2;
    } else if (h > w) {
        cropTop = (h - w) / 2;
        cropBottom = (h - w) / 2;
    }

    QString cropStr = QString("videocrop left=%1 right=%2 top=%3 bottom=%4").arg(cropLeft).arg(cropRight).arg(cropTop).arg(cropBottom);
    QString normalizeStr = QString("videoconvert ! videoscale ! video/x-raw,width=%1,height=%2").arg(w).arg(h);

    return QString(
        "%1 ! %2 ! %3 ! queue leaky=downstream max-size-buffers=2 ! identity name=frame_counter silent=true ! tee name=t "
        "t. ! queue leaky=downstream max-size-buffers=1 ! %4 ! appsink name=ai_sink sync=false max-buffers=1 drop=true "
        "t. ! queue leaky=downstream max-size-buffers=2 ! %5 ! appsink name=preview_sink sync=false max-buffers=1 drop=true")
        .arg(sourcePipeline(), normalizeStr, cropStr, aiTransforms.join(" ! "), previewTransforms.join(" ! "));
}

bool GStreamerCamera::ensurePreviewMapping(int width, int height, int yStride, int uvStride, qsizetype frameSize)
{
    const auto metadataSize = static_cast<qsizetype>(sizeof(PreviewShmHeader));
    const auto requiredSize = metadataSize + frameSize;
    if (previewMap_ != nullptr && previewFrameSize_ == frameSize && previewMapSize_ == requiredSize) {
        return true;
    }

    closePreviewMapping();

#ifndef Q_OS_WIN
    previewFd_ = ::open(previewSocket_.toUtf8().constData(), O_CREAT | O_RDWR, 0600);
    if (previewFd_ < 0) {
        detail_ = QString("%1 · shm open failed: %2").arg(detail_, QString::fromLocal8Bit(std::strerror(errno)));
        return false;
    }
    if (::ftruncate(previewFd_, static_cast<off_t>(requiredSize)) != 0) {
        detail_ = QString("%1 · shm resize failed: %2").arg(detail_, QString::fromLocal8Bit(std::strerror(errno)));
        closePreviewMapping();
        return false;
    }

    previewMap_ = static_cast<uchar*>(::mmap(nullptr, static_cast<size_t>(requiredSize), PROT_READ | PROT_WRITE, MAP_SHARED, previewFd_, 0));
    if (previewMap_ == MAP_FAILED) {
        previewMap_ = nullptr;
        detail_ = QString("%1 · shm mmap failed: %2").arg(detail_, QString::fromLocal8Bit(std::strerror(errno)));
        closePreviewMapping();
        return false;
    }
#else
    std::wstring path = previewSocket_.toStdWString();
    HANDLE fileHandle = CreateFileW(
        path.c_str(),
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        nullptr,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        nullptr
    );
    if (fileHandle == INVALID_HANDLE_VALUE) {
        detail_ = QString("%1 · shm CreateFileW failed: %2").arg(detail_, QString::number(GetLastError()));
        return false;
    }
    previewFileHandle_ = fileHandle;

    std::wstring map_name = L"Local\\";
    size_t last_slash = path.find_last_of(L"/\\");
    std::wstring base_name = (last_slash == std::wstring::npos) ? path : path.substr(last_slash + 1);
    map_name += base_name;

    ULARGE_INTEGER size;
    size.QuadPart = requiredSize;

    HANDLE mappingHandle = CreateFileMappingW(
        fileHandle,
        nullptr,
        PAGE_READWRITE,
        size.HighPart,
        size.LowPart,
        map_name.c_str()
    );
    if (!mappingHandle) {
        detail_ = QString("%1 · shm CreateFileMappingW failed: %2").arg(detail_, QString::number(GetLastError()));
        closePreviewMapping();
        return false;
    }
    previewMappingHandle_ = mappingHandle;

    previewMap_ = static_cast<uchar*>(MapViewOfFile(
        mappingHandle,
        FILE_MAP_ALL_ACCESS,
        0,
        0,
        requiredSize
    ));
    if (!previewMap_) {
        detail_ = QString("%1 · shm MapViewOfFile failed: %2").arg(detail_, QString::number(GetLastError()));
        closePreviewMapping();
        return false;
    }
#endif

    previewMapSize_ = requiredSize;
    previewFrameSize_ = frameSize;
    auto* header = reinterpret_cast<PreviewShmHeader*>(previewMap_);
    *header = PreviewShmHeader{};
    header->width = static_cast<quint32>(width);
    header->height = static_cast<quint32>(height);
    header->yStride = static_cast<quint32>(yStride);
    header->uvStride = static_cast<quint32>(uvStride);
    header->uvOffset = header->yOffset + static_cast<quint32>(static_cast<qsizetype>(yStride) * height);
    header->frameSize = static_cast<quint64>(frameSize);

#ifdef __APPLE__
    previewUsesIoSurface_ = false;
    previewPixelBuffers_.clear();
    previewSurfaceIds_.clear();
    previewSurfaceCursor_ = -1;

    if (useIoSurfacePreview()) {
        CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFMutableDictionaryRef ioSurfaceProps = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        if (attrs != nullptr && ioSurfaceProps != nullptr) {
            // Cross-process IOSurface lookup by ID requires a global surface. The shm mirror below remains valid
            // as a fallback if macOS refuses or changes this import path.
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#endif
            CFDictionarySetValue(ioSurfaceProps, kIOSurfaceIsGlobal, kCFBooleanTrue);
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
            CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, ioSurfaceProps);
            CFDictionarySetValue(attrs, kCVPixelBufferMetalCompatibilityKey, kCFBooleanTrue);
            CFDictionarySetValue(attrs, kCVPixelBufferOpenGLCompatibilityKey, kCFBooleanTrue);
            QVector<void*> pixelBuffers;
            QVector<quint32> surfaceIds;
            for (int i = 0; i < kIoSurfacePreviewBufferCount; ++i) {
                CVPixelBufferRef pixelBuffer = nullptr;
                const auto status = CVPixelBufferCreate(kCFAllocatorDefault,
                                                        width,
                                                        height,
                                                        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                                        attrs,
                                                        &pixelBuffer);
                if (status != kCVReturnSuccess || pixelBuffer == nullptr) {
                    if (pixelBuffer != nullptr) {
                        CVPixelBufferRelease(pixelBuffer);
                    }
                    break;
                }
                auto surface = CVPixelBufferGetIOSurface(pixelBuffer);
                const auto surfaceId = surface == nullptr ? 0 : IOSurfaceGetID(surface);
                if (surfaceId == 0) {
                    CVPixelBufferRelease(pixelBuffer);
                    break;
                }
                pixelBuffers.append(pixelBuffer);
                surfaceIds.append(surfaceId);
            }
            if (pixelBuffers.size() == kIoSurfacePreviewBufferCount) {
                previewPixelBuffers_ = pixelBuffers;
                previewSurfaceIds_ = surfaceIds;
                previewSurfaceCursor_ = -1;
                previewUsesIoSurface_ = true;
                header->storageMode = kStorageIoSurfaceNv12;
                header->surfaceId = previewSurfaceIds_.first();
            } else {
                for (auto* pixelBuffer : std::as_const(pixelBuffers)) {
                    CVPixelBufferRelease(static_cast<CVPixelBufferRef>(pixelBuffer));
                }
            }
        }
        if (ioSurfaceProps != nullptr) {
            CFRelease(ioSurfaceProps);
        }
        if (attrs != nullptr) {
            CFRelease(attrs);
        }
    }
#endif
    return true;
}

void GStreamerCamera::closePreviewMapping()
{
#ifdef __APPLE__
    for (auto* pixelBuffer : std::as_const(previewPixelBuffers_)) {
        CVPixelBufferRelease(static_cast<CVPixelBufferRef>(pixelBuffer));
    }
    previewPixelBuffers_.clear();
    previewSurfaceIds_.clear();
    previewSurfaceCursor_ = -1;
    previewUsesIoSurface_ = false;
#endif
#ifndef Q_OS_WIN
    if (previewMap_ != nullptr) {
        ::munmap(previewMap_, static_cast<size_t>(previewMapSize_));
        previewMap_ = nullptr;
    }
    if (previewFd_ >= 0) {
        ::close(previewFd_);
        previewFd_ = -1;
    }
#else
    if (previewMap_ != nullptr) {
        UnmapViewOfFile(previewMap_);
        previewMap_ = nullptr;
    }
    if (previewMappingHandle_ != nullptr) {
        CloseHandle(static_cast<HANDLE>(previewMappingHandle_));
        previewMappingHandle_ = nullptr;
    }
    if (previewFileHandle_ != nullptr && previewFileHandle_ != INVALID_HANDLE_VALUE) {
        CloseHandle(static_cast<HANDLE>(previewFileHandle_));
        previewFileHandle_ = nullptr;
    }
#endif
    previewMapSize_ = 0;
    previewFrameSize_ = 0;
}

}  // namespace beenut
