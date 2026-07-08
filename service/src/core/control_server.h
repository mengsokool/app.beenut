#pragma once

#include "app_config.h"
#include "hardware_discovery.h"
#include "service_state.h"

#include <QLocalServer>
#include <QLocalSocket>
#include <QObject>
#include <QSet>

namespace beenut {

class ControlServer : public QObject {
    Q_OBJECT

public:
    explicit ControlServer(QString socketPath, QObject* parent = nullptr);
    bool start();
    void stop();
    void broadcast(const AppConfig& config, const ServiceState& state);
    void broadcastCapabilities(const CapabilitySnapshot& capabilities);
    void broadcastConfigValidation(const QJsonObject& validation);
    void broadcastConfigSaveResult(const QJsonObject& result);
    void broadcastDiagnosticEvent(const QJsonObject& event);
    qint64 clientPid() const;

signals:
    void partTypeRequested(const QString& partType);
    void trayOverrideRequested(bool present);
    void lightRequested(bool enabled);
    void countOnceRequested();
    void configSaveRequested(const QJsonObject& config);
    void configValidationRequested(const QJsonObject& config);
    void diagnosticRequested(const QString& target);
    void capabilitiesRequested();
    void capabilitiesRefreshRequested();
    void shutdownRequested();
    void previewPauseRequested(bool paused);
    void clientConnected();

private slots:
    void acceptClient();
    void readClient();
    void removeClient();

private:
    QString socketPath_;
    QLocalServer server_;
    QSet<QLocalSocket*> clients_;
};

}  // namespace beenut
