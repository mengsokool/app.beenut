import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/service_client.dart';
import '../../core/system_permissions.dart';
import '../../core/i18n.dart';
import '../../core/workbench_tokens.dart';
import 'count_panel.dart';
import 'part_selector.dart';
import 'preview_pane.dart';

class KioskPage extends StatefulWidget {
  const KioskPage({
    super.key,
    required this.snapshot,
    required this.client,
    required this.cameraPermission,
    required this.onOpenSettings,
  });

  final MachineSnapshot snapshot;
  final KioskServiceClient client;
  final CameraPermissionStatus cameraPermission;
  final VoidCallback onOpenSettings;

  @override
  State<KioskPage> createState() => _KioskPageState();
}

class _KioskPageState extends State<KioskPage> {
  bool _isSelectorOpen = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final state = widget.snapshot.state;
    final parts = widget.snapshot.config.partTypes
        .where((part) => part.enabled)
        .toList();
    final hasFault =
        !widget.snapshot.connected ||
        widget.cameraPermission.blocksCamera ||
        state.safeMode ||
        state.camera == 'error' ||
        state.camera == 'missing' ||
        state.model == 'error' ||
        state.model == 'missing';
    final statusColor = state.previewPaused
        ? tokens.muted
        : hasFault
        ? tokens.danger
        : state.countTestRunning
        ? tokens.info
        : state.trayPresent
        ? tokens.success
        : tokens.actionText;
    final title = widget.cameraPermission.blocksCamera
        ? I18n.t(context, 'camera_permission_denied')
        : state.previewPaused
        ? I18n.t(context, 'suspended')
        : hasFault
        ? I18n.t(context, 'machine_error')
        : (state.countTestRunning
              ? I18n.t(context, 'counting')
              : (state.trayPresent
                    ? I18n.t(context, 'counted')
                    : I18n.t(context, 'ready_to_count')));
    final subtitle = widget.cameraPermission.blocksCamera
        ? I18n.t(context, 'check_macos_permissions')
        : state.previewPaused
        ? I18n.t(context, 'paused')
        : hasFault
        ? I18n.t(context, 'diagnostic_mode')
        : I18n.t(context, 'items_unit');

    return Stack(
      children: [
        ColoredBox(
          color: tokens.canvas,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableRailWidth =
                  constraints.maxWidth -
                  constraints.maxHeight -
                  WorkbenchSpace.x3;
              final compact =
                  constraints.maxWidth < 760 ||
                  constraints.maxWidth <= constraints.maxHeight ||
                  availableRailWidth < 300;

              if (compact) {
                return _buildCompactLayout(
                  context: context,
                  parts: parts,
                  title: title,
                  subtitle: subtitle,
                  statusColor: statusColor,
                  constraints: constraints,
                );
              }
              return _buildWideLayout(
                context: context,
                parts: parts,
                title: title,
                subtitle: subtitle,
                statusColor: statusColor,
              );
            },
          ),
        ),

        IgnorePointer(
          ignoring: !_isSelectorOpen,
          child: AnimatedOpacity(
            opacity: _isSelectorOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout({
    required BuildContext context,
    required List<PartType> parts,
    required String title,
    required String subtitle,
    required Color statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(WorkbenchSpace.x3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final previewSize = constraints.maxHeight;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox.square(
                key: const ValueKey('kiosk-preview'),
                dimension: previewSize,
                child: _previewPane(),
              ),
              const SizedBox(width: WorkbenchSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _partSelector(parts),
                    const SizedBox(height: WorkbenchSpace.x3),
                    Expanded(child: _countPanel(title, subtitle, statusColor)),
                    const SizedBox(height: WorkbenchSpace.x3),
                    _footerButtons(context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactLayout({
    required BuildContext context,
    required List<PartType> parts,
    required String title,
    required String subtitle,
    required Color statusColor,
    required BoxConstraints constraints,
  }) {
    final countHeight = (constraints.maxHeight * 0.22).clamp(120.0, 180.0);

    return Padding(
      padding: const EdgeInsets.all(WorkbenchSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                key: const ValueKey('kiosk-preview'),
                aspectRatio: 1,
                child: _previewPane(),
              ),
            ),
          ),
          const SizedBox(height: WorkbenchSpace.x3),
          _partSelector(parts),
          const SizedBox(height: WorkbenchSpace.x2),
          SizedBox(
            height: countHeight,
            child: _countPanel(title, subtitle, statusColor),
          ),
          const SizedBox(height: WorkbenchSpace.x2),
          _footerButtons(context),
        ],
      ),
    );
  }

  Widget _previewPane() {
    final state = widget.snapshot.state;
    return NativePreviewPane(
      state: state,
      connected: widget.snapshot.connected,
      previewSocket: widget.snapshot.config.previewSocket,
      aspectRatio: 1.0,
    );
  }

  Widget _partSelector(List<PartType> parts) {
    return PartSelector(
      parts: parts,
      selectedId: widget.snapshot.state.selectedPartType,
      onSelected: widget.client.selectPartType,
      onMenuStateChanged: (isOpen) {
        setState(() {
          _isSelectorOpen = isOpen;
        });
      },
    );
  }

  Widget _countPanel(String title, String subtitle, Color statusColor) {
    final state = widget.snapshot.state;
    final hasFault =
        !widget.snapshot.connected ||
        widget.cameraPermission.blocksCamera ||
        state.safeMode ||
        state.camera == 'error' ||
        state.camera == 'missing' ||
        state.model == 'error' ||
        state.model == 'missing';
    final isMuted = state.previewPaused || hasFault;

    return CountPanel(
      count: state.count,
      color: statusColor,
      title: title,
      subtitle: subtitle,
      isLoading: state.countTestRunning,
      isMuted: isMuted,
    );
  }

  Widget _footerButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _settingsButton()),
        const SizedBox(width: WorkbenchSpace.x2),
        Expanded(child: _pauseButton(context)),
      ],
    );
  }

  Widget _settingsButton() {
    final label = I18n.t(context, 'settings_title');
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          key: const ValueKey('kiosk-settings-action'),
          height: WorkbenchMetric.operatorControlHeight,
          child: OutlinedButton.icon(
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _pauseButton(BuildContext context) {
    final tokens = context.workbenchColors;
    final paused = widget.snapshot.state.previewPaused;
    final label = paused
        ? I18n.t(context, 'resume_preview')
        : I18n.t(context, 'pause_preview');
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          key: const ValueKey('kiosk-pause-action'),
          height: WorkbenchMetric.operatorControlHeight,
          child: paused
              ? FilledButton.icon(
                  onPressed: () => widget.client.setPreviewPaused(false),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(label),
                )
              : OutlinedButton.icon(
                  onPressed: () => widget.client.setPreviewPaused(true),
                  icon: const Icon(Icons.pause, size: 18),
                  label: Text(label),
                  style: OutlinedButton.styleFrom(foregroundColor: tokens.ink),
                ),
        ),
      ),
    );
  }
}
