#include "app_runtime.h"

#include <QCommandLineParser>
#include <QCoreApplication>

#include <gst/gst.h>

int main(int argc, char* argv[])
{
    gst_init(&argc, &argv);

    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName("beenutd");
    QCoreApplication::setApplicationVersion("0.1.0");

    beenut::UnixSignalHandler signalHandler(app);

    QCommandLineParser parser;
    parser.addHelpOption();
    parser.addOption({{"c", "config"}, "Config JSON path.", "path", "service/config/default.json"});
    parser.addOption({{"m", "mode"}, "Runtime mode: auto, mock, or hardware.", "mode", "auto"});
    parser.process(app);

    const auto configPath = parser.value("config");
    const auto runtimeMode = parser.value("mode").toLower();

    beenut::AppRuntime runtime(configPath, runtimeMode);
    if (!runtime.start()) {
        return 1;
    }

    return QCoreApplication::exec();
}
