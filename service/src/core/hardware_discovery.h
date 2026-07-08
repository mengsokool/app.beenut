#pragma once

#include "app_config.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QString>

namespace beenut {

struct CapabilitySnapshot {
    QJsonObject root;
};

CapabilitySnapshot discoverCapabilities(const AppConfig& config);
QJsonObject toJson(const CapabilitySnapshot& capabilities);
QJsonObject validateConfig(const AppConfig& config, const CapabilitySnapshot& capabilities);
QJsonArray parseV4l2FormatsText(const QString& text);
double parseMacPowermetricsTemperatureText(const QString& text);
int resolveAVFoundationDeviceIndex(const QString& deviceStr);
QString migrateAVFoundationDeviceIndexToUniqueId(const QString& deviceStr);

struct SystemMetrics {
    double cpuUsage = 0.0;
    double ramUsage = 0.0;
    double temperature = 0.0;
    double daemonCpu = 0.0;
    double daemonRam = 0.0;
    double flutterCpu = 0.0;
    double flutterRam = 0.0;
};

SystemMetrics readSystemMetrics(qint64 daemonPid, qint64 flutterPid);

}  // namespace beenut
