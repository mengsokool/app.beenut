#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QString>

namespace beenut {

struct Detection {
    QString label;
    double confidence = 0.0;
    double x = 0.0;
    double y = 0.0;
    double w = 0.0;
    double h = 0.0;
};

struct ServiceState {
    bool safeMode = false;
    bool previewPaused = false;
    bool trayPresent = false;
    bool lightOn = false;
    QString selectedPartType;
    int count = 0;
    int processingMs = 0;
    bool countTestRunning = false;
    bool countTestSuccess = false;
    QString countTestMessage;
    QString camera = "missing";
    QString model = "missing";
    QString gpio = "mock";
    QString cameraDetail;
    QString modelDetail;
    QString gpioDetail;
    QString previewTransport = "gstreamer-shm";
    QString previewUrl;
    QString previewCaps;
    QStringList modelLabels;
    double captureFps = 0.0;
    double inferenceFps = 0.0;
    double cpuUsage = 0.0;
    double ramUsage = 0.0;
    double temperature = 0.0;
    QString thermalState = "unknown";
    QString thermalDetail;
    double effectiveAiMaxFps = 0.0;
    double daemonCpu = 0.0;
    double daemonRam = 0.0;
    double flutterCpu = 0.0;
    double flutterRam = 0.0;
    QVector<Detection> detections;
};

QJsonObject toJson(const Detection& detection);
QJsonObject toJson(const ServiceState& state);

}  // namespace beenut
