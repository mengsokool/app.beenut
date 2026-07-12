#pragma once

#include <QString>

namespace beenut {

struct PoweroffCapability {
    bool available = false;
    QString detail;
};

PoweroffCapability discoverPoweroffCapability(const QString& configOverride = {});
bool requestSystemPoweroff(const QString& configOverride, QString* detail);
inline bool requestSystemPoweroff(QString* detail) { return requestSystemPoweroff({}, detail); }

}  // namespace beenut
