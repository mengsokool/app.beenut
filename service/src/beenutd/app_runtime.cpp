#include "app_runtime.h"
#include "control_server.h"
#include "counting_tracker.h"
#include "gpio_controller.h"
#include "gstreamer_camera.h"
#include "onnx_yolo_engine.h"
#include "service_state.h"
#include "hardware_discovery.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QJsonArray>
#include <QObject>
#include <QPair>
#include <QProcess>
#include <QSocketNotifier>
#include <QVector>
#include <QElapsedTimer>
#include <QTimer>
#include <QThread>

#include <csignal>
#include <gst/gst.h>

#ifdef Q_OS_UNIX
#include <fcntl.h>
#include <unistd.h>
#endif

namespace beenut {
namespace {

#ifdef Q_OS_UNIX
int signalFds[2] = {-1, -1};

void handleUnixSignal(int)
{
    const char byte = 1;
    if (signalFds[1] >= 0) {
        ::write(signalFds[1], &byte, sizeof(byte));
    }
}

void closeSignalFds()
{
    if (signalFds[0] >= 0) {
        ::close(signalFds[0]);
        signalFds[0] = -1;
    }
    if (signalFds[1] >= 0) {
        ::close(signalFds[1]);
        signalFds[1] = -1;
    }
}
#endif

bool runCommand(const QString& program, const QStringList& arguments, QString* detail)
{
    QProcess process;
    process.start(program, arguments);
    if (!process.waitForStarted(1000)) {
        if (detail != nullptr) {
            *detail = QString("%1: %2").arg(program, process.errorString());
        }
        return false;
    }
    if (!process.waitForFinished(3000)) {
        process.kill();
        process.waitForFinished(500);
        if (detail != nullptr) {
            *detail = QString("%1 timed out").arg(program);
        }
        return false;
    }
    const auto stderrText = QString::fromUtf8(process.readAllStandardError()).trimmed();
    if (process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0) {
        return true;
    }
    if (detail != nullptr) {
        *detail = QString("%1 exited with %2%3")
                      .arg(program)
                      .arg(process.exitCode())
                      .arg(stderrText.isEmpty() ? QString() : QString(": %1").arg(stderrText));
    }
    return false;
}

}  // namespace

RuntimeIntervals defaultRuntimeIntervals()
{
    return {};
}

UnixSignalHandler::UnixSignalHandler(QCoreApplication& app)
{
#ifdef Q_OS_UNIX
    if (::pipe(signalFds) != 0) {
        return;
    }
    for (int fd : signalFds) {
        const int flags = ::fcntl(fd, F_GETFL, 0);
        if (flags >= 0) {
            ::fcntl(fd, F_SETFL, flags | O_NONBLOCK);
        }
    }
    std::signal(SIGTERM, handleUnixSignal);
    std::signal(SIGINT, handleUnixSignal);
    notifier_ = std::make_unique<QSocketNotifier>(signalFds[0], QSocketNotifier::Read);
    QObject::connect(notifier_.get(), &QSocketNotifier::activated, &app, []() {
        char buffer[32];
        while (::read(signalFds[0], buffer, sizeof(buffer)) > 0) {
        }
        QCoreApplication::quit();
    });
    installed_ = true;
#else
    Q_UNUSED(app);
#endif
}

UnixSignalHandler::~UnixSignalHandler()
{
#ifdef Q_OS_UNIX
    notifier_.reset();
    std::signal(SIGTERM, SIG_DFL);
    std::signal(SIGINT, SIG_DFL);
    closeSignalFds();
#endif
}

bool UnixSignalHandler::isInstalled() const
{
    return installed_;
}

bool cameraChanged(const CameraConfig& a, const CameraConfig& b)
{
    return a.source != b.source || a.device != b.device || a.width != b.width || a.height != b.height ||
           a.fps != b.fps || a.idleFps != b.idleFps || a.warmupFrames != b.warmupFrames ||
           a.previewTransport != b.previewTransport ||
           a.exposureMode != b.exposureMode || a.flipHorizontal != b.flipHorizontal ||
           a.flipVertical != b.flipVertical;
}

bool modelChanged(const ModelConfig& a, const ModelConfig& b)
{
    return a.engine != b.engine || a.modelPath != b.modelPath || a.labelsMode != b.labelsMode ||
           a.labelsPath != b.labelsPath || a.confidenceThreshold != b.confidenceThreshold ||
           a.nmsThreshold != b.nmsThreshold || a.maxFps != b.maxFps;
}

bool gpioChanged(const GpioConfig& a, const GpioConfig& b)
{
    return a.backend != b.backend || a.chip != b.chip ||
           a.traySensorPin != b.traySensorPin || a.relayPin != b.relayPin ||
           a.activeLow != b.activeLow || a.debounceMs != b.debounceMs;
}

bool countingChanged(const CountingConfig& a, const CountingConfig& b)
{
    if (a.stableFrames != b.stableFrames || a.timeoutMs != b.timeoutMs || a.selectedPartType != b.selectedPartType ||
        a.triggerMode != b.triggerMode || a.partTypes.size() != b.partTypes.size()) {
        return true;
    }
    for (qsizetype i = 0; i < a.partTypes.size(); ++i) {
        const auto& left = a.partTypes.at(i);
        const auto& right = b.partTypes.at(i);
        if (left.id != right.id || left.name != right.name || left.image != right.image ||
            left.keywords != right.keywords || left.enabled != right.enabled) {
            return true;
        }
    }
    return false;
}

QStringList selectedPartKeywords(const CountingConfig& counting)
{
    for (const auto& part : counting.partTypes) {
        if (part.id == counting.selectedPartType) {
            return part.keywords;
        }
    }
    return {};
}

bool validationHasErrors(const QJsonObject& validation)
{
    return !validation.value("errors").toArray().isEmpty();
}

bool hardwareTraySensorActive(const QString& triggerMode, const QString& gpioStatus)
{
    return triggerMode == "tray_sensor" && gpioStatus == "ready";
}

bool effectiveRealTimeMode(const QString& triggerMode, const QString& gpioStatus)
{
    return triggerMode == "real_time" ||
           (triggerMode == "tray_sensor" && !hardwareTraySensorActive(triggerMode, gpioStatus));
}

bool countInputPresent(const QString& triggerMode, const QString& gpioStatus, bool trayPresent)
{
    return effectiveRealTimeMode(triggerMode, gpioStatus) || trayPresent;
}

bool shouldUseCameraLowPower(bool safeMode, bool previewPaused, bool realTimeMode,
                             bool trayPresent, bool countTestActive, bool forceLowPower)
{
    const bool activelyCounting = !safeMode && !previewPaused &&
                                  (realTimeMode || trayPresent || countTestActive);
    return !activelyCounting || forceLowPower;
}

ThermalPolicy thermalPolicyFor(double temperatureC, double configuredAiMaxFps)
{
    ThermalPolicy policy;
    if (temperatureC <= 0.0) {
        policy.detail = "temperature sensor unavailable";
        return policy;
    }
    if (temperatureC >= 85.0) {
        policy.state = "critical";
        policy.forceLowPower = true;
        policy.aiMaxFpsScale = 0.25;
    } else if (temperatureC >= 80.0) {
        policy.state = "throttled";
        policy.aiMaxFpsScale = 0.5;
    } else if (temperatureC >= 74.0) {
        policy.state = "hot";
        policy.aiMaxFpsScale = 0.75;
    } else if (temperatureC >= 68.0) {
        policy.state = "warning";
        policy.aiMaxFpsScale = 0.9;
    } else {
        policy.state = "normal";
    }
    const double effectiveFps = qMax(1.0, configuredAiMaxFps * policy.aiMaxFpsScale);
    policy.detail = QString("%1 C · AI max %2 fps")
                        .arg(temperatureC, 0, 'f', 1)
                        .arg(effectiveFps, 0, 'f', 1);
    return policy;
}

QJsonObject diagnosticEvent(const QString& target, bool ok, const QString& message,
                            const QString& detail, const QJsonObject& metrics)
{
    return {
        {"target", target},
        {"ok", ok},
        {"message", message},
        {"detail", detail},
        {"metrics", metrics},
        {"timestampMs", QDateTime::currentMSecsSinceEpoch()},
    };
}

QJsonObject configSaveResult(bool ok, const QString& message, const QString& detail)
{
    return {
        {"ok", ok},
        {"message", message},
        {"detail", detail},
        {"timestampMs", QDateTime::currentMSecsSinceEpoch()},
    };
}

bool requestSystemPoweroff(const QString& configOverride, QString* detail)
{
    // Config-level override takes precedence over env var (useful for dry-run testing
    // where env var inheritance through background processes is unreliable).
    const QString overrideCommand = !configOverride.trimmed().isEmpty()
        ? configOverride.trimmed()
        : qEnvironmentVariable("BEENUT_POWEROFF_COMMAND").trimmed();
    if (!overrideCommand.isEmpty()) {
        const QStringList parts = QProcess::splitCommand(overrideCommand);
        if (parts.isEmpty()) {
            if (detail != nullptr) {
                *detail = "BEENUT_POWEROFF_COMMAND is empty after parsing";
            }
            return false;
        }
        const QString program = parts.first();
        const QStringList arguments = parts.mid(1);
        QString commandDetail;
        if (runCommand(program, arguments, &commandDetail)) {
            if (detail != nullptr) {
                *detail = QString("override: %1").arg(overrideCommand);
            }
            return true;
        }
        if (detail != nullptr) {
            *detail = QString("override failed: %1").arg(commandDetail);
        }
        return false;
    }

#ifdef Q_OS_LINUX
    const QVector<QPair<QString, QStringList>> commands{
        {"/usr/bin/sudo", {"-n", "/usr/bin/systemctl", "poweroff"}},
        {"/usr/bin/sudo", {"-n", "/bin/systemctl", "poweroff"}},
        {"/usr/bin/sudo", {"-n", "/usr/sbin/poweroff"}},
        {"/usr/bin/sudo", {"-n", "/sbin/poweroff"}},
        {"/usr/bin/systemctl", {"poweroff"}},
        {"/bin/systemctl", {"poweroff"}},
    };
#else
    const QVector<QPair<QString, QStringList>> commands{
        {"/usr/bin/sudo", {"-n", "/sbin/shutdown", "-h", "now"}},
    };
#endif
    QStringList failures;
    for (const auto& command : commands) {
        QString commandDetail;
        if (runCommand(command.first, command.second, &commandDetail)) {
            if (detail != nullptr) {
                *detail = QString("%1 %2").arg(command.first, command.second.join(' '));
            }
            return true;
        }
        failures.append(commandDetail);
    }
    if (detail != nullptr) {
        *detail = failures.join(" | ");
    }
    return false;
}

AppRuntime::AppRuntime(const QString& configPath, const QString& runtimeMode, QObject* parent)
    : QObject(parent)
    , configPath_(configPath)
    , runtimeMode_(runtimeMode)
    , config_(loadConfig(configPath))
    , intervals_(defaultRuntimeIntervals())
{
    if (runtimeMode_ == "mock") {
        config_.camera.source = "mock";
        config_.camera.device.clear();
        config_.model.engine = "mock";
        qputenv("BEENUT_GPIO_BACKEND", "mock");
    }
    capabilities_ = discoverCapabilities(config_);
    state_.safeMode = config_.safeMode;
    state_.selectedPartType = config_.counting.selectedPartType;

    control_ = std::make_unique<ControlServer>(config_.controlSocket);
    gpio_ = std::make_unique<GpioController>(config_.gpio, config_.safeMode);
    counting_ = std::make_unique<CountingTracker>(config_.counting);
    camera_ = std::make_unique<GStreamerCamera>(config_.camera, config_.previewSocket, config_.model.inputSize, config_.model.maxFps);
    engine_ = std::make_unique<OnnxYoloEngine>(config_.model);

    effectiveAiMaxFps_ = qMax(1.0, config_.model.maxFps);
    state_.effectiveAiMaxFps = effectiveAiMaxFps_;
}

AppRuntime::~AppRuntime()
{
    inferenceTimer_.stop();
    gpioTimer_.stop();
    sysMetricsTimer_.stop();
    statusTimer_.stop();

    if (camera_) {
        camera_->stop();
    }
    if (gpio_) {
        gpio_->stop();
    }
    if (control_) {
        control_->stop();
    }

    workerThread_.quit();
    workerThread_.wait();
}

bool AppRuntime::start()
{
    gpio_->start();
    state_.gpio = gpio_->status();
    state_.gpioDetail = gpio_->detail();

    setupConnections();

    if (!control_->start()) {
        qWarning("Unable to start control socket");
        return false;
    }

    state_.camera = camera_->start() ? "ready" : "error";
    state_.cameraDetail = camera_->detail();
    state_.previewTransport = camera_->previewTransport();
    state_.previewUrl = camera_->previewUrl();
    state_.previewCaps = camera_->previewCaps();

    updateCameraPowerMode();
    applyThermalPolicy();

    state_.model = engine_->isReady() ? "ready" : "error";
    state_.modelDetail = engine_->detail();
    state_.modelLabels = engine_->labels();

    engine_->moveToThread(&workerThread_);
    workerThread_.start();

    inferenceWindow_.start();
    lastInferenceAt_.start();

    inferenceTimer_.setSingleShot(true);
    inferenceTimer_.start(0);

    gpioTimer_.setInterval(intervals_.gpioPollMs);
    gpioTimer_.start();

    sysMetricsTimer_.setInterval(intervals_.systemMetricsMs);
    sysMetricsTimer_.start();

    statusTimer_.setInterval(intervals_.statusBroadcastMs);
    statusTimer_.start();

    return true;
}

void AppRuntime::setupConnections()
{
    QObject::connect(control_.get(), &ControlServer::partTypeRequested, this, [&](const QString& partType) {
        for (const auto& item : config_.counting.partTypes) {
            if (item.enabled && item.id == partType) {
                config_.counting.selectedPartType = partType;
                state_.selectedPartType = partType;
                counting_->reset();
                state_.count = 0;
                state_.detections.clear();
                break;
            }
        }
    });

    QObject::connect(control_.get(), &ControlServer::trayOverrideRequested, this, [&](bool present) {
        gpio_->setTrayOverride(present);
        state_.trayPresent = gpio_->trayPresent();
        if (!present) {
            state_.count = 0;
            state_.detections.clear();
            counting_->reset();
            countTestActive_ = false;
            state_.countTestRunning = false;
        }
    });

    QObject::connect(control_.get(), &ControlServer::lightRequested, this, [&](bool enabled) {
        gpio_->setLight(enabled);
        state_.lightOn = gpio_->lightOn();
    });

    QObject::connect(engine_.get(), &OnnxYoloEngine::statusChanged, this, [&](bool ready, const QString& detail, const QStringList& labels) {
        state_.model = ready ? "ready" : "error";
        state_.modelDetail = detail;
        state_.modelLabels = labels;
    });

    QObject::connect(control_.get(), &ControlServer::configSaveRequested, this, [&](const QJsonObject& payload) {
        auto nextConfig = parseConfig(payload, config_);
        nextConfig.controlSocket = config_.controlSocket;
        nextConfig.previewSocket = config_.previewSocket;
        const auto validation = validateConfig(nextConfig, capabilities_);
        control_->broadcastConfigValidation(validation);
        if (validationHasErrors(validation)) {
            qWarning("Rejected config save because validation failed");
            control_->broadcastConfigSaveResult(configSaveResult(false, "Config rejected by backend validation"));
            return;
        }
        const auto needsCameraReload = cameraChanged(config_.camera, nextConfig.camera);
        const auto needsModelReload = modelChanged(config_.model, nextConfig.model);
        const auto needsGpioReload = gpioChanged(config_.gpio, nextConfig.gpio);
        const auto needsCountingReload = countingChanged(config_.counting, nextConfig.counting);

        QString error;
        if (!saveConfig(nextConfig, configPath_, &error)) {
            qWarning("Unable to save config: %s", qPrintable(error));
            control_->broadcastConfigSaveResult(configSaveResult(false, "Unable to save config", error));
            return;
        }

        config_ = nextConfig;
        state_.safeMode = config_.safeMode;
        state_.selectedPartType = config_.counting.selectedPartType;
        if (needsCountingReload) {
            counting_->reload(config_.counting);
            state_.count = 0;
            state_.detections.clear();
            countTestActive_ = false;
            state_.countTestRunning = false;
        }
        if (needsCameraReload) {
            cameraLowPowerMode_ = false;
            state_.camera = camera_->reload(config_.camera) ? "ready" : "error";
            state_.cameraDetail = camera_->detail();
            state_.previewCaps = camera_->previewCaps();
            state_.captureFps = 0.0;
            state_.count = 0;
            state_.detections.clear();
            counting_->reset();
            countTestActive_ = false;
            state_.countTestRunning = false;
        }
        if (needsModelReload) {
            state_.model = "loading";
            state_.modelDetail = "Reloading model on worker thread...";
            state_.inferenceFps = 0.0;
            state_.processingMs = 0;
            state_.count = 0;
            state_.detections.clear();
            counting_->reset();
            countTestActive_ = false;
            state_.countTestRunning = false;
            inferenceFrames_ = 0;
            inferenceWindow_.restart();

            QMetaObject::invokeMethod(engine_.get(), "reloadEngine",
                                      Q_ARG(beenut::ModelConfig, config_.model));
        }
        applyThermalPolicy();
        if (needsGpioReload) {
            gpio_->reload(config_.gpio, config_.safeMode);
        } else {
            gpio_->setSafeMode(config_.safeMode);
        }
        state_.gpio = gpio_->status();
        state_.gpioDetail = gpio_->detail();
        state_.lightOn = gpio_->lightOn();
        capabilities_ = discoverCapabilities(config_);
        updateCameraPowerMode();
        control_->broadcastCapabilities(capabilities_);
        control_->broadcastConfigSaveResult(configSaveResult(true, "Config saved and applied"));

        if (!inferenceTimer_.isActive()) {
            inferenceTimer_.start(0);
        }
    });

    QObject::connect(control_.get(), &ControlServer::configValidationRequested, this, [&](const QJsonObject& payload) {
        auto candidate = parseConfig(payload, config_);
        candidate.controlSocket = config_.controlSocket;
        candidate.previewSocket = config_.previewSocket;
        control_->broadcastConfigValidation(validateConfig(candidate, capabilities_));
    });

    QObject::connect(control_.get(), &ControlServer::capabilitiesRequested, this, [&]() {
        control_->broadcastCapabilities(capabilities_);
    });

    QObject::connect(control_.get(), &ControlServer::capabilitiesRefreshRequested, this, [&]() {
        capabilities_ = discoverCapabilities(config_);
        control_->broadcastCapabilities(capabilities_);
    });

    QObject::connect(control_.get(), &ControlServer::previewPauseRequested, this, [&](bool paused) {
        state_.previewPaused = paused;
        if (paused) {
            countTestActive_ = false;
            state_.countTestRunning = false;
            state_.countTestSuccess = false;
            state_.countTestMessage.clear();
            state_.processingMs = 0;
            state_.inferenceFps = 0.0;
            state_.detections.clear();
            counting_->reset();
        }
        updateCameraPowerMode();
        publishSnapshot();
    });

    QObject::connect(control_.get(), &ControlServer::shutdownRequested, this, [&]() {
        QString detail;
        const bool ok = requestSystemPoweroff(config_.poweroffCommand, &detail);
        control_->broadcastDiagnosticEvent(diagnosticEvent(
            "shutdown",
            ok,
            ok ? "System poweroff requested" : "Unable to request system poweroff",
            detail));
        if (!ok) {
            qWarning("Unable to request system poweroff: %s", qPrintable(detail));
        }
    });

    QObject::connect(control_.get(), &ControlServer::clientConnected, this, [&]() {
        publishInitialSnapshot();
    });

    QObject::connect(control_.get(), &ControlServer::diagnosticRequested, this, [&](const QString& target) {
        if (target == "camera") {
            control_->broadcastDiagnosticEvent(diagnosticEvent(
                target,
                camera_->isReady(),
                camera_->isReady() ? "Camera pipeline is running" : "Camera pipeline is not ready",
                camera_->detail(),
                QJsonObject{
                    {"captureFps", camera_->captureFps()},
                    {"previewCaps", camera_->previewCaps()},
                }));
            return;
        }
        if (target == "model") {
            const bool modelReady = state_.model == "ready";
            control_->broadcastDiagnosticEvent(diagnosticEvent(
                target,
                modelReady,
                modelReady ? "Inference runtime is ready" : "Inference runtime is not ready",
                state_.modelDetail,
                QJsonObject{
                    {"labels", state_.modelLabels.size()},
                    {"engine", config_.model.engine},
                    {"lastProcessingMs", state_.processingMs},
                    {"inferenceFps", state_.inferenceFps},
                }));
            return;
        }
        if (target == "gpio") {
            control_->broadcastDiagnosticEvent(diagnosticEvent(
                target,
                gpio_->status() == "ready" || gpio_->status() == "mock",
                QString("GPIO backend is %1").arg(gpio_->status()),
                gpio_->detail(),
                QJsonObject{
                    {"trayPresent", gpio_->trayPresent()},
                    {"lightOn", gpio_->lightOn()},
                    {"backend", gpio_->status()},
                }));
            return;
        }
        control_->broadcastDiagnosticEvent(diagnosticEvent(target, false, "Unknown diagnostic target"));
    });

    QObject::connect(control_.get(), &ControlServer::countOnceRequested, this, [&]() {
        state_.countTestSuccess = false;
        if (state_.safeMode) {
            state_.countTestRunning = false;
            state_.countTestMessage = "ระบบอยู่ใน safe mode";
            return;
        }
        if (!state_.trayPresent) {
            state_.countTestRunning = false;
            state_.countTestMessage = "ยังไม่พบถาดวางชิ้นส่วน";
            return;
        }
        counting_->reset();
        state_.count = 0;
        state_.detections.clear();
        state_.countTestRunning = true;
        state_.countTestMessage = "กำลังนับ...";
        countTestActive_ = true;
        countTestTimer_.restart();
    });

    QObject::connect(engine_.get(), &OnnxYoloEngine::inferenceFinished, this, [&](const InferenceResult& result) {
        workerBusy_ = false;

        if (state_.safeMode || state_.previewPaused || !isCountingInputPresent()) {
            return;
        }

        ++inferenceFrames_;
        const auto counted = counting_->update(isCountingInputPresent(), result);
        state_.count = counted.count;
        state_.processingMs = result.processingMs;
        state_.detections = counted.detections;

        if (countTestActive_ && counted.locked) {
            countTestActive_ = false;
            state_.countTestRunning = false;
            state_.countTestSuccess = true;
            state_.countTestMessage = QString("นับทดสอบสำเร็จ: %1 ชิ้น").arg(state_.count);
        } else if (countTestActive_ && countTestTimer_.isValid() && countTestTimer_.elapsed() > config_.counting.timeoutMs) {
            countTestActive_ = false;
            state_.countTestRunning = false;
            state_.countTestSuccess = false;
            state_.countTestMessage = "ยังไม่มีผลตรวจจากกล้อง";
        }

        if (inferenceWindow_.elapsed() >= intervals_.inferenceFpsWindowMs) {
            state_.inferenceFps = inferenceFrames_ * static_cast<double>(intervals_.inferenceFpsWindowMs) /
                                 static_cast<double>(inferenceWindow_.elapsed());
            inferenceFrames_ = 0;
            inferenceWindow_.restart();
        }

        if (!inferenceTimer_.isActive()) {
            inferenceTimer_.start(0);
        }
    });

    QObject::connect(&inferenceTimer_, &QTimer::timeout, this, &AppRuntime::triggerNextInference);

    QObject::connect(&gpioTimer_, &QTimer::timeout, this, [&]() {
        const auto wasPresent = state_.trayPresent;
        state_.trayPresent = gpio_->trayPresent();
        state_.lightOn = gpio_->lightOn();
        state_.gpio = gpio_->status();
        state_.gpioDetail = gpio_->detail();
        updateCameraPowerMode();
        if (!effectiveRealTime() && wasPresent && !state_.trayPresent) {
            state_.count = 0;
            state_.detections.clear();
            counting_->reset();
        }
    });

    QObject::connect(&sysMetricsTimer_, &QTimer::timeout, this, [&]() {
        const auto metrics = readSystemMetrics(QCoreApplication::applicationPid(), control_->clientPid());
        state_.cpuUsage = metrics.cpuUsage;
        state_.ramUsage = metrics.ramUsage;
        state_.temperature = metrics.temperature;
        state_.daemonCpu = metrics.daemonCpu;
        state_.daemonRam = metrics.daemonRam;
        state_.flutterCpu = metrics.flutterCpu;
        state_.flutterRam = metrics.flutterRam;
        applyThermalPolicy();
    });

    QObject::connect(&statusTimer_, &QTimer::timeout, this, &AppRuntime::publishSnapshot);

    QObject::connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, this, [&]() {
        inferenceTimer_.stop();
        gpioTimer_.stop();
        sysMetricsTimer_.stop();
        statusTimer_.stop();
        if (camera_) camera_->stop();
        if (gpio_) gpio_->stop();
        if (control_) control_->stop();
    });
}

void AppRuntime::updateCameraPowerMode()
{
    if (state_.previewPaused) {
        if (camera_->isReady()) {
            camera_->stop();
        }
        cameraLowPowerMode_ = true;
        state_.camera = "paused";
        state_.captureFps = 0.0;
        return;
    }

    const bool lowPowerMode = shouldUseCameraLowPower(
        state_.safeMode,
        false,
        effectiveRealTime(),
        state_.trayPresent,
        countTestActive_,
        thermalPolicy_.forceLowPower);

    if (state_.camera == "paused") {
        cameraLowPowerMode_ = lowPowerMode;
        camera_->setLowPowerMode(lowPowerMode);
        state_.camera = camera_->start() ? "ready" : "error";
    } else {
        if (cameraLowPowerMode_ != lowPowerMode) {
            cameraLowPowerMode_ = lowPowerMode;
            state_.camera = camera_->setLowPowerMode(lowPowerMode) ? "ready" : "error";
        }
    }

    state_.cameraDetail = camera_->detail();
    state_.previewTransport = camera_->previewTransport();
    state_.previewUrl = camera_->previewUrl();
    state_.previewCaps = camera_->previewCaps();
}

void AppRuntime::applyThermalPolicy()
{
    thermalPolicy_ = thermalPolicyFor(state_.temperature, config_.model.maxFps);
    const double nextEffectiveAiMaxFps = qMax(1.0, config_.model.maxFps * thermalPolicy_.aiMaxFpsScale);
    state_.thermalState = thermalPolicy_.state;
    state_.thermalDetail = thermalPolicy_.detail;
    state_.effectiveAiMaxFps = nextEffectiveAiMaxFps;
    if (!qFuzzyCompare(effectiveAiMaxFps_, nextEffectiveAiMaxFps)) {
        effectiveAiMaxFps_ = nextEffectiveAiMaxFps;
        state_.camera = camera_->setAiMaxFps(effectiveAiMaxFps_) ? "ready" : "error";
        state_.cameraDetail = camera_->detail();
        state_.previewCaps = camera_->previewCaps();
        state_.captureFps = 0.0;
    }
    updateCameraPowerMode();
}

void AppRuntime::triggerNextInference()
{
    if (state_.safeMode || state_.previewPaused || !isCountingInputPresent()) {
        counting_->reset();
        state_.count = 0;
        state_.detections.clear();
        state_.processingMs = 0;
        state_.inferenceFps = 0.0;
        if (countTestActive_) {
            countTestActive_ = false;
            state_.countTestRunning = false;
            state_.countTestSuccess = false;
            state_.countTestMessage = state_.safeMode ? "ระบบอยู่ใน safe mode"
                                                    : (state_.previewPaused ? "ระบบพักเครื่อง" : "ยังไม่พบถาดวางชิ้นส่วน");
        }
        inferenceFrames_ = 0;
        inferenceWindow_.restart();
        inferenceTimer_.start(intervals_.idleInferenceRetryMs);
        return;
    }

    if (workerBusy_) {
        return;
    }

    const int minFrameMs = qMax(1, static_cast<int>(intervals_.inferenceFpsWindowMs / effectiveAiMaxFps_));
    const qint64 elapsedMs = lastInferenceAt_.elapsed();
    if (elapsedMs < minFrameMs) {
        inferenceTimer_.start(static_cast<int>(minFrameMs - elapsedMs));
        return;
    }

    auto* sample = camera_->pullAiSample();
    if (sample == nullptr) {
        inferenceTimer_.start(intervals_.missingAiSampleRetryMs);
        return;
    }

    workerBusy_ = true;
    lastInferenceAt_.restart();
    gst_sample_ref(sample);
    QMetaObject::invokeMethod(engine_.get(), "runInference",
                              Q_ARG(void*, sample),
                              Q_ARG(QString, state_.selectedPartType),
                              Q_ARG(QStringList, selectedPartKeywords(config_.counting)));
    gst_sample_unref(sample);
}

void AppRuntime::publishSnapshot()
{
    if (camera_ && !camera_->isReady() && !config_.safeMode && !state_.previewPaused) {
        qInfo("Camera is not running. Attempting auto-retry start...");
        camera_->start();
        updateCameraPowerMode();
    }
    state_.captureFps = camera_->captureFps();
    if (state_.previewPaused) {
        state_.camera = "paused";
    } else {
        state_.camera = camera_->isReady() ? "ready" : "error";
    }
    state_.gpio = gpio_->status();
    state_.cameraDetail = camera_->detail();
    state_.gpioDetail = gpio_->detail();
    state_.previewTransport = camera_->previewTransport();
    state_.previewUrl = camera_->previewUrl();
    state_.previewCaps = camera_->previewCaps();
    control_->broadcast(config_, state_);
}

void AppRuntime::publishInitialSnapshot()
{
    publishSnapshot();
    control_->broadcastCapabilities(capabilities_);
    control_->broadcastConfigValidation(validateConfig(config_, capabilities_));
}

bool AppRuntime::effectiveRealTime() const
{
    return effectiveRealTimeMode(config_.counting.triggerMode, gpio_->status());
}

bool AppRuntime::isCountingInputPresent() const
{
    return countInputPresent(config_.counting.triggerMode, gpio_->status(), state_.trayPresent);
}

}  // namespace beenut
