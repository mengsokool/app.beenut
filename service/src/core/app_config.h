#pragma once

#include <QJsonObject>
#include <QString>
#include <QVector>

namespace beenut {

int currentConfigSchemaVersion();

struct PartType {
    QString id;
    QString name;
    QString image;
    QStringList keywords;
    bool enabled = true;
};

struct GpioConfig {
    QString backend = "auto";
    QString chip = "gpiochip0";
    int traySensorPin = 17;
    int relayPin = 27;
    bool activeLow = false;
    int debounceMs = 80;
};

struct CameraConfig {
    QString source = "auto";
    QString device;
    QString previewTransport = "auto";
    int width = 1280;
    int height = 1280;
    int fps = 30;
    int idleFps = 5;
    int warmupFrames = 5;
    QString exposureMode = "auto";
    bool flipHorizontal = false;
    bool flipVertical = false;
};

struct ModelConfig {
    QString engine = "onnx";
    QString modelPath;
    QString labelsMode = "auto";
    QString labelsPath;
    int inputSize = 640;
    double confidenceThreshold = 0.45;
    double nmsThreshold = 0.5;
    double maxFps = 10.0;
};

struct CountingConfig {
    int stableFrames = 5;
    int timeoutMs = 2500;
    QString selectedPartType;
    QString triggerMode = "tray_sensor";
    QVector<PartType> partTypes;
};

struct UiConfig {
    double scale = 1.0;
    QString language = "en";
    QString theme = "system";
};

struct AppConfig {
    int schemaVersion = currentConfigSchemaVersion();
    QString controlSocket = "/tmp/beenutd.sock";
    QString previewSocket = "/tmp/beenut-preview.sock";
    // Optional override for the system poweroff command. When non-empty this
    // takes precedence over BEENUT_POWEROFF_COMMAND and the built-in shutdown
    // commands. Intended for development dry-run testing.
    QString poweroffCommand;
    GpioConfig gpio;
    CameraConfig camera;
    ModelConfig model;
    CountingConfig counting;
    UiConfig ui;
    bool safeMode = false;
};

AppConfig loadConfig(const QString& path);
AppConfig parseConfig(const QJsonObject& root, AppConfig base = {});
bool saveConfig(const AppConfig& config, const QString& path, QString* error = nullptr);
QJsonObject toJson(const AppConfig& config);
QString resolvedLabelsPath(const ModelConfig& model);

}  // namespace beenut
