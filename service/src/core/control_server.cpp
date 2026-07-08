#include "control_server.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtGlobal>

#ifdef Q_OS_UNIX
#include <sys/socket.h>
#include <sys/types.h>
#ifdef Q_OS_LINUX
#include <sys/un.h>
#endif
#endif

#include <utility>

namespace beenut {

ControlServer::ControlServer(QString socketPath, QObject* parent)
    : QObject(parent), socketPath_(std::move(socketPath))
{
    connect(&server_, &QLocalServer::newConnection, this, &ControlServer::acceptClient);
}

bool ControlServer::start()
{
    QLocalServer::removeServer(socketPath_);
    QFile::remove(socketPath_);
    return server_.listen(socketPath_);
}

void ControlServer::stop()
{
    for (auto* client : std::as_const(clients_)) {
        client->disconnectFromServer();
        client->deleteLater();
    }
    clients_.clear();
    server_.close();
    QLocalServer::removeServer(socketPath_);
    QFile::remove(socketPath_);
}

void ControlServer::broadcast(const AppConfig& config, const ServiceState& state)
{
    const auto line = QJsonDocument(QJsonObject{
        {"type", "status"},
        {"config", toJson(config)},
        {"state", toJson(state)},
    }).toJson(QJsonDocument::Compact) + '\n';

    for (auto* client : std::as_const(clients_)) {
        client->write(line);
        client->flush();
    }
}

void ControlServer::broadcastCapabilities(const CapabilitySnapshot& capabilities)
{
    const auto line = QJsonDocument(QJsonObject{
        {"type", "capabilities"},
        {"capabilities", toJson(capabilities)},
    }).toJson(QJsonDocument::Compact) + '\n';

    for (auto* client : std::as_const(clients_)) {
        client->write(line);
        client->flush();
    }
}

void ControlServer::broadcastConfigValidation(const QJsonObject& validation)
{
    const auto line = QJsonDocument(QJsonObject{
        {"type", "configValidation"},
        {"validation", validation},
    }).toJson(QJsonDocument::Compact) + '\n';

    for (auto* client : std::as_const(clients_)) {
        client->write(line);
        client->flush();
    }
}

void ControlServer::broadcastConfigSaveResult(const QJsonObject& result)
{
    const auto line = QJsonDocument(QJsonObject{
        {"type", "configSaveResult"},
        {"result", result},
    }).toJson(QJsonDocument::Compact) + '\n';

    for (auto* client : std::as_const(clients_)) {
        client->write(line);
        client->flush();
    }
}

void ControlServer::broadcastDiagnosticEvent(const QJsonObject& event)
{
    const auto line = QJsonDocument(QJsonObject{
        {"type", "diagnosticEvent"},
        {"event", event},
    }).toJson(QJsonDocument::Compact) + '\n';

    for (auto* client : std::as_const(clients_)) {
        client->write(line);
        client->flush();
    }
}

void ControlServer::acceptClient()
{
    while (server_.hasPendingConnections()) {
        auto* client = server_.nextPendingConnection();
        clients_.insert(client);
        connect(client, &QLocalSocket::readyRead, this, &ControlServer::readClient);
        connect(client, &QLocalSocket::disconnected, this, &ControlServer::removeClient);
        emit clientConnected();
    }
}

void ControlServer::readClient()
{
    auto* client = qobject_cast<QLocalSocket*>(sender());
    if (client == nullptr) {
        return;
    }
    while (client->canReadLine()) {
        const auto object = QJsonDocument::fromJson(client->readLine().trimmed()).object();
        const auto type = object.value("type").toString();
        if (type == "selectPartType") {
            emit partTypeRequested(object.value("partType").toString());
        } else if (type == "testTray") {
            emit trayOverrideRequested(object.value("present").toBool());
        } else if (type == "testLight") {
            emit lightRequested(object.value("enabled").toBool());
        } else if (type == "countOnce") {
            emit countOnceRequested();
        } else if (type == "saveConfig") {
            emit configSaveRequested(object.value("config").toObject());
        } else if (type == "validateConfig") {
            emit configValidationRequested(object.value("config").toObject());
        } else if (type == "runDiagnostic") {
            emit diagnosticRequested(object.value("target").toString());
        } else if (type == "getCapabilities") {
            emit capabilitiesRequested();
        } else if (type == "refreshCapabilities") {
            emit capabilitiesRefreshRequested();
        } else if (type == "shutdown") {
            emit shutdownRequested();
        } else if (type == "setPreviewPaused") {
            emit previewPauseRequested(object.value("paused").toBool());
        }
    }
}

void ControlServer::removeClient()
{
    auto* client = qobject_cast<QLocalSocket*>(sender());
    if (client == nullptr) {
        return;
    }
    clients_.remove(client);
    client->deleteLater();
}

qint64 ControlServer::clientPid() const
{
    if (clients_.isEmpty()) {
        return 0;
    }
    auto* socket = *clients_.begin();
    qintptr fd = socket->socketDescriptor();
    if (fd == -1) {
        return 0;
    }
#if defined(Q_OS_LINUX)
    struct ucred credentials;
    socklen_t ucred_length = sizeof(struct ucred);
    if (getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &credentials, &ucred_length) == 0) {
        return credentials.pid;
    }
#elif defined(Q_OS_MACOS) || defined(Q_OS_MAC)
    #ifndef SOL_LOCAL
    #define SOL_LOCAL 0
    #endif
    #ifndef LOCAL_PEERPID
    #define LOCAL_PEERPID 0x002
    #endif
    pid_t client_pid = 0;
    socklen_t client_pid_len = sizeof(pid_t);
    if (getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &client_pid, &client_pid_len) == 0) {
        return client_pid;
    }
#endif
    return 0;
}

}  // namespace beenut
