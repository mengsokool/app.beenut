#pragma once

#include "app_config.h"

#include <QObject>
#include <QSet>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QVector>

#include <gst/app/gstappsink.h>
#include <gst/gst.h>
#include <gst/video/video.h>

namespace beenut {

class GStreamerCamera : public QObject {
    Q_OBJECT

public:
    GStreamerCamera(CameraConfig config, QString previewSocket, int aiInputSize, double aiMaxFps, QObject* parent = nullptr);
    ~GStreamerCamera() override;

    bool start();
    bool reload(CameraConfig config);
    bool setAiMaxFps(double fps);
    bool setLowPowerMode(bool enabled);
    void stop();
    bool isReady() const;
    QString detail() const;
    QString previewCaps() const;
    QString previewTransport() const;
    QString previewUrl() const;
    double captureFps() const;
    GstSample* pullAiSample();
    void noteCapturedFrame();

private slots:
    void refreshStats();
    void acceptPreviewClient();
    void removePreviewClient();
    void publishPreviewFrame();

private:
    QString sourcePipeline() const;
    QString previewCapsDescription() const;
    QString pipelineDescription() const;
    bool useDmaBufPreview() const;
    bool useIoSurfacePreview() const;
    bool ensurePreviewMapping(int width, int height, int yStride, int uvStride, qsizetype frameSize);
    void closePreviewMapping();
    bool publishDmaBufFrame(GstSample* sample, const GstVideoInfo& info);
    void startDmaBufServer();
    void stopDmaBufServer();
    void acceptDmaBufClients();

    CameraConfig config_;
    QString previewSocket_;
    int aiInputSize_ = 640;
    double aiMaxFps_ = 10.0;
    int effectiveFps_ = 30;
    bool lowPowerMode_ = false;
    GstElement* pipeline_ = nullptr;
    GstAppSink* aiSink_ = nullptr;
    GstAppSink* previewSink_ = nullptr;
    QTcpServer previewServer_;
    QSet<QTcpSocket*> previewClients_;
    QTimer statsTimer_;
    QTimer previewTimer_;
    int previewFd_ = -1;
#ifdef Q_OS_WIN
    void* previewFileHandle_ = nullptr;
    void* previewMappingHandle_ = nullptr;
#endif
    uchar* previewMap_ = nullptr;
    qsizetype previewMapSize_ = 0;
    qsizetype previewFrameSize_ = 0;
    quint64 previewFrameIndex_ = 0;
    bool previewUsesIoSurface_ = false;
    QVector<void*> previewPixelBuffers_;
    QVector<quint32> previewSurfaceIds_;
    int previewSurfaceCursor_ = -1;
    int dmaBufServerFd_ = -1;
    QVector<int> dmaBufClientFds_;
    quint64 framesSeen_ = 0;
    quint64 lastFramesSeen_ = 0;
    double captureFps_ = 0.0;
    bool ready_ = false;
    QString detail_;
};

}  // namespace beenut
