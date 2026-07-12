import 'package:flutter/material.dart';
import '../../../core/models.dart';
import '../../../core/i18n.dart';
import '../../../core/system_permissions.dart';
import '../../common/widgets.dart';
import '../widgets/resource_chart.dart';

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
  });

  final MachineConfig config;
  final MachineSnapshot snapshot;
  final CameraPermissionStatus cameraPermission;
  final Future<void> Function() onRefreshCameraPermission;
  final VoidCallback onRefreshCapabilities;
  final ValueChanged<MachineConfig> onSave;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = snapshot.state;
    final capabilities = snapshot.capabilities;
    final validation = snapshot.validation;
    final saveResult = snapshot.saveResult;
    final gpio = capabilities.gpio;
    final validationValue = validation.ok
        ? (validation.warnings.isEmpty
              ? 'ready'
              : '${validation.warnings.length} warnings')
        : '${validation.errors.length} errors';
    final thermalTone = switch (state.thermalState) {
      'critical' => RowTone.danger,
      'throttled' || 'warning' => RowTone.warning,
      'normal' => RowTone.success,
      _ => RowTone.neutral,
    };
    final thermalColor = switch (thermalTone) {
      RowTone.danger => scheme.error,
      RowTone.warning => scheme.secondary,
      RowTone.success => scheme.tertiary,
      _ => scheme.onSurfaceVariant,
    };
    final validationDescription = [
      ...validation.errors,
      ...validation.warnings,
    ].take(3).join(' · ');
    final ui = config.uiSettings;
    final uiScalePercent = (ui.scale * 100).round();

    return Column(
      children: [
        SettingsGroup(
          title: I18n.t(context, 'system_health'),
          icon: Icons.health_and_safety_outlined,
          children: [
            IconInfoRow(
              icon: Icons.power_outlined,
              iconColor: snapshot.connected ? scheme.tertiary : scheme.error,
              label: 'Service',
              value: snapshot.connected ? 'connected' : 'offline',
              tone: snapshot.connected ? RowTone.success : RowTone.danger,
            ),
            IconInfoRow(
              icon: Icons.camera_alt_outlined,
              iconColor: cameraPermission.blocksCamera
                  ? scheme.error
                  : scheme.primary,
              label: 'Camera',
              description: cameraPermission.blocksCamera
                  ? cameraPermission.message
                  : state.cameraDetail,
              value: cameraPermission.blocksCamera
                  ? cameraPermission.label
                  : '${state.camera} · ${state.captureFps.toStringAsFixed(1)} fps',
              tone: cameraPermission.blocksCamera
                  ? RowTone.danger
                  : RowTone.neutral,
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
                    label: 'Open Settings',
                    primary: true,
                    onPressed: SystemPermissions.openCameraPrivacySettings,
                  ),
                  RowAction(
                    label: 'Check Again',
                    onPressed: onRefreshCameraPermission,
                  ),
                ],
              ),
            if (cameraPermission == CameraPermissionStatus.notDetermined ||
                cameraPermission == CameraPermissionStatus.unknown)
              ActionSettingRow(
                icon: Icons.video_camera_front_outlined,
                iconColor: scheme.primary,
                label: 'Camera Permission',
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
            IconInfoRow(
              icon: Icons.psychology_outlined,
              iconColor: scheme.tertiary,
              label: 'Model',
              description: state.modelDetail,
              value:
                  '${state.model} · ${state.inferenceFps.toStringAsFixed(1)} fps',
            ),
            IconInfoRow(
              icon: validation.ok
                  ? Icons.check_box_outlined
                  : Icons.error_outline,
              iconColor: validation.ok
                  ? (validation.warnings.isEmpty
                        ? scheme.tertiary
                        : scheme.secondary)
                  : scheme.error,
              label: 'Config Validation',
              description: validationDescription.isEmpty
                  ? 'Backend accepted the current hardware and runtime settings'
                  : validationDescription,
              value: validationValue,
              tone: validation.ok
                  ? (validation.warnings.isEmpty
                        ? RowTone.success
                        : RowTone.warning)
                  : RowTone.danger,
            ),
            if (saveResult.hasData)
              IconInfoRow(
                icon: saveResult.ok
                    ? Icons.save_outlined
                    : Icons.report_problem_outlined,
                iconColor: saveResult.ok ? scheme.tertiary : scheme.error,
                label: 'Config Save',
                description: saveResult.detail,
                value: saveResult.message,
                tone: saveResult.ok ? RowTone.success : RowTone.danger,
              ),
          ],
        ),
        SettingsGroup(
          title: I18n.t(context, 'display_settings'),
          icon: Icons.display_settings_outlined,
          children: [
            StepperSettingRow(
              label: I18n.t(context, 'ui_scale'),
              description: I18n.t(context, 'ui_scale_desc'),
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
              description: I18n.t(context, 'app_language_desc'),
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
              description: I18n.t(context, 'theme_mode_desc'),
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
        SettingsGroup(
          title: I18n.t(context, 'device_state'),
          description: I18n.t(context, 'device_state_desc'),
          icon: Icons.monitor_heart_outlined,
          collapsible: true,
          initiallyExpanded: false,
          children: [
            IconInfoRow(
              icon: Icons.sensors_outlined,
              iconColor: scheme.primary,
              label: 'Tray Sensor',
              value: state.trayPresent ? 'Present' : 'Missing',
              tone: state.trayPresent ? RowTone.success : RowTone.neutral,
            ),
            IconInfoRow(
              icon: Icons.lightbulb_outline,
              iconColor: scheme.secondary,
              label: 'LED Relay',
              value: state.lightOn ? 'ON' : 'OFF',
              tone: state.lightOn ? RowTone.warning : RowTone.neutral,
            ),
            IconInfoRow(
              icon: Icons.verified_outlined,
              iconColor: scheme.tertiary,
              label: 'Last Detection Count',
              value: '${state.count} pcs',
            ),
            IconInfoRow(
              icon: Icons.memory_outlined,
              iconColor: scheme.primary,
              label: 'Inference Latency',
              value: '${state.processingMs} ms',
            ),
            IconInfoRow(
              icon: Icons.device_thermostat_outlined,
              iconColor: thermalColor,
              label: 'Thermal Policy',
              description: state.thermalDetail,
              value:
                  '${state.thermalState} · ${state.temperature.toStringAsFixed(1)} C · ${state.effectiveAiMaxFps.toStringAsFixed(1)} fps',
              tone: thermalTone,
            ),
          ],
        ),
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
              label: 'Hardware Inventory',
              description: capabilities.hasData
                  ? '${capabilities.cameras.length} cameras · ${capabilities.aiRuntimes.length} AI runtimes · GPIO ${gpio['backend'] ?? 'unknown'}'
                  : I18n.t(context, 'no_hw_diagnostics'),
              actions: [
                RowAction(
                  label: 'Scan',
                  primary: true,
                  onPressed: snapshot.connected ? onRefreshCapabilities : null,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
