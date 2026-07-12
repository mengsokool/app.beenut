#include "power_control.h"

#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QVector>

namespace beenut {
namespace {

bool runCommand(const QString& program, const QStringList& arguments, QString* detail)
{
    QProcess process;
    process.start(program, arguments);
    if (!process.waitForStarted(1000)) {
        if (detail != nullptr) {
            *detail = QString("%1: %2").arg(program, process.errorString());
        }
        return false;
    }
    if (!process.waitForFinished(3000)) {
        process.kill();
        process.waitForFinished(500);
        if (detail != nullptr) {
            *detail = QString("%1 timed out").arg(program);
        }
        return false;
    }
    const auto stderrText = QString::fromUtf8(process.readAllStandardError()).trimmed();
    if (process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0) {
        return true;
    }
    if (detail != nullptr) {
        *detail = QString("%1 exited with %2%3")
                      .arg(program)
                      .arg(process.exitCode())
                      .arg(stderrText.isEmpty() ? QString() : QString(": %1").arg(stderrText));
    }
    return false;
}

QString configuredPoweroffCommand(const QString& configOverride)
{
    return !configOverride.trimmed().isEmpty()
        ? configOverride.trimmed()
        : qEnvironmentVariable("BEENUT_POWEROFF_COMMAND").trimmed();
}

bool commandExists(const QString& command)
{
    const QFileInfo direct(command);
    return direct.isAbsolute()
        ? direct.exists() && direct.isExecutable()
        : !QStandardPaths::findExecutable(command).isEmpty();
}

QString sudoPath()
{
    if (QFileInfo::exists("/usr/bin/sudo")) {
        return "/usr/bin/sudo";
    }
    return QStandardPaths::findExecutable("sudo");
}

QVector<QPair<QString, QStringList>> poweroffCommands()
{
#ifdef Q_OS_LINUX
    return {
        {"/usr/bin/sudo", {"-n", "/usr/bin/systemctl", "poweroff"}},
        {"/usr/bin/sudo", {"-n", "/bin/systemctl", "poweroff"}},
        {"/usr/bin/sudo", {"-n", "/usr/sbin/poweroff"}},
        {"/usr/bin/sudo", {"-n", "/sbin/poweroff"}},
        {"/usr/bin/systemctl", {"poweroff"}},
        {"/bin/systemctl", {"poweroff"}},
    };
#elif defined(Q_OS_MACOS)
    return {
        {"/usr/bin/sudo", {"-n", "/sbin/shutdown", "-h", "now"}},
    };
#else
    return {};
#endif
}

}  // namespace

PoweroffCapability discoverPoweroffCapability(const QString& configOverride)
{
    const auto overrideCommand = configuredPoweroffCommand(configOverride);
    if (!overrideCommand.isEmpty()) {
        const auto parts = QProcess::splitCommand(overrideCommand);
        if (parts.isEmpty() || !commandExists(parts.first())) {
            return {.available = false, .detail = "Configured poweroff command is not executable"};
        }
        return {.available = true, .detail = "Configured poweroff command is available"};
    }

    const auto sudo = sudoPath();
    if (sudo.isEmpty()) {
        return {.available = false, .detail = "sudo is not installed"};
    }

    QString detail;
    if (runCommand(sudo, {"-n", "-l"}, &detail)) {
        return {.available = true, .detail = "Non-interactive poweroff permission is available"};
    }
    return {.available = false, .detail = "Non-interactive poweroff permission is unavailable: " + detail};
}

bool requestSystemPoweroff(const QString& configOverride, QString* detail)
{
    const auto overrideCommand = configuredPoweroffCommand(configOverride);
    if (!overrideCommand.isEmpty()) {
        const auto parts = QProcess::splitCommand(overrideCommand);
        if (parts.isEmpty()) {
            if (detail != nullptr) {
                *detail = "BEENUT_POWEROFF_COMMAND is empty after parsing";
            }
            return false;
        }
        QString commandDetail;
        if (runCommand(parts.first(), parts.mid(1), &commandDetail)) {
            if (detail != nullptr) {
                *detail = QString("override: %1").arg(overrideCommand);
            }
            return true;
        }
        if (detail != nullptr) {
            *detail = QString("override failed: %1").arg(commandDetail);
        }
        return false;
    }

    QStringList failures;
    for (const auto& command : poweroffCommands()) {
        QString commandDetail;
        if (runCommand(command.first, command.second, &commandDetail)) {
            if (detail != nullptr) {
                *detail = QString("%1 %2").arg(command.first, command.second.join(' '));
            }
            return true;
        }
        failures.append(commandDetail);
    }
    if (detail != nullptr) {
        *detail = failures.isEmpty() ? "System poweroff is unsupported on this platform" : failures.join(" | ");
    }
    return false;
}

}  // namespace beenut
