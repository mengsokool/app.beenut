#include "app_config.h"
#include "app_runtime.h"
#include "counting_tracker.h"
#include "hardware_discovery.h"
#include "onnx_yolo_engine.h"

#include <QJsonObject>
#include <QFile>
#include <QJsonArray>
#include <QtGlobal>

#include <cstdlib>
#include <iostream>

namespace {

beenut::InferenceResult resultWithCount(int count)
{
    beenut::InferenceResult result;
    result.count = count;
    result.processingMs = 3;
    result.detections.append({
        .label = QString("class_%1").arg(count),
        .confidence = 0.9,
        .x = 0.1,
        .y = 0.2,
        .w = 0.3,
        .h = 0.4,
    });
    return result;
}
void expect(bool condition, const char* message)
{
    if (!condition) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}

void testCountingTrackerLocksMedianSample()
{
    beenut::CountingConfig config;
    config.stableFrames = 3;
    config.timeoutMs = 1000;
    beenut::CountingTracker tracker(config);

    auto snapshot = tracker.update(true, resultWithCount(2));
    expect(!snapshot.locked, "tracker should not lock before stable frame window is full");
    expect(snapshot.samples == 1, "tracker should report first sample");

    snapshot = tracker.update(true, resultWithCount(7));
    expect(!snapshot.locked, "tracker should still wait for stable frame window");
    expect(snapshot.samples == 2, "tracker should report second sample");

    snapshot = tracker.update(true, resultWithCount(5));
    expect(snapshot.locked, "tracker should lock when stable frame window is full");
    expect(snapshot.count == 5, "tracker should lock to median count");
    expect(snapshot.samples == 3, "tracker should keep stable frame sample count");
    expect(snapshot.detections.size() == 1, "tracker should keep detections from median sample");
    expect(snapshot.detections.first().label == "class_5", "tracker should choose median sample detections");

    snapshot = tracker.update(false, resultWithCount(9));
    expect(!snapshot.locked, "tracker should reset when tray is not present");
    expect(snapshot.count == 0, "tracker should clear count after tray removal");
}

void testCountingTrackerUsesLowerMedianForEvenWindow()
{
    beenut::CountingConfig config;
    config.stableFrames = 4;
    config.timeoutMs = 1000;
    beenut::CountingTracker tracker(config);

    tracker.update(true, resultWithCount(2));
    tracker.update(true, resultWithCount(4));
    tracker.update(true, resultWithCount(8));
    const auto snapshot = tracker.update(true, resultWithCount(10));

    expect(snapshot.locked, "tracker should lock when even stable frame window is full");
    expect(snapshot.count == 4, "tracker should use lower median for even sample windows");
    expect(snapshot.detections.size() == 1, "tracker should keep detections from lower median sample");
    expect(snapshot.detections.first().label == "class_4", "tracker should choose lower median sample detections");
}

void testLabelMatchesPartWithoutDomainHardcoding()
{
    using beenut::labelMatchesPart;

    expect(labelMatchesPart("person", "person"), "direct label should match selected part id");
    expect(labelMatchesPart("large_class_a", "target-a", {"class_a"}),
           "keyword should map model class to selected part");
    expect(labelMatchesPart("Class A", "target-a", {" class a "}),
           "keyword matching should be case-insensitive and trim spaces");
    expect(labelMatchesPart("anything", ""), "empty selected part should accept any label");
    expect(!labelMatchesPart("person", "washer", {"hex_nut"}),
           "unrelated legacy/domain label should not match");
}

void testModelInputSizeRoundTripsConfig()
{
    const QJsonObject root{
        {"model", QJsonObject{
            {"input_size", 512},
        }},
        {"gpio", QJsonObject{
            {"backend", "libgpiod"},
            {"chip", "gpiochip4"},
        }},
        {"ui", QJsonObject{
            {"scale", 1.15},
        }},
    };

    const auto config = beenut::parseConfig(root);
    expect(config.model.inputSize == 512, "model input_size should parse from config");
    expect(config.gpio.backend == "libgpiod", "gpio backend should parse from config");
    expect(config.gpio.chip == "gpiochip4", "gpio chip should parse from config");
    expect(config.ui.scale == 1.15, "ui scale should parse from config");

    const auto json = beenut::toJson(config);
    const auto model = json.value("model").toObject();
    expect(model.value("input_size").toInt() == 512, "model input_size should round-trip to json");
    const auto gpio = json.value("gpio").toObject();
    expect(gpio.value("backend").toString() == "libgpiod", "gpio backend should round-trip to json");
    expect(gpio.value("chip").toString() == "gpiochip4", "gpio chip should round-trip to json");
    const auto ui = json.value("ui").toObject();
    expect(ui.value("scale").toDouble() == 1.15, "ui scale should round-trip to json");

    expect(beenut::parseConfig({{"ui", QJsonObject{{"scale", 3.0}}}}).ui.scale == 2.0,
           "ui scale should clamp to maximum supported scale");
    expect(beenut::parseConfig({{"ui", QJsonObject{{"scale", 0.2}}}}).ui.scale == 0.5,
           "ui scale should clamp to minimum supported scale");
}

void testRuntimeCountingModeFallbacks()
{
    using beenut::countInputPresent;
    using beenut::effectiveRealTimeMode;
    using beenut::hardwareTraySensorActive;
    using beenut::shouldUseCameraLowPower;

    expect(hardwareTraySensorActive("tray_sensor", "ready"),
           "tray sensor should be active only when GPIO is ready");
    expect(!hardwareTraySensorActive("tray_sensor", "mock"),
           "mock GPIO should not count as active tray hardware");
    expect(effectiveRealTimeMode("real_time", "ready"),
           "real_time trigger should always run as realtime");
    expect(effectiveRealTimeMode("tray_sensor", "mock"),
           "tray_sensor should fallback to realtime when GPIO is unavailable");
    expect(!effectiveRealTimeMode("tray_sensor", "ready"),
           "tray_sensor should not fallback when GPIO is ready");
    expect(countInputPresent("tray_sensor", "mock", false),
           "missing GPIO fallback should make inference input present");
    expect(!countInputPresent("tray_sensor", "ready", false),
           "ready tray sensor should wait for tray presence");
    expect(countInputPresent("tray_sensor", "ready", true),
           "ready tray sensor should count when tray is present");
    expect(!shouldUseCameraLowPower(false, false, true, false, false, false),
           "active realtime counting should keep camera out of low power");
    expect(shouldUseCameraLowPower(false, true, true, true, true, false),
           "preview pause should force low power");
    expect(shouldUseCameraLowPower(false, false, true, true, true, true),
           "thermal policy should force low power");
}

void testThermalPolicyBalancesSpeedAndHeat()
{
    const auto normal = beenut::thermalPolicyFor(55.0, 4.0);
    expect(normal.state == "normal", "cool machine should stay in normal thermal state");
    expect(normal.aiMaxFpsScale == 1.0, "cool machine should keep full AI FPS");
    expect(!normal.forceLowPower, "cool machine should not force low power");

    const auto warning = beenut::thermalPolicyFor(69.0, 4.0);
    expect(warning.state == "warning", "warm machine should enter warning thermal state");
    expect(warning.aiMaxFpsScale < 1.0 && warning.aiMaxFpsScale > 0.75,
           "warning thermal state should shave AI FPS lightly");

    const auto hot = beenut::thermalPolicyFor(75.0, 4.0);
    expect(hot.state == "hot", "hot machine should enter hot thermal state");
    expect(hot.aiMaxFpsScale == 0.75, "hot thermal state should reduce AI FPS before throttling");

    const auto critical = beenut::thermalPolicyFor(86.0, 4.0);
    expect(critical.state == "critical", "critical temperature should enter critical thermal state");
    expect(critical.forceLowPower, "critical thermal state should force low power");
    expect(critical.aiMaxFpsScale == 0.25, "critical thermal state should cap AI FPS aggressively");
}

void testConfigMigrationFromOldSchema()
{
    const QJsonObject oldRoot{
        {"safe_mode", false},
    };
    const auto config = beenut::parseConfig(oldRoot);
    expect(config.schemaVersion == 1, "schema_version should migrate to current version");
}

void testConfigAtomicSaveAndBackup()
{
    const QString testFile = "/tmp/beenut_test_config.json";
    const QString backupFile = testFile + ".bak";
    QFile::remove(testFile);
    QFile::remove(backupFile);

    beenut::AppConfig config;
    config.safeMode = true;
    config.model.inputSize = 480;

    QString error;
    bool ok = beenut::saveConfig(config, testFile, &error);
    expect(ok, "first config save should succeed");
    expect(QFile::exists(testFile), "config file should exist");
    expect(!QFile::exists(backupFile), "backup file should not exist on first save");

    config.model.inputSize = 512;
    ok = beenut::saveConfig(config, testFile, &error);
    expect(ok, "second config save should succeed");
    expect(QFile::exists(testFile), "config file should still exist");
    expect(QFile::exists(backupFile), "backup file should be created on second save");

    const auto backupConfig = beenut::loadConfig(backupFile);
    expect(backupConfig.model.inputSize == 480, "backup config should hold original value");

    const auto currentConfig = beenut::loadConfig(testFile);
    expect(currentConfig.model.inputSize == 512, "current config should hold new value");

    QFile::remove(testFile);
    QFile::remove(backupFile);
}

void testV4l2FormatParser()
{
    const QString sample = R"V4L2(
ioctl: VIDIOC_ENUM_FMT
	Type: Video Capture

	[0]: 'YUYV' (YUYV 4:2:2)
		Size: Discrete 640x480
			Interval: Discrete 0.033s (30.000 fps)
			Interval: Discrete 0.067s (15.000 fps)
		Size: Discrete 1280x720
			Interval: Discrete 0.033s (30.000 fps)
	[1]: 'MJPG' (Motion-JPEG)
		Size: Discrete 1920x1080
			Interval: Discrete 0.033s (30.000 fps)
)V4L2";

    const auto formats = beenut::parseV4l2FormatsText(sample);
    expect(formats.size() == 3, "v4l2 parser should return each discrete format");
    const auto first = formats.first().toObject();
    expect(first.value("fourcc").toString() == "MJPG", "v4l2 parser should sort largest format first");
    expect(first.value("width").toInt() == 1920, "v4l2 parser should parse width");
    expect(first.value("height").toInt() == 1080, "v4l2 parser should parse height");
    const auto firstFps = first.value("fps").toArray();
    expect(firstFps.contains(30), "v4l2 parser should parse fps values");

    const auto last = formats.last().toObject();
    const auto lastFps = last.value("fps").toArray();
    expect(last.value("fourcc").toString() == "YUYV", "v4l2 parser should keep fourcc");
    expect(last.value("width").toInt() == 640, "v4l2 parser should keep smaller format");
    expect(lastFps.contains(30) && lastFps.contains(15), "v4l2 parser should keep multiple fps values");
}

void testMacPowermetricsTemperatureParser()
{
    const QString sample = R"PM(
**** Processor usage ****
CPU die temperature: 71.6 C
GPU die temperature: 68.2 C
SoC temperature: 69.4 C
)PM";

    const double temperature = beenut::parseMacPowermetricsTemperatureText(sample);
    expect(temperature > 71.5 && temperature < 71.7,
           "macOS powermetrics parser should pick the hottest relevant temperature");
    expect(beenut::parseMacPowermetricsTemperatureText("powermetrics must be invoked as the superuser") == 0.0,
           "macOS powermetrics parser should return unavailable when no temperature is present");
}

void testGpioBackendValidation()
{
    beenut::AppConfig config;
    config.safeMode = true;
    config.camera.source = "mock";
    config.model.engine = "mock";
    config.counting.triggerMode = "real_time";
    config.gpio.backend = "libgpiod";
    config.gpio.chip = "gpiochip4";

    const beenut::CapabilitySnapshot capabilities{QJsonObject{
        {"cameras", QJsonArray{QJsonObject{
            {"source", "mock"},
            {"available", true},
            {"recommended", true},
        }}},
        {"previewTransports", QJsonArray{QJsonObject{
            {"id", "shm_nv12"},
            {"available", true},
        }}},
        {"aiRuntimes", QJsonArray{QJsonObject{
            {"id", "mock"},
            {"available", true},
        }}},
        {"gpio", QJsonObject{
            {"available", false},
            {"hardwareSupported", true},
            {"libgpiodAvailable", false},
            {"sysfsAvailable", false},
            {"chips", QJsonArray{"/dev/gpiochip0"}},
            {"availablePins", QJsonArray{}},
        }},
    }};

    const auto validation = beenut::validateConfig(config, capabilities);
    const auto errors = validation.value("errors").toArray();
    expect(!errors.isEmpty(), "libgpiod validation should reject missing backend");
    const auto patch = validation.value("suggestedPatch").toObject();
    expect(patch.value("gpio").toObject().value("backend").toString() == "auto",
           "libgpiod validation should suggest auto backend");
}

void testPoweroffCommandOverride()
{
    qputenv("BEENUT_POWEROFF_COMMAND", "/usr/bin/env true");
    QString detail;
    const bool ok = beenut::requestSystemPoweroff(&detail);
    qunsetenv("BEENUT_POWEROFF_COMMAND");

    expect(ok, "poweroff override command should be accepted for dry-run validation");
    expect(detail.contains("override:"), "poweroff override should report override detail");
}

void testPoweroffConfigOverride()
{
    QString detail;
    const bool ok = beenut::requestSystemPoweroff("/usr/bin/env true", &detail);

    expect(ok, "poweroff config override should be accepted for dry-run validation");
    expect(detail.contains("override:"), "poweroff config override should report override detail");
}

}  // namespace

int main()
{
    testCountingTrackerLocksMedianSample();
    testCountingTrackerUsesLowerMedianForEvenWindow();
    testLabelMatchesPartWithoutDomainHardcoding();
    testModelInputSizeRoundTripsConfig();
    testRuntimeCountingModeFallbacks();
    testThermalPolicyBalancesSpeedAndHeat();
    testConfigMigrationFromOldSchema();
    testConfigAtomicSaveAndBackup();
    testV4l2FormatParser();
    testMacPowermetricsTemperatureParser();
    testGpioBackendValidation();
    testPoweroffCommandOverride();
    testPoweroffConfigOverride();
    std::cout << "service_tests passed\n";
    return 0;
}
