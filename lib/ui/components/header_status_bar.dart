import 'package:flutter/material.dart';
import '../../core/dls_tokens.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';
import 'kiosk_form_controls.dart';

enum DaemonConnectionState { connected, connecting, disconnected }
enum HardwareHealthState { optimal, warning, fault }

/// Reusable touchscreen header status bar component.
/// Displays daemon connection status, camera status, model load status,
/// hardware temperature indicator, theme mode toggle button, and settings button.
class KioskHeaderStatusBar extends StatelessWidget {
  const KioskHeaderStatusBar({
    super.key,
    required this.connectionState,
    required this.cameraStatusText,
    required this.activeModelName,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
    this.onOpenSettings,
    this.hardwareTemperature,
    this.hardwareHealthState = HardwareHealthState.optimal,
    this.height = 64.0,
  });

  /// Helper constructor from MachineSnapshot
  factory KioskHeaderStatusBar.fromSnapshot({
    Key? key,
    required MachineSnapshot snapshot,
    required AppThemeMode currentThemeMode,
    required ValueChanged<AppThemeMode> onThemeModeChanged,
    VoidCallback? onOpenSettings,
    double height = 64.0,
  }) {
    final state = snapshot.state;
    final model = snapshot.config.modelSettings;
    final isModelUnconfigured =
        model.modelPath.trim().isEmpty && model.hefPath.trim().isEmpty;

    final connState = !snapshot.connected
        ? DaemonConnectionState.disconnected
        : DaemonConnectionState.connected;

    final camText = state.camera == 'ok'
        ? 'Camera Ready'
        : (state.camera == 'error' ? 'Camera Error' : 'No Camera');

    final modelText = isModelUnconfigured
        ? 'No Model'
        : (state.model == 'ok'
            ? (model.modelPath.split('/').last.isNotEmpty
                ? model.modelPath.split('/').last
                : 'Model Loaded')
            : 'Model Error');

    final temp = state.temperature;
    final health = (temp > 80.0)
        ? HardwareHealthState.fault
        : ((temp > 70.0)
            ? HardwareHealthState.warning
            : HardwareHealthState.optimal);

    return KioskHeaderStatusBar(
      key: key,
      connectionState: connState,
      cameraStatusText: camText,
      activeModelName: modelText,
      currentThemeMode: currentThemeMode,
      onThemeModeChanged: onThemeModeChanged,
      onOpenSettings: onOpenSettings,
      hardwareTemperature: temp,
      hardwareHealthState: health,
      height: height,
    );
  }

  final DaemonConnectionState connectionState;
  final String cameraStatusText;
  final String activeModelName;
  final AppThemeMode currentThemeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final VoidCallback? onOpenSettings;
  final double? hardwareTemperature;
  final HardwareHealthState hardwareHealthState;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;
    final shadows = context.dlsShadows;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radii.borderMd(),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: shadows.softSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Connection status badge
                  _buildConnectionBadge(context),
                  SizedBox(width: spacing.md),

                  // 2. Camera status badge
                  _buildStatusBadge(
                    context,
                    icon: Icons.videocam_outlined,
                    label: cameraStatusText,
                    color: cameraStatusText.contains('Ready') || cameraStatusText.contains('OK')
                        ? colors.success
                        : colors.danger,
                  ),
                  SizedBox(width: spacing.md),

                  // 3. Active Model badge
                  _buildStatusBadge(
                    context,
                    icon: Icons.memory_outlined,
                    label: activeModelName,
                    color: activeModelName == 'No Model' || activeModelName.contains('Error')
                        ? colors.warning
                        : colors.info,
                  ),

                  // 4. Hardware temperature tracking badge (if available)
                  if (hardwareTemperature != null) ...[
                    SizedBox(width: spacing.md),
                    _buildStatusBadge(
                      context,
                      icon: Icons.thermostat_outlined,
                      label: '${hardwareTemperature!.toStringAsFixed(1)}°C',
                      color: switch (hardwareHealthState) {
                        HardwareHealthState.optimal => colors.success,
                        HardwareHealthState.warning => colors.warning,
                        HardwareHealthState.fault => colors.danger,
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: spacing.md),

          // 5. Theme Mode Toggle Popup/Button (Min 48x48dp touch target)
          _buildThemeToggle(context),

          // 6. Settings gear button (Min 48x48dp touch target)
          if (onOpenSettings != null) ...[
            SizedBox(width: spacing.sm),
            SizedBox(
              width: 48.0,
              height: 48.0,
              child: KioskTouchScale(
                onTap: onOpenSettings,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: radii.borderSm(),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 22,
                    color: colors.inkPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(BuildContext context) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;

    final color = switch (connectionState) {
      DaemonConnectionState.connected => colors.success,
      DaemonConnectionState.connecting => colors.warning,
      DaemonConnectionState.disconnected => colors.danger,
    };
    final label = switch (connectionState) {
      DaemonConnectionState.connected => 'ONLINE',
      DaemonConnectionState.connecting => 'CONNECTING',
      DaemonConnectionState.disconnected => 'OFFLINE',
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: radii.borderPill(),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: spacing.sm),
          Text(
            label,
            style: DlsTypography.captionKiosk(color: color).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: radii.borderPill(),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: spacing.xs + 2),
          Flexible(
            child: Text(
              label,
              style: DlsTypography.captionKiosk(color: colors.inkPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final colors = context.dlsColors;
    final radii = context.dlsRadii;
    final spacing = context.dlsSpacing;

    final themeIcon = switch (currentThemeMode) {
      AppThemeMode.light => Icons.wb_sunny_outlined,
      AppThemeMode.dark => Icons.nightlight_round,
      AppThemeMode.kioskHighContrast => Icons.contrast_rounded,
    };

    return PopupMenuButton<AppThemeMode>(
      initialValue: currentThemeMode,
      onSelected: onThemeModeChanged,
      tooltip: 'Switch Theme Mode',
      shape: RoundedRectangleBorder(
        borderRadius: radii.borderSm(),
        side: BorderSide(color: colors.border),
      ),
      color: colors.surface,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: AppThemeMode.light,
          child: Row(
            children: [
              Icon(Icons.wb_sunny_outlined, size: 18, color: colors.accent),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  'Light Warm Mode',
                  style: DlsTypography.bodyKiosk(color: colors.inkPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: AppThemeMode.dark,
          child: Row(
            children: [
              Icon(Icons.nightlight_round, size: 18, color: colors.accent),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  'Dark Obsidian Mode',
                  style: DlsTypography.bodyKiosk(color: colors.inkPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: AppThemeMode.kioskHighContrast,
          child: Row(
            children: [
              Icon(Icons.contrast_rounded, size: 18, color: colors.accent),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  'Kiosk High Contrast',
                  style: DlsTypography.bodyKiosk(color: colors.inkPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 48.0,
        height: 48.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: radii.borderSm(),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Icon(
          themeIcon,
          size: 22,
          color: colors.accent,
        ),
      ),
    );
  }
}
