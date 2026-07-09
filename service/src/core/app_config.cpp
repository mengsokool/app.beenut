#include "app_config.h"
#include "config_migrations.h"
#include "hardware_discovery.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>
#include <algorithm>

namespace beenut {
namespace {

QString str(const QJsonObject& o, const char* key, const QString& fallback = {})
{
    const auto v = o.value(QString::fromUtf8(key));
    return v.isString() ? v.toString() : fallback;
}

int integer(const QJsonObject& o, const char* key, int fallback)
{
    const auto v = o.value(QString::fromUtf8(key));
    return v.isDouble() ? v.toInt() : fallback;
}

double number(const QJsonObject& o, const char* key, double fallback)
{
    const auto v = o.value(QString::fromUtf8(key));
    return v.isDouble() ? v.toDouble() : fallback;
}

bool boolean(const QJsonObject& o, const char* key, bool fallback)
{
    const auto v = o.value(QString::fromUtf8(key));
    return v.isBool() ? v.toBool() : fallback;
}

QVector<PartType> defaultPartTypes()
{
    return {};
}

}  // namespace

AppConfig loadConfig(const QString& path)
{
    AppConfig config;
    config.counting.partTypes = defaultPartTypes();

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return config;
    }
    return parseConfig(QJsonDocument::fromJson(file.readAll()).object(), config);
}

AppConfig parseConfig(const QJsonObject& root, AppConfig config)
{
    const auto migration = migrateConfig(root);
    const auto migratedRoot = migration.config;
    if (config.counting.partTypes.empty()) {
        config.counting.partTypes = defaultPartTypes();
    }
    config.schemaVersion = integer(migratedRoot, "schema_version", currentConfigSchemaVersion());
    config.controlSocket = str(migratedRoot, "controlSocket", config.controlSocket);
    config.previewSocket = str(migratedRoot, "previewSocket", config.previewSocket);
    config.poweroffCommand = str(migratedRoot, "poweroffCommand", config.poweroffCommand);

    const auto gpio = migratedRoot.value("gpio").toObject();
    config.gpio.backend = str(gpio, "backend", config.gpio.backend);
    if (config.gpio.backend != "auto" && config.gpio.backend != "mock" &&
        config.gpio.backend != "libgpiod" && config.gpio.backend != "sysfs") {
        config.gpio.backend = "auto";
    }
    config.gpio.chip = str(gpio, "chip", config.gpio.chip);
    if (config.gpio.chip.isEmpty()) {
        config.gpio.chip = "gpiochip0";
    }
    config.gpio.traySensorPin = integer(gpio, "tray_sensor_pin", config.gpio.traySensorPin);
    config.gpio.relayPin = integer(gpio, "relay_pin", config.gpio.relayPin);
    config.gpio.activeLow = boolean(gpio, "active_low", config.gpio.activeLow);
    config.gpio.debounceMs = integer(gpio, "debounce_ms", config.gpio.debounceMs);

    const auto camera = migratedRoot.value("camera").toObject();
    config.camera.source = str(camera, "source", config.camera.source);
    config.camera.device = str(camera, "device", config.camera.device);
    if (config.camera.source == "avfoundation") {
        config.camera.device = migrateAVFoundationDeviceIndexToUniqueId(config.camera.device);
    }
    config.camera.previewTransport = str(camera, "preview_transport", config.camera.previewTransport);
    if (config.camera.previewTransport != "dmabuf_egl" && config.camera.previewTransport != "iosurface_nv12" &&
        config.camera.previewTransport != "shm_nv12") {
        config.camera.previewTransport = "auto";
    }
    config.camera.width = integer(camera, "width", config.camera.width);
    config.camera.height = integer(camera, "height", config.camera.height);
    config.camera.fps = integer(camera, "fps", config.camera.fps);
    config.camera.idleFps = integer(camera, "idle_fps", config.camera.idleFps);
    config.camera.warmupFrames = integer(camera, "warmup_frames", config.camera.warmupFrames);
    config.camera.exposureMode = str(camera, "exposure_mode", config.camera.exposureMode);
    config.camera.flipHorizontal = boolean(camera, "flip_horizontal", config.camera.flipHorizontal);
    config.camera.flipVertical = boolean(camera, "flip_vertical", config.camera.flipVertical);

    const auto model = migratedRoot.value("model").toObject();
    config.model.engine = str(model, "engine", config.model.engine);
    config.model.modelPath = str(model, "model_path", config.model.modelPath);
    config.model.labelsMode = str(model, "labels_mode", config.model.labelsMode);
    if (config.model.labelsMode != "custom") {
        config.model.labelsMode = "auto";
    }
    config.model.labelsPath = str(model, "labels_path", config.model.labelsPath);
    config.model.inputSize = integer(model, "input_size", config.model.inputSize);
    config.model.confidenceThreshold = number(model, "confidence_threshold", config.model.confidenceThreshold);
    config.model.nmsThreshold = number(model, "nms_threshold", config.model.nmsThreshold);
    config.model.maxFps = number(model, "max_fps", config.model.maxFps);

    const auto counting = migratedRoot.value("counting").toObject();
    config.counting.stableFrames = integer(counting, "stable_frames", config.counting.stableFrames);
    config.counting.timeoutMs = integer(counting, "timeout_ms", config.counting.timeoutMs);
    config.counting.selectedPartType = str(counting, "selected_part_type", config.counting.selectedPartType);
    config.counting.triggerMode = str(counting, "trigger_mode", config.counting.triggerMode);
    if (config.counting.triggerMode != "real_time" && config.counting.triggerMode != "manual_button") {
        config.counting.triggerMode = "tray_sensor";
    }
    const auto partTypesRaw = counting.value("part_types").toArray();
    if (!partTypesRaw.isEmpty()) {
        QVector<PartType> partTypes;
        for (const auto& raw : partTypesRaw) {
            const auto object = raw.toObject();
            QStringList keywords;
            for (const auto& keyword : object.value("keywords").toArray()) {
                keywords.append(keyword.toString());
            }
            partTypes.append({
                .id = str(object, "id"),
                .name = str(object, "name"),
                .image = str(object, "image"),
                .keywords = keywords,
                .enabled = boolean(object, "enabled", true),
            });
        }
        config.counting.partTypes = partTypes;
    }

    const auto ui = migratedRoot.value("ui").toObject();
    config.ui.scale = std::clamp(number(ui, "scale", config.ui.scale), 0.5, 2.0);
    config.ui.language = str(ui, "language", config.ui.language);
    config.ui.theme = str(ui, "theme", config.ui.theme);

    config.safeMode = boolean(migratedRoot, "safe_mode", config.safeMode);
    return config;
}

bool saveConfig(const AppConfig& config, const QString& path, QString* error)
{
    const QFileInfo info(path);
    if (!info.absoluteDir().exists() && !QDir().mkpath(info.absolutePath())) {
        if (error != nullptr) {
            *error = QString("Unable to create config directory: %1").arg(info.absolutePath());
        }
        return false;
    }

    if (info.exists()) {
        const auto backupPath = path + ".bak";
        QFile::remove(backupPath);
        if (!QFile::copy(path, backupPath)) {
            if (error != nullptr) {
                *error = QString("Unable to create config backup: %1").arg(backupPath);
            }
            return false;
        }
    }

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        if (error != nullptr) {
            *error = file.errorString();
        }
        return false;
    }
    file.write(QJsonDocument(toJson(config)).toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        if (error != nullptr) {
            *error = file.errorString();
        }
        return false;
    }
    return true;
}

QJsonObject toJson(const AppConfig& config)
{
    QJsonArray parts;
    for (const auto& part : config.counting.partTypes) {
        QJsonArray keywords;
        for (const auto& keyword : part.keywords) {
            keywords.append(keyword);
        }
        parts.append(QJsonObject{
            {"id", part.id},
            {"name", part.name},
            {"image", part.image},
            {"keywords", keywords},
            {"enabled", part.enabled},
        });
    }

    return {
        {"schema_version", currentConfigSchemaVersion()},
        {"controlSocket", config.controlSocket},
        {"previewSocket", config.previewSocket},
        {"poweroffCommand", config.poweroffCommand},
        {"gpio", QJsonObject{
            {"backend", config.gpio.backend},
            {"chip", config.gpio.chip},
            {"tray_sensor_pin", config.gpio.traySensorPin},
            {"relay_pin", config.gpio.relayPin},
            {"active_low", config.gpio.activeLow},
            {"debounce_ms", config.gpio.debounceMs},
        }},
        {"camera", QJsonObject{
            {"source", config.camera.source},
            {"device", config.camera.device},
            {"preview_transport", config.camera.previewTransport},
            {"width", config.camera.width},
            {"height", config.camera.height},
            {"fps", config.camera.fps},
            {"idle_fps", config.camera.idleFps},
            {"warmup_frames", config.camera.warmupFrames},
            {"exposure_mode", config.camera.exposureMode},
            {"flip_horizontal", config.camera.flipHorizontal},
            {"flip_vertical", config.camera.flipVertical},
        }},
        {"model", QJsonObject{
            {"engine", config.model.engine},
            {"model_path", config.model.modelPath},
            {"labels_mode", config.model.labelsMode},
            {"labels_path", config.model.labelsPath},
            {"input_size", config.model.inputSize},
            {"confidence_threshold", config.model.confidenceThreshold},
            {"nms_threshold", config.model.nmsThreshold},
            {"max_fps", config.model.maxFps},
        }},
        {"counting", QJsonObject{
            {"stable_frames", config.counting.stableFrames},
            {"timeout_ms", config.counting.timeoutMs},
            {"selected_part_type", config.counting.selectedPartType},
            {"trigger_mode", config.counting.triggerMode},
            {"part_types", parts},
        }},
        {"ui", QJsonObject{
            {"scale", config.ui.scale},
            {"language", config.ui.language},
            {"theme", config.ui.theme},
        }},
        {"safe_mode", config.safeMode},
    };
}

QString resolvedLabelsPath(const ModelConfig& model)
{
    if (model.labelsMode == "custom") {
        return model.labelsPath;
    }
    if (!model.labelsPath.trimmed().isEmpty()) {
        return model.labelsPath;
    }
    const QFileInfo modelFile(model.modelPath);
    if (!modelFile.absolutePath().isEmpty()) {
        return QDir(modelFile.absolutePath()).filePath("labels.txt");
    }
    return {};
}

}  // namespace beenut
