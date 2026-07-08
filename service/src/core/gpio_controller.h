#pragma once

#include "app_config.h"

#include <QObject>
#include <QString>

namespace beenut {

class GpioController : public QObject {
    Q_OBJECT

public:
    explicit GpioController(GpioConfig config, bool safeMode, QObject* parent = nullptr);
    ~GpioController() override;

    bool start();
    bool reload(GpioConfig config, bool safeMode);
    void stop();
    void setSafeMode(bool enabled);
    void setTrayOverride(bool present);
    void setLight(bool enabled);

    bool trayPresent() const;
    bool lightOn() const;
    QString status() const;
    QString detail() const;

private:
    enum class Backend {
        Mock,
        Sysfs,
        Libgpiod,
    };

    bool exportPin(int pin);
    bool writePinFile(int pin, const QString& name, const QString& value);
    QString readPinFile(int pin, const QString& name) const;
    bool configureGpiodPins();
    bool configureLinuxPins();
    bool readGpiodPin(int pin, bool fallback) const;
    bool writeGpiodPin(int pin, bool active);
    bool readLinuxPin(int pin, bool fallback) const;
    void writeLinuxPin(int pin, bool active);

    GpioConfig config_;
    bool safeMode_ = false;
    Backend backend_ = Backend::Mock;
    bool ready_ = false;
    bool trayOverride_ = false;
    bool lightOn_ = false;
    QString status_ = "missing";
    QString detail_ = "GPIO controller not initialized";
};

}  // namespace beenut
