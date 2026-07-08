#include "hardware_discovery.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QMap>
#include <QOperatingSystemVersion>
#include <QProcess>
#include <QSet>
#include <QSysInfo>
#include <QFile>
#include <QDateTime>
#include <QRegularExpression>
#include <cmath>
#include <QThread>

#ifdef Q_OS_MAC
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/mach_time.h>
#include <libproc.h>
#include <sys/proc_info.h>
#import <AVFoundation/AVFoundation.h>
#endif

#include <gst/gst.h>

namespace beenut {
namespace {

bool executableExists(const QString& name)
{
    const auto path = qEnvironmentVariable("PATH");
#if defined(Q_OS_WIN)
    const auto sep = L';';
#else
    const auto sep = ':';
#endif
    for (const auto& dir : path.split(sep, Qt::SkipEmptyParts)) {
        const QFileInfo candidate(QDir(dir).filePath(name));
        if (candidate.exists() && candidate.isExecutable()) {
            return true;
        }
    }
    return false;
}

QString commandOutput(const QString& program, const QStringList& arguments, int timeoutMs = 700)
{
    QProcess process;
    process.start(program, arguments);
    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(100);
        return {};
    }
    return QString::fromUtf8(process.readAllStandardOutput()).trimmed();
}

bool gstElementAvailable(const char* name)
{
    auto* feature = gst_element_factory_find(name);
    if (feature == nullptr) {
        return false;
    }
    gst_object_unref(feature);
    return true;
}

QString linuxBoardModel()
{
#if defined(Q_OS_LINUX)
    const QStringList paths{
        "/proc/device-tree/model",
        "/sys/firmware/devicetree/base/model",
        "/sys/class/dmi/id/product_name",
    };
    for (const auto& path : paths) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly)) {
            auto model = QString::fromUtf8(file.readAll()).trimmed();
            model.remove(QChar('\0'));
            if (!model.isEmpty()) {
                return model;
            }
        }
    }
#endif
    return {};
}

bool isRaspberryPiBoard()
{
    return linuxBoardModel().contains("Raspberry Pi", Qt::CaseInsensitive);
}

bool hardwareGpioAllowed()
{
#if defined(Q_OS_LINUX)
    if (qEnvironmentVariable("BEENUT_GPIO_ALLOW") == "1") {
        return true;
    }
    return isRaspberryPiBoard();
#else
    return false;
#endif
}

QJsonArray raspberryPiBcmPins()
{
    return QJsonArray{2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                      17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27};
}

QString platformClass()
{
#if defined(Q_OS_MACOS)
    return "macos";
#elif defined(Q_OS_WINDOWS)
    return "windows";
#elif defined(Q_OS_ANDROID)
    return "android";
#elif defined(Q_OS_IOS)
    return "ios";
#elif defined(Q_OS_LINUX)
    if (isRaspberryPiBoard()) {
        return "raspberry_pi";
    }
    if (qEnvironmentVariable("BEENUT_GPIO_ALLOW") == "1") {
        return "custom_sbc";
    }
    return "linux_pc";
#else
    return "unknown";
#endif
}

QJsonArray fallbackV4l2Formats()
{
    return QJsonArray{
        QJsonObject{{"fourcc", "NV12"}, {"width", 1920}, {"height", 1080}, {"fps", QJsonArray{30}}},
        QJsonObject{{"fourcc", "RGB"}, {"width", 640}, {"height", 640}, {"fps", QJsonArray{30}}},
    };
}

QJsonArray sortedFormats(const QMap<QString, QJsonObject>& formats)
{
    auto values = formats.values();
    std::sort(values.begin(), values.end(), [](const QJsonObject& left, const QJsonObject& right) {
        const int leftPixels = left.value("width").toInt() * left.value("height").toInt();
        const int rightPixels = right.value("width").toInt() * right.value("height").toInt();
        if (leftPixels != rightPixels) {
            return leftPixels > rightPixels;
        }
        return left.value("fourcc").toString() < right.value("fourcc").toString();
    });
    QJsonArray result;
    for (const auto& value : values) {
        result.append(value);
    }
    return result;
}

}  // namespace

QJsonArray parseV4l2FormatsText(const QString& text)
{
    QMap<QString, QJsonObject> formats;
    QString currentFourcc;
    QString currentKey;
    const QRegularExpression fourccRe(R"(\[\d+\]:\s+'([^']+)')");
    const QRegularExpression sizeRe(R"(Size:\s+Discrete\s+(\d+)x(\d+))");
    const QRegularExpression fpsRe(R"(\((\d+(?:\.\d+)?)\s+fps\))");

    for (const auto& line : text.split('\n')) {
        const auto fourccMatch = fourccRe.match(line);
        if (fourccMatch.hasMatch()) {
            currentFourcc = fourccMatch.captured(1).trimmed();
            currentKey.clear();
            continue;
        }
        const auto sizeMatch = sizeRe.match(line);
        if (sizeMatch.hasMatch() && !currentFourcc.isEmpty()) {
            const int width = sizeMatch.captured(1).toInt();
            const int height = sizeMatch.captured(2).toInt();
            currentKey = QString("%1:%2x%3").arg(currentFourcc).arg(width).arg(height);
            formats.insert(currentKey, QJsonObject{
                {"fourcc", currentFourcc},
                {"width", width},
                {"height", height},
                {"fps", QJsonArray{}},
            });
            continue;
        }
        const auto fpsMatch = fpsRe.match(line);
        if (fpsMatch.hasMatch() && formats.contains(currentKey)) {
            auto item = formats.value(currentKey);
            auto fps = item.value("fps").toArray();
            const int fpsValue = qRound(fpsMatch.captured(1).toDouble());
            if (!fps.contains(fpsValue)) {
                fps.append(fpsValue);
                item["fps"] = fps;
                formats.insert(currentKey, item);
            }
        }
    }

    for (auto it = formats.begin(); it != formats.end(); ++it) {
        auto item = it.value();
        if (item.value("fps").toArray().isEmpty()) {
            item["fps"] = QJsonArray{30};
            it.value() = item;
        }
    }
    return sortedFormats(formats);
}

double parseMacPowermetricsTemperatureText(const QString& text)
{
    const QRegularExpression pattern(
        R"((?:CPU|SoC|Package|Die|GPU|ANE)[^\n:]{0,64}(?:temperature|temp)[^\n:]{0,16}[:=]?\s*([0-9]+(?:\.[0-9]+)?)\s*(?:C|°C)?)",
        QRegularExpression::CaseInsensitiveOption);
    double highest = 0.0;
    auto match = pattern.globalMatch(text);
    while (match.hasNext()) {
        bool ok = false;
        const double value = match.next().captured(1).toDouble(&ok);
        if (ok && value > 0.0 && value < 130.0) {
            highest = std::max(highest, value);
        }
    }
    return highest;
}

namespace {

QJsonArray discoverCameras()
{
    QJsonArray cameras;

#if defined(Q_OS_LINUX)
    const QDir dev("/dev");
    const auto entries = dev.entryInfoList({"video*"}, QDir::System | QDir::Readable | QDir::Writable, QDir::Name);
    for (const auto& entry : entries) {
        const auto path = entry.absoluteFilePath();
        auto name = commandOutput("v4l2-ctl", {"--device", path, "--info"});
        if (name.isEmpty()) {
            name = QFileInfo(path).fileName();
        } else {
            const auto lines = name.split('\n');
            for (const auto& line : lines) {
                if (line.contains("Card type", Qt::CaseInsensitive)) {
                    name = line.section(':', 1).trimmed();
                    break;
                }
            }
        }
        auto formats = parseV4l2FormatsText(commandOutput("v4l2-ctl", {"--device", path, "--list-formats-ext"}, 1200));
        if (formats.isEmpty()) {
            formats = fallbackV4l2Formats();
        }
        cameras.append(QJsonObject{
            {"id", QString("v4l2:%1").arg(path)},
            {"source", "v4l2"},
            {"device", path},
            {"name", name},
            {"available", true},
            {"recommended", cameras.isEmpty()},
            {"formats", formats},
        });
    }
    if (gstElementAvailable("libcamerasrc")) {
        cameras.prepend(QJsonObject{
            {"id", "libcamera:auto"},
            {"source", "libcamera"},
            {"device", ""},
            {"name", "libcamera auto"},
            {"available", true},
            {"recommended", cameras.isEmpty()},
            {"formats", QJsonArray{
                QJsonObject{{"fourcc", "NV12"}, {"width", 1920}, {"height", 1080}, {"fps", QJsonArray{30}}},
            }},
        });
    }
#elif defined(Q_OS_MACOS)
    bool foundAny = false;
    GstDeviceProviderFactory* factory = gst_device_provider_factory_find("avfdeviceprovider");
    if (factory != nullptr) {
        GstDeviceProvider* provider = gst_device_provider_factory_get(factory);
        if (provider != nullptr) {
            GList* devices = gst_device_provider_get_devices(provider);
            int index = 0;
            for (GList* l = devices; l != nullptr; l = l->next) {
                auto* device = GST_DEVICE(l->data);
                gchar* name = gst_device_get_display_name(device);
                
                // Get unique-id from properties to match the actual AVFoundation index
                GstStructure* props = gst_device_get_properties(device);
                QString uniqueId;
                if (props) {
                    const gchar* uid = gst_structure_get_string(props, "avf.unique_id");
                    if (uid) {
                        uniqueId = QString::fromUtf8(uid);
                    }
                    gst_structure_free(props);
                }
                
                int actualIndex = -1;
                if (!uniqueId.isEmpty()) {
                    @autoreleasepool {
                        NSArray *avDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
                        for (int i = 0; i < [avDevices count]; ++i) {
                            AVCaptureDevice *avDev = [avDevices objectAtIndex:i];
                            NSString *avUid = [avDev uniqueID];
                            if (uniqueId == QString::fromUtf8([avUid UTF8String])) {
                                actualIndex = i;
                                break;
                            }
                        }
                    }
                }
                if (actualIndex == -1) {
                    actualIndex = index;
                }

                QString deviceValue = uniqueId.isEmpty() ? QString::number(actualIndex) : uniqueId;
                cameras.append(QJsonObject{
                    {"id", QString("avfoundation:%1").arg(deviceValue)},
                    {"source", "avfoundation"},
                    {"device", deviceValue},
                    {"name", QString::fromUtf8(name)},
                    {"available", true},
                    {"recommended", actualIndex == 0},
                    {"formats", QJsonArray{
                        QJsonObject{{"fourcc", "NV12"}, {"width", 1920}, {"height", 1080}, {"fps", QJsonArray{30}}},
                        QJsonObject{{"fourcc", "NV12"}, {"width", 1280}, {"height", 720}, {"fps", QJsonArray{30}}},
                        QJsonObject{{"fourcc", "NV12"}, {"width", 640}, {"height", 480}, {"fps", QJsonArray{30}}},
                    }},
                });
                g_free(name);
                index++;
                foundAny = true;
            }
            g_list_free_full(devices, gst_object_unref);
            gst_object_unref(provider);
        }
        gst_object_unref(factory);
    }

    if (!foundAny) {
        cameras.append(QJsonObject{
            {"id", "avfoundation:0"},
            {"source", "avfoundation"},
            {"device", "0"},
            {"name", "macOS default camera"},
            {"available", gstElementAvailable("avfvideosrc")},
            {"recommended", true},
            {"formats", QJsonArray{
                QJsonObject{{"fourcc", "NV12"}, {"width", 1920}, {"height", 1080}, {"fps", QJsonArray{30}}},
                QJsonObject{{"fourcc", "NV12"}, {"width", 1280}, {"height", 720}, {"fps", QJsonArray{30}}},
                QJsonObject{{"fourcc", "NV12"}, {"width", 640}, {"height", 480}, {"fps", QJsonArray{30}}},
            }},
        });
    }
#endif

    cameras.append(QJsonObject{
        {"id", "mock:test-pattern"},
        {"source", "mock"},
        {"device", ""},
        {"name", "Test pattern"},
        {"available", gstElementAvailable("videotestsrc")},
        {"recommended", cameras.isEmpty()},
        {"formats", QJsonArray{
            QJsonObject{{"fourcc", "RGB"}, {"width", 1280}, {"height", 1280}, {"fps", QJsonArray{30}}},
        }},
    });
    return cameras;
}

QJsonArray discoverPreviewTransports()
{
    return QJsonArray{
        QJsonObject{
            {"id", "iosurface_nv12"},
            {"name", "IOSurface NV12"},
            {"available", QOperatingSystemVersion::currentType() == QOperatingSystemVersion::MacOS},
            {"detail", "macOS native zero-copy texture path with shared-memory fallback"},
        },
        QJsonObject{
            {"id", "dmabuf_egl"},
            {"name", "DMA-BUF/EGL NV12"},
            {"available", QSysInfo::productType() == "raspbian" || QFileInfo::exists("/dev/dri")},
            {"detail", QFileInfo::exists("/dev/dri") ? "DRM device present" : "requires Linux DRM/EGL import path"},
        },
        QJsonObject{
            {"id", "shm_nv12"},
            {"name", "Shared memory NV12"},
            {"available", true},
            {"detail", "portable low-copy fallback for native texture preview"},
        },
        QJsonObject{
            {"id", "gstreamer_shm"},
            {"name", "GStreamer SHM"},
            {"available", gstElementAvailable("shmsink")},
            {"detail", "current preview transport"},
        },
        QJsonObject{
            {"id", "mjpeg"},
            {"name", "MJPEG fallback"},
            {"available", gstElementAvailable("jpegenc")},
            {"detail", "debug fallback; higher CPU than NV12 transports"},
        },
    };
}

QJsonArray discoverAiRuntimes(const AppConfig& config)
{
    const QFileInfo model(config.model.modelPath);
    QJsonArray runtimes;
    runtimes.append(QJsonObject{
        {"id", "onnx"},
        {"name", "ONNX Runtime"},
        {"available", model.exists()},
        {"detail", model.exists()
             ? QString("model found: %1 · labels mode: %2")
                   .arg(model.fileName(), config.model.labelsMode)
             : QString("model missing: %1").arg(config.model.modelPath)},
    });
    const bool hailoDevice = QFileInfo::exists("/dev/hailo0");
    const bool hailoCli = executableExists("hailortcli");
    runtimes.append(QJsonObject{
        {"id", "hailo"},
        {"name", "Hailo-8"},
        {"available", hailoDevice && hailoCli},
        {"detail", hailoDevice ? (hailoCli ? "device and hailortcli present" : "device present, hailortcli missing")
                               : "device not found"},
    });
    runtimes.append(QJsonObject{
        {"id", "mock"},
        {"name", "Mock inference"},
        {"available", true},
        {"detail", "deterministic simulated detections for development"},
    });
    return runtimes;
}

QJsonObject discoverGpio()
{
#if defined(Q_OS_LINUX)
    const bool gpioAllowed = hardwareGpioAllowed();
    const bool raspberryPi = isRaspberryPiBoard();
    const bool sysfs = QFileInfo::exists("/sys/class/gpio");
    QJsonArray chips;
    const QDir dev("/dev");
    for (const auto& entry : dev.entryInfoList({"gpiochip*"}, QDir::System | QDir::Readable | QDir::Writable, QDir::Name)) {
        chips.append(entry.absoluteFilePath());
    }
    const bool gpiodCli = executableExists("gpioget") && executableExists("gpioset");
    const bool libgpiod = !chips.isEmpty() && gpiodCli;
    const bool interfaceAvailable = sysfs || libgpiod;
    const bool available = gpioAllowed && interfaceAvailable;
    return {
        {"available", available},
        {"hardwareSupported", gpioAllowed},
        {"platformClass", platformClass()},
        {"boardModel", linuxBoardModel()},
        {"backend", available ? (libgpiod ? "libgpiod" : "sysfs") : "mock"},
        {"sysfsAvailable", sysfs},
        {"libgpiodAvailable", libgpiod},
        {"libgpiodCliAvailable", gpiodCli},
        {"chips", chips},
        {"availablePins", raspberryPi ? raspberryPiBcmPins() : QJsonArray{}},
        {"permissionsOk", available},
        {"detail", available
             ? QString("GPIO hardware controls enabled through %1").arg(libgpiod ? "libgpiod" : "sysfs")
             : (gpioAllowed ? "GPIO hardware is allowed but no GPIO interface was detected"
                            : "GPIO hardware controls are disabled on this platform; software controls active")},
    };
#else
    return {
        {"available", false},
        {"hardwareSupported", false},
        {"platformClass", platformClass()},
        {"boardModel", ""},
        {"backend", "mock"},
        {"sysfsAvailable", false},
        {"libgpiodAvailable", false},
        {"libgpiodCliAvailable", false},
        {"chips", QJsonArray{}},
        {"availablePins", QJsonArray{}},
        {"permissionsOk", true},
        {"detail", "GPIO mock active on non-Linux host"},
    };
#endif
}

QJsonObject discoverGStreamer()
{
    return {
        {"version", QString::fromUtf8(gst_version_string())},
        {"elements", QJsonObject{
            {"libcamerasrc", gstElementAvailable("libcamerasrc")},
            {"v4l2src", gstElementAvailable("v4l2src")},
            {"avfvideosrc", gstElementAvailable("avfvideosrc")},
            {"dshowvideosrc", gstElementAvailable("dshowvideosrc")},
            {"videotestsrc", gstElementAvailable("videotestsrc")},
            {"appsink", gstElementAvailable("appsink")},
            {"shmsink", gstElementAvailable("shmsink")},
            {"glupload", gstElementAvailable("glupload")},
            {"v4l2h264enc", gstElementAvailable("v4l2h264enc")},
            {"jpegenc", gstElementAvailable("jpegenc")},
        }},
    };
}

QJsonObject discoverSystem()
{
    return {
        {"os", QSysInfo::prettyProductName()},
        {"kernel", QSysInfo::kernelVersion()},
        {"arch", QSysInfo::currentCpuArchitecture()},
        {"hostname", QSysInfo::machineHostName()},
        {"appDir", QCoreApplication::applicationDirPath()},
        {"platformClass", platformClass()},
        {"boardModel", linuxBoardModel()},
    };
}

}  // namespace

CapabilitySnapshot discoverCapabilities(const AppConfig& config)
{
    return {QJsonObject{
        {"cameras", discoverCameras()},
        {"previewTransports", discoverPreviewTransports()},
        {"aiRuntimes", discoverAiRuntimes(config)},
        {"gpio", discoverGpio()},
        {"gstreamer", discoverGStreamer()},
        {"system", discoverSystem()},
    }};
}

QJsonObject toJson(const CapabilitySnapshot& capabilities)
{
    return capabilities.root;
}

QJsonObject validateConfig(const AppConfig& config, const CapabilitySnapshot& capabilities)
{
    QJsonArray warnings;
    QJsonArray errors;
    QJsonObject suggestedPatch;
    const auto mergeSuggestedPatch = [&](const QString& section, const QJsonObject& patch) {
        auto current = suggestedPatch.value(section).toObject();
        for (auto it = patch.begin(); it != patch.end(); ++it) {
            current.insert(it.key(), it.value());
        }
        suggestedPatch.insert(section, current);
    };

    const auto cameras = capabilities.root.value("cameras").toArray();
    bool cameraSourceAvailable = config.camera.source == "auto";
    QJsonObject recommendedCamera;
    for (const auto& raw : cameras) {
        const auto camera = raw.toObject();
        if (recommendedCamera.isEmpty() && camera.value("recommended").toBool()) {
            recommendedCamera = camera;
        }
        if (camera.value("source").toString() == config.camera.source && camera.value("available").toBool()) {
            cameraSourceAvailable = true;
        }
    }
    if (!cameraSourceAvailable) {
        errors.append(QString("Camera source '%1' is not available on this machine").arg(config.camera.source));
        if (!recommendedCamera.isEmpty()) {
            suggestedPatch.insert("camera", QJsonObject{
                {"source", recommendedCamera.value("source").toString()},
                {"device", recommendedCamera.value("device").toString()},
            });
        }
    }
    if (config.camera.width < 320 || config.camera.height < 320) {
        errors.append("Camera resolution is too small for detection");
    }
    if (config.camera.fps < 1 || config.camera.fps > 120) {
        errors.append("Camera FPS must be between 1 and 120");
    }
    if (config.camera.previewTransport != "auto") {
        const auto transports = capabilities.root.value("previewTransports").toArray();
        bool transportKnown = false;
        bool transportAvailable = false;
        QString transportDetail;
        for (const auto& raw : transports) {
            const auto transport = raw.toObject();
            if (transport.value("id").toString() == config.camera.previewTransport) {
                transportKnown = true;
                transportAvailable = transport.value("available").toBool();
                transportDetail = transport.value("detail").toString();
                break;
            }
        }
        if (!transportKnown) {
            errors.append(QString("Preview transport '%1' is not supported by this backend").arg(config.camera.previewTransport));
            suggestedPatch.insert("camera", QJsonObject{{"preview_transport", "auto"}});
        } else if (!transportAvailable) {
            warnings.append(QString("Preview transport '%1' is unavailable on this machine: %2")
                                .arg(config.camera.previewTransport, transportDetail));
            suggestedPatch.insert("camera", QJsonObject{{"preview_transport", "auto"}});
        }
    }

    const auto runtimes = capabilities.root.value("aiRuntimes").toArray();
    bool runtimeKnown = false;
    bool runtimeAvailable = false;
    QString runtimeDetail;
    for (const auto& raw : runtimes) {
        const auto runtime = raw.toObject();
        if (runtime.value("id").toString() == config.model.engine) {
            runtimeKnown = true;
            runtimeAvailable = runtime.value("available").toBool();
            runtimeDetail = runtime.value("detail").toString();
            break;
        }
    }
    if (!runtimeKnown) {
        errors.append(QString("AI runtime '%1' is not supported by this backend").arg(config.model.engine));
        suggestedPatch.insert("model", QJsonObject{{"engine", "mock"}});
    } else if (!runtimeAvailable) {
        errors.append(QString("AI runtime '%1' is unavailable: %2").arg(config.model.engine, runtimeDetail));
        suggestedPatch.insert("model", QJsonObject{{"engine", "mock"}});
    }
    if (config.model.engine == "onnx") {
        if (!QFileInfo::exists(config.model.modelPath)) {
            errors.append(QString("ONNX model file does not exist: %1").arg(config.model.modelPath));
        }
        if (config.model.labelsMode == "custom") {
            const auto labelsPath = resolvedLabelsPath(config.model);
            if (labelsPath.isEmpty() || !QFileInfo::exists(labelsPath)) {
                warnings.append(QString("Custom labels file does not exist: %1").arg(labelsPath));
            }
        }
    }
    if (config.model.confidenceThreshold <= 0.0 || config.model.confidenceThreshold >= 1.0) {
        errors.append("Confidence threshold must be greater than 0 and less than 1");
    }
    if (config.model.nmsThreshold <= 0.0 || config.model.nmsThreshold >= 1.0) {
        errors.append("NMS threshold must be greater than 0 and less than 1");
    }
    if (config.model.inputSize < 64 || config.model.inputSize > 2048) {
        errors.append("Model input size must be between 64 and 2048 pixels");
    } else if (config.model.inputSize % 32 != 0) {
        warnings.append("Model input size is usually a multiple of 32 for YOLO-style models");
    }

    const auto gpio = capabilities.root.value("gpio").toObject();
    const bool gpioAvailable = gpio.value("available").toBool();
    const bool libgpiodAvailable = gpio.value("libgpiodAvailable").toBool();
    const bool sysfsAvailable = gpio.value("sysfsAvailable").toBool();
    if (config.counting.triggerMode == "tray_sensor" && !gpioAvailable) {
        warnings.append("Tray sensor mode requires supported GPIO hardware; backend will use real-time software counting on this platform");
        suggestedPatch.insert("counting", QJsonObject{{"trigger_mode", "real_time"}});
    }
    if (config.gpio.backend == "libgpiod" && !libgpiodAvailable) {
        errors.append("GPIO backend 'libgpiod' was requested but libgpiod is not available");
        mergeSuggestedPatch("gpio", QJsonObject{{"backend", "auto"}});
    }
    if (config.gpio.backend == "sysfs" && !sysfsAvailable) {
        errors.append("GPIO backend 'sysfs' was requested but sysfs GPIO is not available");
        mergeSuggestedPatch("gpio", QJsonObject{{"backend", "auto"}});
    }
    const auto chips = gpio.value("chips").toArray();
    if ((config.gpio.backend == "libgpiod" || config.gpio.backend == "auto") && !chips.isEmpty()) {
        bool chipAllowed = false;
        const QString requestedChip = config.gpio.chip.startsWith('/')
            ? config.gpio.chip
            : QString("/dev/%1").arg(config.gpio.chip);
        for (const auto& raw : chips) {
            if (raw.toString() == requestedChip || QFileInfo(raw.toString()).fileName() == config.gpio.chip) {
                chipAllowed = true;
                break;
            }
        }
        if (!chipAllowed) {
            warnings.append(QString("GPIO chip '%1' is outside the detected gpiochip list").arg(config.gpio.chip));
            mergeSuggestedPatch("gpio", QJsonObject{{"chip", QFileInfo(chips.first().toString()).fileName()}});
        }
    }
    if (!config.safeMode && !gpioAvailable && gpio.value("hardwareSupported").toBool()) {
        warnings.append("GPIO hardware is supported but not currently available; backend will use software mock controls");
    }
    if (config.gpio.traySensorPin == config.gpio.relayPin) {
        errors.append("Tray sensor pin and relay pin must be different");
    }
    const auto availablePins = gpio.value("availablePins").toArray();
    if (gpioAvailable && !availablePins.isEmpty()) {
        const auto pinAllowed = [&](int pin) {
            for (const auto& raw : availablePins) {
                if (raw.toInt(-1) == pin) {
                    return true;
                }
            }
            return false;
        };
        if (!pinAllowed(config.gpio.traySensorPin)) {
            warnings.append(QString("Tray sensor GPIO %1 is outside the detected board pin list")
                                .arg(config.gpio.traySensorPin));
        }
        if (!pinAllowed(config.gpio.relayPin)) {
            warnings.append(QString("Relay GPIO %1 is outside the detected board pin list")
                                .arg(config.gpio.relayPin));
        }
    }
    if (config.gpio.debounceMs < 0 || config.gpio.debounceMs > 5000) {
        errors.append("GPIO debounce must be between 0 and 5000 ms");
    }

    bool selectedPartExists = config.counting.partTypes.isEmpty() && config.counting.selectedPartType.isEmpty();
    QSet<QString> partIds;
    for (const auto& part : config.counting.partTypes) {
        if (part.id.isEmpty()) {
            errors.append("Part type id cannot be empty");
            continue;
        }
        if (partIds.contains(part.id)) {
            errors.append(QString("Duplicate part type id: %1").arg(part.id));
        }
        partIds.insert(part.id);
        if (part.enabled && part.id == config.counting.selectedPartType) {
            selectedPartExists = true;
        }
    }
    if (config.counting.partTypes.isEmpty()) {
        warnings.append("No target catalog entries are configured yet");
    } else if (!selectedPartExists) {
        errors.append(QString("Selected part type '%1' is not enabled or does not exist").arg(config.counting.selectedPartType));
    }
    if (config.counting.stableFrames < 1 || config.counting.stableFrames > 60) {
        errors.append("Stable frames must be between 1 and 60");
    }
    if (config.counting.timeoutMs < 100 || config.counting.timeoutMs > 60000) {
        errors.append("Counting timeout must be between 100 and 60000 ms");
    }
    if (config.counting.triggerMode != "tray_sensor" && config.counting.triggerMode != "real_time" &&
        config.counting.triggerMode != "manual_button") {
        errors.append(QString("Unknown trigger mode: %1").arg(config.counting.triggerMode));
        suggestedPatch.insert("counting", QJsonObject{{"trigger_mode", "tray_sensor"}});
    }

    return {
        {"ok", errors.isEmpty()},
        {"warnings", warnings},
        {"errors", errors},
        {"suggestedPatch", suggestedPatch},
    };
}

double readProcessRam(qint64 pid)
{
    if (pid <= 0) return 0.0;
#ifdef Q_OS_MAC
    struct proc_taskinfo pti;
    if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &pti, sizeof(pti)) == sizeof(pti)) {
        return pti.pti_resident_size / (1024.0 * 1024.0); // bytes to MB
    }
    return 0.0;
#else
    QFile file(QString("/proc/%1/status").arg(pid));
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        while (!file.atEnd()) {
            QString line = file.readLine();
            if (line.startsWith("VmRSS:")) {
                QStringList parts = line.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
                if (parts.size() >= 2) {
                    file.close();
                    return parts[1].toDouble() / 1024.0; // kB to MB
                }
            }
        }
        file.close();
    }
    return 0.0;
#endif
}

double readProcessCpu(qint64 pid, unsigned long long& lastProcTime, unsigned long long& lastSysTime)
{
    if (pid <= 0) return 0.0;
#ifdef Q_OS_MAC
    struct proc_taskinfo pti;
    unsigned long long procTime = 0;
    if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &pti, sizeof(pti)) == sizeof(pti)) {
        procTime = pti.pti_total_user + pti.pti_total_system;
        static mach_timebase_info_data_t timebase_info;
        if (timebase_info.denom == 0) {
            mach_timebase_info(&timebase_info);
        }
        if (timebase_info.denom > 0) {
            procTime = procTime * timebase_info.numer / timebase_info.denom;
        }
    }
    unsigned long long sysTime = QDateTime::currentMSecsSinceEpoch() * 1000000ULL;
    double cpu = 0.0;
    if (lastSysTime > 0 && sysTime > lastSysTime) {
        unsigned long long sysDelta = sysTime - lastSysTime;
        unsigned long long procDelta = procTime - lastProcTime;
        int cores = QThread::idealThreadCount();
        if (sysDelta > 0 && cores > 0) {
            cpu = 100.0 * procDelta / sysDelta / cores;
        }
    }
    lastProcTime = procTime;
    lastSysTime = sysTime;
    return cpu;
#else
    unsigned long long procTime = 0;
    QFile statFile(QString("/proc/%1/stat").arg(pid));
    if (statFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString line = statFile.readAll();
        statFile.close();
        int lastParen = line.lastIndexOf(')');
        if (lastParen != -1) {
            QString rest = line.mid(lastParen + 2);
            QStringList tokens = rest.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
            if (tokens.size() >= 13) {
                procTime = tokens[11].toULongLong() + tokens[12].toULongLong();
            }
        }
    }

    unsigned long long sysTime = 0;
    QFile sysFile("/proc/stat");
    if (sysFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString line = sysFile.readLine();
        sysFile.close();
        QStringList tokens = line.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
        if (tokens.size() >= 5 && tokens[0] == "cpu") {
            sysTime = tokens[1].toULongLong() + tokens[2].toULongLong() + tokens[3].toULongLong() + tokens[4].toULongLong();
            if (tokens.size() > 5) sysTime += tokens[5].toULongLong();
            if (tokens.size() > 6) sysTime += tokens[6].toULongLong();
            if (tokens.size() > 7) sysTime += tokens[7].toULongLong();
            if (tokens.size() > 8) sysTime += tokens[8].toULongLong();
        }
    }

    double cpu = 0.0;
    if (lastSysTime > 0 && sysTime > lastSysTime) {
        unsigned long long sysDelta = sysTime - lastSysTime;
        unsigned long long procDelta = procTime - lastProcTime;
        if (sysDelta > 0) {
            cpu = 100.0 * procDelta / sysDelta;
        }
    }
    lastProcTime = procTime;
    lastSysTime = sysTime;
    return cpu;
#endif
}

#ifdef Q_OS_MAC
double readMacTemperature()
{
    static double cachedTemperature = 0.0;
    static qint64 lastReadMs = 0;

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    if (lastReadMs > 0 && nowMs - lastReadMs < 10000) {
        return cachedTemperature;
    }
    lastReadMs = nowMs;

    const auto output = commandOutput(
        "/usr/bin/sudo",
        {"-n", "/usr/bin/powermetrics", "-n", "1", "-i", "100", "--show-all"},
        2500);
    cachedTemperature = parseMacPowermetricsTemperatureText(output);
    return cachedTemperature;
}
#endif

SystemMetrics readSystemMetrics(qint64 daemonPid, qint64 flutterPid)
{
    SystemMetrics metrics;

#ifdef Q_OS_MAC
    // 1. CPU Usage on macOS
    static unsigned long long lastSysTotalTicks = 0;
    static unsigned long long lastSysIdleTicks = 0;
    
    double systemCpu = 0.0;
    host_cpu_load_info_data_t cpu_load;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&cpu_load, &count) == KERN_SUCCESS) {
        unsigned long long user = cpu_load.cpu_ticks[CPU_STATE_USER];
        unsigned long long nice = cpu_load.cpu_ticks[CPU_STATE_NICE];
        unsigned long long system = cpu_load.cpu_ticks[CPU_STATE_SYSTEM];
        unsigned long long idle = cpu_load.cpu_ticks[CPU_STATE_IDLE];
        
        unsigned long long total = user + nice + system + idle;
        if (lastSysTotalTicks > 0 && total > lastSysTotalTicks) {
            unsigned long long totalDelta = total - lastSysTotalTicks;
            unsigned long long idleDelta = idle - lastSysIdleTicks;
            systemCpu = 100.0 * (totalDelta - idleDelta) / totalDelta;
        }
        lastSysTotalTicks = total;
        lastSysIdleTicks = idle;
    }
    metrics.cpuUsage = systemCpu;

    // 2. RAM Usage on macOS
    int mib[2] = {CTL_HW, HW_MEMSIZE};
    int64_t total_mem = 0;
    size_t len = sizeof(total_mem);
    double systemRam = 0.0;
    if (sysctl(mib, 2, &total_mem, &len, NULL, 0) == 0 && total_mem > 0) {
        vm_size_t page_size;
        mach_port_t host_port = mach_host_self();
        mach_msg_type_number_t vm_count = HOST_VM_INFO64_COUNT;
        vm_statistics64_data_t vm_stats;
        if (host_page_size(host_port, &page_size) == KERN_SUCCESS &&
            host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stats, &vm_count) == KERN_SUCCESS) {
            int64_t used_mem = (vm_stats.active_count + vm_stats.inactive_count + vm_stats.wire_count) * (int64_t)page_size;
            systemRam = 100.0 * used_mem / total_mem;
        }
    }
    metrics.ramUsage = systemRam;

    // 3. CPU Temperature on macOS. powermetrics requires root/admin
    // privileges on most systems; 0.0 means the sensor is unavailable.
    metrics.temperature = readMacTemperature();

    // 4. Process specific CPU & Memory
    static unsigned long long lastDaemonProcTime = 0;
    static unsigned long long lastDaemonSysTime = 0;
    static unsigned long long lastFlutterProcTime = 0;
    static unsigned long long lastFlutterSysTime = 0;

    metrics.daemonRam = readProcessRam(daemonPid);
    metrics.daemonCpu = readProcessCpu(daemonPid, lastDaemonProcTime, lastDaemonSysTime);

    if (flutterPid > 0) {
        metrics.flutterRam = readProcessRam(flutterPid);
        metrics.flutterCpu = readProcessCpu(flutterPid, lastFlutterProcTime, lastFlutterSysTime);
    } else {
        metrics.flutterRam = 0.0;
        metrics.flutterCpu = 0.0;
        lastFlutterProcTime = 0;
        lastFlutterSysTime = 0;
    }
#else
    // 1. CPU Usage
    static unsigned long long lastTotal = 0;
    static unsigned long long lastIdleTime = 0;

    QFile statFile("/proc/stat");
    if (statFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString line = statFile.readLine();
        statFile.close();
        QStringList tokens = line.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
        if (tokens.size() >= 5 && tokens[0] == "cpu") {
            unsigned long long user = tokens[1].toULongLong();
            unsigned long long nice = tokens[2].toULongLong();
            unsigned long long system = tokens[3].toULongLong();
            unsigned long long idle = tokens[4].toULongLong();
            unsigned long long iowait = tokens.size() > 5 ? tokens[5].toULongLong() : 0;
            unsigned long long irq = tokens.size() > 6 ? tokens[6].toULongLong() : 0;
            unsigned long long softirq = tokens.size() > 7 ? tokens[7].toULongLong() : 0;
            unsigned long long steal = tokens.size() > 8 ? tokens[8].toULongLong() : 0;

            unsigned long long total = user + nice + system + idle + iowait + irq + softirq + steal;
            unsigned long long idled = idle + iowait;

            if (lastTotal > 0) {
                unsigned long long totalDelta = total - lastTotal;
                unsigned long long idleDelta = idled - lastIdleTime;
                if (totalDelta > 0 && totalDelta >= idleDelta) {
                    metrics.cpuUsage = 100.0 * (totalDelta - idleDelta) / totalDelta;
                }
            }
            lastTotal = total;
            lastIdleTime = idled;
        }
    }

    // 2. RAM Usage
    QFile memFile("/proc/meminfo");
    if (memFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        unsigned long long totalMem = 0;
        unsigned long long availMem = 0;
        while (!memFile.atEnd()) {
            QString line = memFile.readLine();
            if (line.startsWith("MemTotal:")) {
                totalMem = line.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts)[1].toULongLong();
            } else if (line.startsWith("MemAvailable:")) {
                availMem = line.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts)[1].toULongLong();
            }
        }
        memFile.close();
        if (totalMem > 0 && totalMem >= availMem) {
            metrics.ramUsage = 100.0 * (totalMem - availMem) / totalMem;
        }
    }

    // 3. CPU Temperature
    QFile tempFile("/sys/class/thermal/thermal_zone0/temp");
    if (tempFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        double tempVal = tempFile.readAll().trimmed().toDouble();
        tempFile.close();
        metrics.temperature = tempVal / 1000.0;
    }

    // 4. Process specific CPU & Memory
    static unsigned long long lastDaemonProcTime = 0;
    static unsigned long long lastDaemonSysTime = 0;
    static unsigned long long lastFlutterProcTime = 0;
    static unsigned long long lastFlutterSysTime = 0;

    metrics.daemonRam = readProcessRam(daemonPid);
    metrics.daemonCpu = readProcessCpu(daemonPid, lastDaemonProcTime, lastDaemonSysTime);

    if (flutterPid > 0) {
        metrics.flutterRam = readProcessRam(flutterPid);
        metrics.flutterCpu = readProcessCpu(flutterPid, lastFlutterProcTime, lastFlutterSysTime);
    } else {
        metrics.flutterRam = 0.0;
        metrics.flutterCpu = 0.0;
        lastFlutterProcTime = 0;
        lastFlutterSysTime = 0;
    }
#endif

    return metrics;
}

int resolveAVFoundationDeviceIndex(const QString& deviceStr)
{
    if (deviceStr.isEmpty()) {
        return 0;
    }
#ifdef Q_OS_MACOS
    @autoreleasepool {
        NSArray *avDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (int i = 0; i < [avDevices count]; ++i) {
            AVCaptureDevice *avDev = [avDevices objectAtIndex:i];
            NSString *avUid = [avDev uniqueID];
            if (deviceStr == QString::fromUtf8([avUid UTF8String])) {
                return i;
            }
        }
    }
#endif
    bool isOk = false;
    int index = deviceStr.toInt(&isOk);
    if (isOk) {
        return index;
    }
    return 0;
}

QString migrateAVFoundationDeviceIndexToUniqueId(const QString& deviceStr)
{
#ifdef Q_OS_MACOS
    bool isOk = false;
    int idx = deviceStr.toInt(&isOk);
    if (isOk) {
        @autoreleasepool {
            NSArray *avDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
            if (idx >= 0 && idx < [avDevices count]) {
                AVCaptureDevice *avDev = [avDevices objectAtIndex:idx];
                return QString::fromUtf8([[avDev uniqueID] UTF8String]);
            }
        }
    }
#endif
    return deviceStr;
}

}  // namespace beenut
