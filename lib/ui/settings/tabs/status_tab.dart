import 'package:flutter/material.dart';
import '../../../core/models.dart';
import '../../../core/i18n.dart';
import '../../../core/system_permissions.dart';
import '../../../core/workbench_tokens.dart';
import '../../common/widgets.dart';
import '../widgets/resource_chart.dart';

enum StatusSettingsSection { overview, interface, service }

class StatusSettingsTab extends StatelessWidget {
  const StatusSettingsTab({
    super.key,
    required this.config,
    required this.snapshot,
    required this.cameraPermission,
    required this.onRefreshCameraPermission,
    required this.onRefreshCapabilities,
    required this.onSave,
    required this.enabled,
    this.section = StatusSettingsSection.overview,
  });

  final MachineConfig config;
  final MachineSnapshot snapshot;
  final CameraPermissionStatus cameraPermission;
  final Future<void> Function() onRefreshCameraPermission;
  final VoidCallback onRefreshCapabilities;
  final ValueChanged<MachineConfig> onSave;
  final bool enabled;
  final StatusSettingsSection section;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.workbenchColors;
    final state = snapshot.state;
    final capabilities = snapshot.capabilities;
    final validation = snapshot.validation;
    final gpio = capabilities.gpio;
    final camera = config.cameraSettings;
    final model = config.modelSettings;
    final cameraSourceName = _cameraSourceDisplayName(
      context,
      camera,
      capabilities.cameras,
    );
    final cameraTone = cameraPermission.blocksCamera
        ? RowTone.danger
        : _runtimeTone(state.camera);
    final modelTone = _runtimeTone(state.model);
    final validationTone = validation.ok
        ? (validation.warnings.isEmpty ? RowTone.success : RowTone.warning)
        : RowTone.danger;
    final validationStatus = validation.ok
        ? (validation.warnings.isEmpty
              ? I18n.t(context, 'config_valid')
              : I18n.t(
                  context,
                  'config_warning_count',
                  args: {'count': '${validation.warnings.length}'},
                ))
        : I18n.t(
            context,
            'config_error_count',
            args: {'count': '${validation.errors.length}'},
          );
    final cameraDetails = <SystemStatusDetail>[
      if (camera.device.trim().isNotEmpty && cameraSourceName != camera.device)
        SystemStatusDetail(
          label: I18n.t(context, 'detail_camera_device_id'),
          value: camera.device,
          monospace: true,
        ),
      if (cameraPermission.blocksCamera)
        SystemStatusDetail(
          label: I18n.t(context, 'camera_status'),
          value: cameraPermission.message,
        )
      else if (state.cameraDetail.trim().isNotEmpty)
        SystemStatusDetail(
          label: I18n.t(context, 'detail_camera_pipeline'),
          value: state.cameraDetail,
          monospace: true,
        ),
    ];
    final modelPath = model.engine == 'hailo' ? model.hefPath : model.modelPath;
    final modelDetails = <SystemStatusDetail>[
      if (modelPath.trim().isNotEmpty)
        SystemStatusDetail(
          label: I18n.t(context, 'detail_model_path'),
          value: modelPath,
          monospace: true,
        ),
      if (state.modelDetail.trim().isNotEmpty)
        SystemStatusDetail(
          label: I18n.t(context, 'detail_runtime_report'),
          value: state.modelDetail,
        ),
    ];
    final validationDetails = <SystemStatusDetail>[
      for (final error in validation.errors)
        SystemStatusDetail(
          label: I18n.t(context, 'detail_validation_error'),
          value: error,
        ),
      for (final warning in validation.warnings)
        SystemStatusDetail(
          label: I18n.t(context, 'detail_validation_warning'),
          value: warning,
        ),
    ];
    final thermalTone = switch (state.thermalState) {
      'critical' => RowTone.danger,
      'throttled' || 'warning' => RowTone.warning,
      'normal' => RowTone.success,
      _ => RowTone.neutral,
    };
    final thermalColor = switch (thermalTone) {
      RowTone.danger => tokens.danger,
      RowTone.warning => tokens.warning,
      RowTone.success => tokens.success,
      _ => tokens.muted,
    };
    final ui = config.uiSettings;
    final uiScalePercent = (ui.scale * 100).round();

    return Column(
      children: [
        if (section == StatusSettingsSection.overview)
          SettingsGroup(
            title: I18n.t(context, 'system_health'),
            children: [
              SystemStatusRow(
                key: const ValueKey('service-status'),
                icon: Icons.power_outlined,
                iconColor: snapshot.connected ? tokens.success : tokens.danger,
                label: I18n.t(context, 'service_status'),
                status: snapshot.connected
                    ? I18n.t(context, 'status_connected')
                    : I18n.t(context, 'status_offline'),
                tone: snapshot.connected ? RowTone.success : RowTone.danger,
              ),
              SystemStatusRow(
                key: const ValueKey('camera-status'),
                icon: Icons.camera_alt_outlined,
                iconColor: _toneColor(tokens, cameraTone),
                label: I18n.t(context, 'camera_status'),
                status: cameraPermission.blocksCamera
                    ? I18n.t(context, 'status_permission_required')
                    : _runtimeStatusLabel(context, state.camera),
                tone: cameraTone,
                metrics: [
                  SystemStatusMetric(
                    label: I18n.t(context, 'metric_source'),
                    value: cameraSourceName,
                  ),
                  SystemStatusMetric(
                    label: I18n.t(context, 'metric_resolution'),
                    value: '${camera.width} × ${camera.height}',
                    monospace: true,
                  ),
                  SystemStatusMetric(
                    label: I18n.t(context, 'metric_capture_rate'),
                    value: '${state.captureFps.toStringAsFixed(1)} fps',
                    monospace: true,
                  ),
                ],
                details: cameraDetails,
                showDetailsLabel: I18n.t(context, 'show_technical_details'),
                hideDetailsLabel: I18n.t(context, 'hide_technical_details'),
              ),
              if (cameraPermission.blocksCamera)
                ActionSettingRow(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: scheme.error,
                  label: 'macOS Camera Privacy',
                  description: cameraPermission == CameraPermissionStatus.denied
                      ? 'Enable BeeNut in Privacy & Security > Camera, then check again.'
                      : cameraPermission.message,
                  actions: [
                    RowAction(
                      label: 'Open settings',
                      primary: true,
                      onPressed: SystemPermissions.openCameraPrivacySettings,
                    ),
                    RowAction(
                      label: 'Check again',
                      onPressed: onRefreshCameraPermission,
                    ),
                  ],
                ),
              if (cameraPermission == CameraPermissionStatus.notDetermined ||
                  cameraPermission == CameraPermissionStatus.unknown)
                ActionSettingRow(
                  icon: Icons.video_camera_front_outlined,
                  iconColor: scheme.primary,
                  label: 'Camera permission',
                  description:
                      'Request camera access before starting the live preview.',
                  actions: [
                    RowAction(
                      label: 'Request',
                      primary: true,
                      onPressed: onRefreshCameraPermission,
                    ),
                  ],
                ),
              SystemStatusRow(
                key: const ValueKey('model-status'),
                icon: Icons.psychology_outlined,
                iconColor: _toneColor(tokens, modelTone),
                label: I18n.t(context, 'model_status'),
                status: _runtimeStatusLabel(context, state.model),
                tone: modelTone,
                metrics: [
                  SystemStatusMetric(
                    label: I18n.t(context, 'metric_model'),
                    value: _fileName(modelPath),
                    monospace: true,
                  ),
                  SystemStatusMetric(
                    label: I18n.t(context, 'metric_classes'),
                    value: '${state.modelLabels.length}',
                    monospace: true,
                  ),
                  SystemStatusMetric(
                    label: I18n.t(context, 'metric_inference_rate'),
                    value: '${state.inferenceFps.toStringAsFixed(1)} fps',
                    monospace: true,
                  ),
                  SystemStatusMetric(
                    label: I18n.t(context, 'metric_runtime'),
                    value: model.engine.toUpperCase(),
                  ),
                ],
                details: modelDetails,
                showDetailsLabel: I18n.t(context, 'show_technical_details'),
                hideDetailsLabel: I18n.t(context, 'hide_technical_details'),
              ),
              SystemStatusRow(
                key: const ValueKey('configuration-status'),
                icon: validation.ok
                    ? Icons.check_box_outlined
                    : Icons.error_outline,
                iconColor: _toneColor(tokens, validationTone),
                label: I18n.t(context, 'config_validation_status'),
                status: validationStatus,
                tone: validationTone,
                metrics: [
                  SystemStatusMetric(
                    label: I18n.t(context, 'metric_result'),
                    value: validation.errors.isEmpty
                        ? I18n.t(context, 'config_no_issues')
                        : validationStatus,
                  ),
                ],
                details: validationDetails,
                showDetailsLabel: I18n.t(context, 'show_technical_details'),
                hideDetailsLabel: I18n.t(context, 'hide_technical_details'),
              ),
            ],
          ),
        if (section == StatusSettingsSection.interface)
          SettingsGroup(
            title: I18n.t(context, 'display_settings'),
            icon: Icons.display_settings_outlined,
            children: [
              StepperSettingRow(
                label: I18n.t(context, 'ui_scale'),
                description: '',
                value: uiScalePercent,
                unit: '%',
                min: 50,
                max: 200,
                step: 5,
                enabled: enabled,
                onChanged: (value) => onSave(
                  config.copyWithUiSettings(ui.copyWith(scale: value / 100)),
                ),
              ),
              SelectSettingRow(
                label: I18n.t(context, 'app_language'),
                description: '',
                value: ui.language == 'th' ? 'ไทย' : 'English',
                options: const ['English', 'ไทย'],
                enabled: enabled,
                onSelected: (value) => onSave(
                  config.copyWithUiSettings(
                    ui.copyWith(language: value == 'ไทย' ? 'th' : 'en'),
                  ),
                ),
              ),
              SelectSettingRow(
                label: I18n.t(context, 'theme_mode'),
                description: '',
                value: ui.theme == 'light'
                    ? I18n.t(context, 'theme_light')
                    : (ui.theme == 'dark'
                          ? I18n.t(context, 'theme_dark')
                          : I18n.t(context, 'theme_system')),
                options: [
                  I18n.t(context, 'theme_system'),
                  I18n.t(context, 'theme_light'),
                  I18n.t(context, 'theme_dark'),
                ],
                enabled: enabled,
                onSelected: (value) {
                  String mode = 'system';
                  if (value == I18n.t(context, 'theme_light')) {
                    mode = 'light';
                  } else if (value == I18n.t(context, 'theme_dark')) {
                    mode = 'dark';
                  }
                  onSave(config.copyWithUiSettings(ui.copyWith(theme: mode)));
                },
              ),
            ],
          ),
        if (section == StatusSettingsSection.overview)
          SettingsGroup(
            title: I18n.t(context, 'device_state'),
            summary: _deviceStateSummary(context, state),
            collapsible: true,
            initiallyExpanded: false,
            children: [
              IconInfoRow(
                icon: Icons.sensors_outlined,
                iconColor: tokens.actionText,
                label: I18n.t(context, 'tray_sensor'),
                value: state.trayPresent
                    ? I18n.t(context, 'tray_present')
                    : I18n.t(context, 'tray_missing'),
                tone: state.trayPresent ? RowTone.success : RowTone.neutral,
              ),
              IconInfoRow(
                icon: Icons.lightbulb_outline,
                iconColor: tokens.warning,
                label: I18n.t(context, 'led_relay'),
                value: state.lightOn
                    ? I18n.t(context, 'relay_active')
                    : I18n.t(context, 'relay_idle'),
                tone: state.lightOn ? RowTone.warning : RowTone.neutral,
              ),
              IconInfoRow(
                icon: Icons.verified_outlined,
                iconColor: tokens.success,
                label: I18n.t(context, 'last_detection_count'),
                value: '${state.count} ${I18n.t(context, 'items_unit')}',
              ),
              IconInfoRow(
                icon: Icons.memory_outlined,
                iconColor: tokens.info,
                label: I18n.t(context, 'inference_latency'),
                value: '${state.processingMs} ms',
              ),
              IconInfoRow(
                icon: Icons.device_thermostat_outlined,
                iconColor: thermalColor,
                label: I18n.t(context, 'thermal_policy'),
                description: state.thermalDetail,
                value:
                    '${state.thermalState} · ${state.temperature.toStringAsFixed(1)} C · ${state.effectiveAiMaxFps.toStringAsFixed(1)} fps',
                tone: thermalTone,
              ),
            ],
          ),
        if (section == StatusSettingsSection.service)
          SettingsGroup(
            title: I18n.t(context, 'performance_history'),
            description: I18n.t(context, 'performance_history_desc'),
            icon: Icons.query_stats_outlined,
            collapsible: true,
            initiallyExpanded: false,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 360,
                  child: ResourceHistoryChart(
                    daemonCpu: state.daemonCpu,
                    daemonRam: state.daemonRam,
                    flutterCpu: state.flutterCpu,
                    flutterRam: state.flutterRam,
                  ),
                ),
              ),
            ],
          ),
        if (section == StatusSettingsSection.service)
          SettingsGroup(
            title: I18n.t(context, 'technical_details'),
            description: I18n.t(context, 'technical_details_desc'),
            icon: Icons.tune_outlined,
            collapsible: true,
            initiallyExpanded: false,
            children: [
              IconInfoRow(
                icon: Icons.cable_outlined,
                iconColor: scheme.onSurfaceVariant,
                label: 'Preview',
                description: state.previewCaps,
                value: state.previewTransport,
              ),
              ActionSettingRow(
                icon: Icons.manage_search_outlined,
                iconColor: scheme.primary,
                label: 'Hardware inventory',
                description: capabilities.hasData
                    ? '${capabilities.cameras.length} cameras · ${capabilities.aiRuntimes.length} AI runtimes · GPIO ${gpio['backend'] ?? 'unknown'}'
                    : I18n.t(context, 'no_hw_diagnostics'),
                actions: [
                  RowAction(
                    label: 'Scan',
                    primary: true,
                    onPressed: snapshot.connected
                        ? onRefreshCapabilities
                        : null,
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

RowTone _runtimeTone(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'ready' ||
      normalized == 'running' ||
      normalized == 'connected' ||
      normalized == 'ok') {
    return RowTone.success;
  }
  if (normalized.contains('warning') ||
      normalized.contains('throttled') ||
      normalized.contains('degraded')) {
    return RowTone.warning;
  }
  if (normalized.contains('error') ||
      normalized.contains('fail') ||
      normalized.contains('missing') ||
      normalized.contains('offline') ||
      normalized.contains('unavailable')) {
    return RowTone.danger;
  }
  return RowTone.neutral;
}

Color _toneColor(WorkbenchColors tokens, RowTone tone) => switch (tone) {
  RowTone.success => tokens.success,
  RowTone.warning => tokens.warning,
  RowTone.danger => tokens.danger,
  RowTone.neutral => tokens.muted,
};

String _deviceStateSummary(BuildContext context, MachineState state) {
  final tray = state.trayPresent
      ? I18n.t(context, 'tray_summary_present')
      : I18n.t(context, 'tray_summary_missing');
  final relay = state.lightOn
      ? I18n.t(context, 'relay_summary_active')
      : I18n.t(context, 'relay_summary_idle');
  return '$tray · $relay · ${state.temperature.toStringAsFixed(1)} °C';
}

String _runtimeStatusLabel(BuildContext context, String value) {
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'ready' || 'running' || 'ok' => I18n.t(context, 'status_ready'),
    'connected' => I18n.t(context, 'status_connected'),
    'offline' || 'disconnected' => I18n.t(context, 'status_offline'),
    'missing' || 'unavailable' => I18n.t(context, 'status_missing'),
    'error' || 'failed' => I18n.t(context, 'status_error'),
    _ => value.trim().isEmpty ? '—' : value,
  };
}

String _fileName(String path) {
  final normalized = path.trim();
  if (normalized.isEmpty) return '—';
  return normalized.split(RegExp(r'[/\\]')).last;
}

String _cameraSourceDisplayName(
  BuildContext context,
  CameraSettings camera,
  List<Map<String, dynamic>> discoveredCameras,
) {
  final source = camera.source.trim();
  final device = camera.device.trim();

  for (final candidate in discoveredCameras) {
    final candidateSource = '${candidate['source'] ?? ''}'.trim();
    final candidateDevice = '${candidate['device'] ?? ''}'.trim();
    if (candidateDevice == device &&
        (source.isEmpty || candidateSource == source)) {
      final name = '${candidate['name'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    }
  }

  if (source == 'auto' || (source.isEmpty && device.isEmpty)) {
    return I18n.t(context, 'auto_detect');
  }
  if (source == 'avfoundation') {
    return I18n.t(context, 'camera_source_macos');
  }
  if (source == 'mock') {
    return I18n.t(context, 'camera_source_test_pattern');
  }
  if (device.isNotEmpty) return device;
  return source;
}
