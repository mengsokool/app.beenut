#include "service_state.h"

namespace beenut {

QJsonObject toJson(const Detection& detection)
{
    return {
        {"label", detection.label},
        {"confidence", detection.confidence},
        {"x", detection.x},
        {"y", detection.y},
        {"w", detection.w},
        {"h", detection.h},
    };
}

QJsonObject toJson(const ServiceState& state)
{
    QJsonArray detections;
    for (const auto& detection : state.detections) {
        detections.append(toJson(detection));
    }
    QJsonArray modelLabels;
    for (const auto& label : state.modelLabels) {
        modelLabels.append(label);
    }
    return {
        {"safeMode", state.safeMode},
        {"previewPaused", state.previewPaused},
        {"trayPresent", state.trayPresent},
        {"lightOn", state.lightOn},
        {"selectedPartType", state.selectedPartType},
        {"count", state.count},
        {"processingMs", state.processingMs},
        {"countTestRunning", state.countTestRunning},
        {"countTestSuccess", state.countTestSuccess},
        {"countTestMessage", state.countTestMessage},
        {"camera", state.camera},
        {"model", state.model},
        {"gpio", state.gpio},
        {"cameraDetail", state.cameraDetail},
        {"modelDetail", state.modelDetail},
        {"gpioDetail", state.gpioDetail},
        {"previewTransport", state.previewTransport},
        {"previewUrl", state.previewUrl},
        {"previewCaps", state.previewCaps},
        {"modelLabels", modelLabels},
        {"captureFps", state.captureFps},
        {"inferenceFps", state.inferenceFps},
        {"cpuUsage", state.cpuUsage},
        {"ramUsage", state.ramUsage},
        {"temperature", state.temperature},
        {"thermalState", state.thermalState},
        {"thermalDetail", state.thermalDetail},
        {"effectiveAiMaxFps", state.effectiveAiMaxFps},
        {"daemonCpu", state.daemonCpu},
        {"daemonRam", state.daemonRam},
        {"flutterCpu", state.flutterCpu},
        {"flutterRam", state.flutterRam},
        {"detections", detections},
    };
}

}  // namespace beenut
