import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/service_client.dart';
import '../../core/system_permissions.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final state = widget.snapshot.state;
    final parts = widget.snapshot.config.partTypes
        .where((part) => part.enabled)
        .toList();
    final selected =
        parts.where((part) => part.id == state.selectedPartType).firstOrNull ??
        parts.firstOrNull;
    final hasFault =
        !widget.snapshot.connected ||
        widget.cameraPermission.blocksCamera ||
        state.safeMode ||
        state.camera == 'error' ||
        state.camera == 'missing' ||
        state.model == 'error' ||
        state.model == 'missing';
    final statusColor = state.previewPaused
        ? scheme.onSurfaceVariant
        : hasFault
        ? scheme.error
        : state.trayPresent
        ? scheme.tertiary
        : scheme.primary;
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
        : (state.trayPresent
              ? I18n.t(context, 'items_unit')
              : selected?.name ?? '');

    return Stack(
      children: [
        ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              final rightColumnWidth =
                  constraints.maxWidth - constraints.maxHeight - 16;
              final compact =
                  !isLandscape ||
                  rightColumnWidth < 180 ||
                  constraints.maxHeight < 200;

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
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 1.0, child: _previewPane()),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _partSelector(parts),
                const SizedBox(height: 14),
                Expanded(child: _countPanel(title, subtitle, statusColor)),
                const SizedBox(height: 14),
                _footerButtons(context),
              ],
            ),
          ),
        ],
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
    // Adaptive layout: Calculate maximum available height for the preview pane
    // to prevent vertical overflow on short screens while guaranteeing w-full on tall screens.
    // Total non-preview elements height ~ 300px (padding, margins, selector, counter, buttons)
    final maxPreviewWidth = constraints.maxWidth - 32;
    final maxPreviewHeight = constraints.maxHeight - 300;
    final previewSize = maxPreviewWidth.clamp(
      0.0,
      maxPreviewHeight > 0 ? maxPreviewHeight : 0.0,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Preview Pane at the top
          Center(
            child: SizedBox(
              width: previewSize,
              height: previewSize,
              child: _previewPane(),
            ),
          ),
          // 2. Counter centered vertically in the remaining space
          Expanded(
            child: Center(
              child: SizedBox(
                width: double.infinity,
                height: 120,
                child: _countPanel(title, subtitle, statusColor),
              ),
            ),
          ),
          // 3. Selector and ButtonGroup at the bottom
          _partSelector(parts),
          const SizedBox(height: 16),
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
        const SizedBox(width: 14),
        Expanded(child: _powerButton(context)),
      ],
    );
  }

  Widget _settingsButton() {
    final label = I18n.t(context, 'settings_title');
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          height: 52,
          child: IconButton.filled(
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: scheme.onPrimary,
              backgroundColor: scheme.primary,
              shape: BeenutTheme.controlShape,
            ),
          ),
        ),
      ),
    );
  }

  Widget _powerButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          height: 52,
          child: IconButton.filled(
            onPressed: () => widget.client.setPreviewPaused(!paused),
            icon: Icon(paused ? Icons.play_arrow : Icons.pause, size: 20),
            style: IconButton.styleFrom(
              foregroundColor: paused ? scheme.onPrimary : scheme.onSecondary,
              backgroundColor: paused ? scheme.primary : scheme.secondary,
              shape: BeenutTheme.controlShape,
            ),
          ),
        ),
      ),
    );
  }
}
