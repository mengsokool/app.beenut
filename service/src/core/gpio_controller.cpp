#include "gpio_controller.h"

#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QStringList>
#include <QTextStream>
#include <QtGlobal>

namespace beenut {
namespace {

QString gpioPath(int pin, const QString& name)
{
    return QString("/sys/class/gpio/gpio%1/%2").arg(pin).arg(name);
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

bool hardwareGpioAllowed()
{
#if defined(Q_OS_LINUX)
    if (qEnvironmentVariable("BEENUT_GPIO_ALLOW") == "1") {
        return true;
    }
    return linuxBoardModel().contains("Raspberry Pi", Qt::CaseInsensitive);
#else
    return false;
#endif
}

bool executableAvailable(const QString& name)
{
    return !QStandardPaths::findExecutable(name).isEmpty();
}

QString gpioChipDevicePath(const QString& chip)
{
    if (chip.startsWith('/')) {
        return chip;
    }
    return QString("/dev/%1").arg(chip.isEmpty() ? "gpiochip0" : chip);
}

bool gpioChipAvailable(const QString& chip)
{
    return QFileInfo::exists(gpioChipDevicePath(chip));
}

}  // namespace

GpioController::GpioController(GpioConfig config, bool safeMode, QObject* parent)
    : QObject(parent), config_(config), safeMode_(safeMode)
{
}

GpioController::~GpioController()
{
    stop();
}

bool GpioController::start()
{
    auto requestedBackend = qEnvironmentVariable("BEENUT_GPIO_BACKEND");
    if (requestedBackend.isEmpty()) {
        requestedBackend = config_.backend;
    }
    if (requestedBackend == "mock") {
        ready_ = false;
        backend_ = Backend::Mock;
        status_ = "mock";
        detail_ = "mock GPIO forced by runtime mode";
        return true;
    }
#if defined(Q_OS_LINUX)
    if (!hardwareGpioAllowed()) {
        ready_ = false;
        backend_ = Backend::Mock;
        status_ = "mock";
        detail_ = "GPIO hardware controls disabled on this platform";
        return true;
    }
    if (requestedBackend == "libgpiod" || requestedBackend.isEmpty() || requestedBackend == "auto") {
        ready_ = configureGpiodPins();
        if (ready_) {
            backend_ = Backend::Libgpiod;
            status_ = "ready";
            detail_ = "libgpiod GPIO active via gpiod CLI";
            setLight(false);
            return true;
        }
        if (requestedBackend == "libgpiod") {
            return false;
        }
    }
    if (requestedBackend == "sysfs" || requestedBackend.isEmpty() || requestedBackend == "auto") {
        ready_ = configureLinuxPins();
    } else {
        ready_ = false;
    }
    if (ready_) {
        backend_ = Backend::Sysfs;
        status_ = "ready";
        detail_ = "sysfs GPIO active";
        setLight(false);
        return true;
    }
    return false;
#else
    ready_ = false;
    backend_ = Backend::Mock;
    status_ = "mock";
    detail_ = "mock GPIO active on non-Linux host";
    return true;
#endif
}

void GpioController::stop()
{
    setLight(false);
    ready_ = false;
}

bool GpioController::reload(GpioConfig config, bool safeMode)
{
    stop();
    config_ = config;
    safeMode_ = safeMode;
    return start();
}

void GpioController::setSafeMode(bool enabled)
{
    safeMode_ = enabled;
    if (safeMode_) {
        setLight(false);
    }
}

void GpioController::setTrayOverride(bool present)
{
    trayOverride_ = present;
}

void GpioController::setLight(bool enabled)
{
    const bool allowed = enabled && !safeMode_;
    lightOn_ = allowed;
    if (ready_) {
        if (backend_ == Backend::Libgpiod) {
            writeGpiodPin(config_.relayPin, allowed);
        } else {
            writeLinuxPin(config_.relayPin, allowed);
        }
    }
}

bool GpioController::trayPresent() const
{
    if (!ready_) {
        return trayOverride_;
    }
    if (backend_ == Backend::Libgpiod) {
        return readGpiodPin(config_.traySensorPin, trayOverride_);
    }
    return readLinuxPin(config_.traySensorPin, trayOverride_);
}

bool GpioController::lightOn() const
{
    return lightOn_;
}

QString GpioController::status() const
{
    return status_;
}

QString GpioController::detail() const
{
    return detail_;
}

bool GpioController::exportPin(int pin)
{
    if (QFile::exists(QString("/sys/class/gpio/gpio%1").arg(pin))) {
        return true;
    }
    QFile exportFile("/sys/class/gpio/export");
    if (!exportFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        detail_ = exportFile.errorString();
        return false;
    }
    QTextStream stream(&exportFile);
    stream << pin;
    exportFile.close();
    return QFile::exists(QString("/sys/class/gpio/gpio%1").arg(pin));
}

bool GpioController::writePinFile(int pin, const QString& name, const QString& value)
{
    QFile file(gpioPath(pin, name));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        detail_ = QString("%1: %2").arg(gpioPath(pin, name), file.errorString());
        return false;
    }
    QTextStream stream(&file);
    stream << value;
    return true;
}

QString GpioController::readPinFile(int pin, const QString& name) const
{
    QFile file(gpioPath(pin, name));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }
    return QString::fromUtf8(file.readAll()).trimmed();
}

bool GpioController::configureLinuxPins()
{
#if defined(Q_OS_LINUX)
    if (!QFile::exists("/sys/class/gpio")) {
        status_ = "missing";
        detail_ = "sysfs GPIO is not available";
        return false;
    }
    if (!exportPin(config_.traySensorPin) || !exportPin(config_.relayPin)) {
        status_ = "error";
        return false;
    }
    if (!writePinFile(config_.traySensorPin, "direction", "in")) {
        status_ = "error";
        return false;
    }
    if (!writePinFile(config_.relayPin, "direction", "out")) {
        status_ = "error";
        return false;
    }
    writePinFile(config_.traySensorPin, "active_low", config_.activeLow ? "1" : "0");
    writePinFile(config_.relayPin, "active_low", config_.activeLow ? "1" : "0");
    return true;
#else
    return false;
#endif
}

bool GpioController::configureGpiodPins()
{
#if defined(Q_OS_LINUX)
    if (!gpioChipAvailable(config_.chip)) {
        status_ = "missing";
        detail_ = QString("libgpiod %1 is not available").arg(gpioChipDevicePath(config_.chip));
        return false;
    }
    if (!executableAvailable("gpioget") || !executableAvailable("gpioset")) {
        status_ = "missing";
        detail_ = "libgpiod CLI tools gpioget/gpioset are not available";
        return false;
    }
    if (!writeGpiodPin(config_.relayPin, false)) {
        status_ = "error";
        detail_ = QString("unable to write GPIO %1 through libgpiod on %2")
                      .arg(config_.relayPin)
                      .arg(config_.chip);
        return false;
    }
    return true;
#else
    return false;
#endif
}

bool GpioController::readGpiodPin(int pin, bool fallback) const
{
#if defined(Q_OS_LINUX)
    QProcess process;
    process.start("gpioget", {config_.chip, QString::number(pin)});
    if (!process.waitForFinished(500)) {
        return fallback;
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        return fallback;
    }
    const auto value = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    if (value == "0" || value == "1") {
        const bool raw = value == "1";
        return config_.activeLow ? !raw : raw;
    }
    return fallback;
#else
    Q_UNUSED(pin);
    return fallback;
#endif
}

bool GpioController::writeGpiodPin(int pin, bool active)
{
#if defined(Q_OS_LINUX)
    const bool raw = config_.activeLow ? !active : active;
    return QProcess::execute("gpioset", {config_.chip, QString("%1=%2").arg(pin).arg(raw ? 1 : 0)}) == 0;
#else
    Q_UNUSED(pin);
    Q_UNUSED(active);
    return false;
#endif
}

bool GpioController::readLinuxPin(int pin, bool fallback) const
{
    const auto value = readPinFile(pin, "value");
    if (value == "0") {
        return false;
    }
    if (value == "1") {
        return true;
    }
    return fallback;
}

void GpioController::writeLinuxPin(int pin, bool active)
{
    writePinFile(pin, "value", active ? "1" : "0");
}

}  // namespace beenut
