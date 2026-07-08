#pragma once

#include "app_config.h"
#include "service_state.h"
#include "hardware_discovery.h"

#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QThread>
#include <QElapsedTimer>
#include <memory>

class QCoreApplication;
class QSocketNotifier;

namespace beenut {

class ControlServer;
class GpioController;
class CountingTracker;
class GStreamerCamera;
class OnnxYoloEngine;

struct ThermalPolicy {
    QString state = "unknown";
    QString detail;
    double aiMaxFpsScale = 1.0;
    bool forceLowPower = false;
};

struct RuntimeIntervals {
    int idleInferenceRetryMs = 100;
    int missingAiSampleRetryMs = 2;
    int inferenceFpsWindowMs = 1000;
    int gpioPollMs = 50;
    int systemMetricsMs = 1000;
    int statusBroadcastMs = 250;
};

RuntimeIntervals defaultRuntimeIntervals();

class UnixSignalHandler {
public:
    explicit UnixSignalHandler(QCoreApplication& app);
    ~UnixSignalHandler();

    UnixSignalHandler(const UnixSignalHandler&) = delete;
    UnixSignalHandler& operator=(const UnixSignalHandler&) = delete;

    bool isInstalled() const;

private:
    std::unique_ptr<QSocketNotifier> notifier_;
    bool installed_ = false;
};

/**
 * @brief The AppRuntime class manages the native daemon lifecycle.
 *
 * It instantiates all key controllers (camera, ONNX engine, GPIO, socket server)
 * and orchestrates their events, power policy, thermal policy, and periodic timers.
 */
class AppRuntime : public QObject {
    Q_OBJECT
public:
    /**
     * @brief Constructs the application runtime.
     * @param configPath Path to the config JSON file.
     * @param runtimeMode Mode string: "auto", "mock", or "hardware".
     * @param parent Optional Qt parent QObject.
     */
    AppRuntime(const QString& configPath, const QString& runtimeMode, QObject* parent = nullptr);

    /**
     * @brief Cleans up runtime resources, stopping timers and active hardware handles.
     */
    ~AppRuntime() override;

    /**
     * @brief Starts all system components and threads.
     * @return true if starting all servers and devices succeeded, false otherwise.
     */
    bool start();

private:
    void setupConnections();
    void updateCameraPowerMode();
    void applyThermalPolicy();
    void triggerNextInference();
    void publishSnapshot();
    void publishInitialSnapshot();
    bool effectiveRealTime() const;
    bool isCountingInputPresent() const;

    QString configPath_;
    QString runtimeMode_;
    AppConfig config_;
    CapabilitySnapshot capabilities_;
    ServiceState state_;
    RuntimeIntervals intervals_;

    std::unique_ptr<ControlServer> control_;
    std::unique_ptr<GpioController> gpio_;
    std::unique_ptr<CountingTracker> counting_;
    std::unique_ptr<GStreamerCamera> camera_;
    std::unique_ptr<OnnxYoloEngine> engine_;
    QThread workerThread_;

    bool countTestActive_ = false;
    QElapsedTimer countTestTimer_;
    bool cameraLowPowerMode_ = false;
    double effectiveAiMaxFps_ = 1.0;
    ThermalPolicy thermalPolicy_;

    bool workerBusy_ = false;
    int inferenceFrames_ = 0;
    QElapsedTimer inferenceWindow_;
    QTimer inferenceTimer_;
    QElapsedTimer lastInferenceAt_;

    QTimer gpioTimer_;
    QTimer sysMetricsTimer_;
    QTimer statusTimer_;
};

bool cameraChanged(const CameraConfig& a, const CameraConfig& b);
bool modelChanged(const ModelConfig& a, const ModelConfig& b);
bool gpioChanged(const GpioConfig& a, const GpioConfig& b);
bool countingChanged(const CountingConfig& a, const CountingConfig& b);
QStringList selectedPartKeywords(const CountingConfig& counting);
bool validationHasErrors(const QJsonObject& validation);
bool hardwareTraySensorActive(const QString& triggerMode, const QString& gpioStatus);
bool effectiveRealTimeMode(const QString& triggerMode, const QString& gpioStatus);
bool countInputPresent(const QString& triggerMode, const QString& gpioStatus, bool trayPresent);
bool shouldUseCameraLowPower(bool safeMode, bool previewPaused, bool realTimeMode,
                             bool trayPresent, bool countTestActive, bool forceLowPower);

ThermalPolicy thermalPolicyFor(double temperatureC, double configuredAiMaxFps);
QJsonObject diagnosticEvent(const QString& target, bool ok, const QString& message,
                            const QString& detail = {}, const QJsonObject& metrics = {});
QJsonObject configSaveResult(bool ok, const QString& message, const QString& detail = {});
bool requestSystemPoweroff(const QString& configOverride, QString* detail);
inline bool requestSystemPoweroff(QString* detail) { return requestSystemPoweroff({}, detail); }

}  // namespace beenut
