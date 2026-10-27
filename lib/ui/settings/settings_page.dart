import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/android_camera_controller.dart';
import '../../core/config_draft.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/service_client.dart';
import '../../core/system_permissions.dart';
import '../../core/theme.dart';
import '../../core/ui_scale.dart';
import '../../core/workbench_tokens.dart';
import '../common/settings_experience.dart';
import '../kiosk/preview_pane.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/config_tab.dart';
import 'tabs/model_tab.dart';
import 'tabs/status_tab.dart';
import 'tabs/test_tab.dart';

enum SettingsTask { jobs, camera, display, machine }

enum MachineSection { model, detection, performance, devices, diagnostics }

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.snapshot,
    required this.client,
    required this.cameraPermission,
    required this.onRefreshCameraPermission,
    required this.onClose,
    this.cameraController,
    this.initialTask,
    this.initialSection = MachineSection.model,
  });
  final MachineSnapshot snapshot;
  final KioskServiceClient client;
  final CameraPermissionStatus cameraPermission;
  final Future<void> Function() onRefreshCameraPermission;
  final VoidCallback onClose;
  final AndroidCameraController? cameraController;
  final SettingsTask? initialTask;
  final MachineSection initialSection;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ConfigDraft _draft = ConfigDraft();
  final _formKey = GlobalKey<FormState>();
  SettingsTask? _task;
  MachineSection _section = MachineSection.model;
  bool _applying = false;
  bool _previewingScale = false;
  VoidCallback? _afterApply;
  Timer? _applyTimeout, _refreshTimer, _shutdownTimeout;
  bool _shutdownInProgress = false;
  int _shutdownRequestStartedAt = 0;
  late String _lastSaveResultSignature;

  @override
  void initState() {
    super.initState();
    _task = widget.initialTask;
    _section = widget.initialSection;
    _lastSaveResultSignature = _saveResultSignature(widget.snapshot.saveResult);
    widget.client.refreshCapabilities();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) widget.client.refreshCapabilities();
    });
  }

  @override
  void dispose() {
    _applyTimeout?.cancel();
    _refreshTimer?.cancel();
    _shutdownTimeout?.cancel();
    if (_previewingScale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UiScaleController.clearPreview();
      });
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final result = widget.snapshot.saveResult;
    final signature = _saveResultSignature(result);
    if ((result.hasData || result.timestampMs > 0) &&
        signature != _lastSaveResultSignature) {
      _lastSaveResultSignature = signature;
      if (_applying) {
        _applyTimeout?.cancel();
        _applying = false;
        final after = _afterApply;
        _afterApply = null;
        if (result.ok) {
          _draft.clear();
          if (_previewingScale) {
            _previewingScale = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              UiScaleController.update(widget.snapshot.config.uiSettings.scale);
              UiScaleController.clearPreview();
            });
          }
          if (after != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) after();
            });
          }
        }
      }
      if (!result.ok) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showConfigSaveFailure(result);
        });
      }
    }
    final diagnostic = widget.snapshot.diagnostic;
    if (_shutdownInProgress &&
        diagnostic.target == 'shutdown' &&
        diagnostic.timestampMs >= _shutdownRequestStartedAt) {
      if (diagnostic.ok) {
        // An accepted poweroff request can outlive the IPC connection.
        _shutdownTimeout?.cancel();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showShutdownDenied();
        });
      }
    }
  }

  String _saveResultSignature(ConfigSaveResult result) =>
      '${result.timestampMs}|${result.ok}|${result.message}|${result.detail}';
  void _showConfigSaveFailure(ConfigSaveResult result) {
    final scheme = Theme.of(context).colorScheme;
    final message = result.detail.trim().isNotEmpty
        ? result.detail
        : result.message;
    final foreground = scheme.onErrorContainer;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
          backgroundColor: scheme.errorContainer,
          shape: BeenutTheme.controlShape,
          content: Row(
            children: [
              Icon(Icons.error_outline, color: foreground, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  String _taskTitle(SettingsTask task) => I18n.t(context, switch (task) {
    SettingsTask.jobs => 'settings_jobs',
    SettingsTask.camera => 'settings_camera_task',
    SettingsTask.display => 'tab_interface',
    SettingsTask.machine => 'settings_machine',
  });
  String _sectionTitle(MachineSection section) =>
      I18n.t(context, switch (section) {
        MachineSection.model => 'settings_model_classes',
        MachineSection.detection => 'settings_detection_counting',
        MachineSection.performance => 'settings_performance',
        MachineSection.devices => 'tab_hardware',
        MachineSection.diagnostics => 'settings_diagnostics',
      });
  IconData _taskIcon(SettingsTask task) => switch (task) {
    SettingsTask.jobs => Icons.inventory_2_outlined,
    SettingsTask.camera => Icons.videocam_outlined,
    SettingsTask.display => Icons.text_fields_outlined,
    SettingsTask.machine => Icons.tune_outlined,
  };
  IconData _sectionIcon(MachineSection section) => switch (section) {
    MachineSection.model => Icons.memory_outlined,
    MachineSection.detection => Icons.center_focus_strong_outlined,
    MachineSection.performance => Icons.speed_outlined,
    MachineSection.devices => Icons.developer_board_outlined,
    MachineSection.diagnostics => Icons.monitor_heart_outlined,
  };
  void _editConfig(MachineConfig edited) {
    setState(() => _draft.update(widget.snapshot.config, edited));
    if (_task == SettingsTask.display) {
      _previewingScale = true;
      UiScaleController.preview(
        _draft.resolve(widget.snapshot.config).uiSettings.scale,
      );
    }
  }

  void _discardDraft() {
    setState(_draft.clear);
    if (_previewingScale) {
      _previewingScale = false;
      UiScaleController.clearPreview();
    }
  }

  void _saveJob(MachineConfig edited) {
    _editConfig(edited);
    _applyConfig();
  }

  void _saveCamera(MachineConfig edited) {
    if (!widget.snapshot.connected) return;
    // Camera alignment is a live control. Use the client's latest configuration
    // so a camera change cannot overwrite unrelated settings from a live update.
    // The client coalesces quick taps and rolls back rejected saves.
    setState(_draft.clear);
    widget.client.saveConfig(
      widget.client.snapshot.config.copyWithCameraSettings(
        edited.cameraSettings,
      ),
    );
  }

  void _applyConfig({VoidCallback? after}) {
    if (_applying || !(_formKey.currentState?.validate() ?? true)) return;
    if (!_draft.isDirty) {
      after?.call();
      return;
    }
    setState(() {
      _applying = true;
      _afterApply = after;
    });
    _applyTimeout?.cancel();
    _applyTimeout = Timer(const Duration(seconds: 10), () {
      if (!mounted || !_applying) return;
      setState(() {
        _applying = false;
        _afterApply = null;
      });
      _showConfigSaveFailure(
        ConfigSaveResult(
          ok: false,
          message: I18n.t(context, 'settings_save_timeout'),
          detail: '',
          timestampMs: 0,
        ),
      );
    });
    widget.client.saveConfig(_draft.resolve(widget.snapshot.config));
  }

  Future<void> _leaveTask(VoidCallback leave) async {
    if (_applying) return;
    if (!_draft.isDirty) {
      if (_previewingScale) {
        _previewingScale = false;
        UiScaleController.clearPreview();
      }
      leave();
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(I18n.t(context, 'settings_leave_title')),
        content: Text(I18n.t(context, 'settings_leave_detail')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(I18n.t(context, 'settings_keep_editing')),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(I18n.t(context, 'settings_discard')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(
              I18n.t(
                context,
                _task == SettingsTask.machine ? 'settings_apply' : 'save_btn',
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'discard') {
      _discardDraft();
      leave();
    }
    if (action == 'save') _applyConfig(after: leave);
  }

  void _changeSection(MachineSection section) {
    if (_formKey.currentState?.validate() == false) return;
    setState(() => _section = section);
  }

  void _openTask(SettingsTask task) => _leaveTask(
    () => setState(() {
      _task = task;
    }),
  );
  void _back() {
    if (_shutdownInProgress) return;
    _leaveTask(() {
      if (_task == null) {
        widget.onClose();
      } else {
        setState(() => _task = null);
      }
    });
  }

  void _beginShutdown() {
    if (_shutdownInProgress || !widget.snapshot.connected) return;
    setState(() {
      _shutdownInProgress = true;
      _shutdownRequestStartedAt = DateTime.now().millisecondsSinceEpoch;
    });
    _shutdownTimeout?.cancel();
    _shutdownTimeout = Timer(const Duration(seconds: 10), () {
      if (mounted && _shutdownInProgress) _showShutdownDenied(timedOut: true);
    });
    widget.client.shutdown();
  }

  void _showShutdownDenied({bool timedOut = false}) {
    if (!_shutdownInProgress) return;
    _shutdownTimeout?.cancel();
    setState(() => _shutdownInProgress = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          content: Text(
            I18n.t(
              context,
              timedOut ? 'shutdown_no_response' : 'shutdown_not_permitted',
            ),
          ),
        ),
      );
  }

  void _showShutdownConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.power_settings_new, color: scheme.error, size: 24),
              const SizedBox(width: 8),
              Text(
                I18n.t(context, 'confirm_shutdown'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            I18n.t(context, 'shutdown_warning'),
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(128, 56)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                I18n.t(context, 'cancel'),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _beginShutdown();
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(128, 56),
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              child: Text(
                I18n.t(context, 'shutdown_btn'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar(bool wideMachine) {
    final colors = context.workbenchColors;
    return Container(
      key: const ValueKey('settings-toolbar'),
      height: 56,
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(bottom: BorderSide(color: colors.lineSubtle)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('settings-back'),
            onPressed: _applying ? null : _back,
            tooltip: I18n.t(
              context,
              _task == null ? 'back_to_kiosk' : 'back_to_settings',
            ),
            style: IconButton.styleFrom(minimumSize: const Size.square(48)),
            icon: Icon(
              _task == null ? Icons.close : Icons.arrow_back,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                _task == null
                    ? I18n.t(context, 'settings_title')
                    : _taskTitle(_task!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.ink,
                ),
              ),
            ),
          ),
          if (_task == SettingsTask.machine && !wideMachine) ...[
            PopupMenuButton<MachineSection>(
              key: const ValueKey('settings-machine-section'),
              tooltip: I18n.t(context, 'settings_machine'),
              enabled: !_applying,
              initialValue: _section,
              onSelected: _changeSection,
              itemBuilder: (_) => [
                for (final section in MachineSection.values)
                  PopupMenuItem(
                    value: section,
                    height: 48,
                    child: Text(_sectionTitle(section)),
                  ),
              ],
              child: Container(
                height: 48,
                constraints: const BoxConstraints(maxWidth: 208),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: colors.raised,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _sectionTitle(_section),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _applyBar() {
    final colors = context.workbenchColors;
    return Container(
      key: const ValueKey('settings-apply-bar'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.lineSubtle)),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              I18n.t(context, 'settings_unsaved'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const ValueKey('settings-discard'),
            onPressed: _applying ? null : _discardDraft,
            style: OutlinedButton.styleFrom(minimumSize: const Size(96, 48)),
            child: Text(I18n.t(context, 'settings_discard')),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const ValueKey('settings-apply'),
            onPressed: _applying ? null : () => _applyConfig(),
            style: FilledButton.styleFrom(minimumSize: const Size(128, 48)),
            child: Text(
              I18n.t(
                context,
                _applying
                    ? 'settings_applying'
                    : _task == SettingsTask.machine
                    ? 'settings_apply'
                    : 'save_btn',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _draft.resolve(widget.snapshot.config);
    final colors = context.workbenchColors;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: SettingsExperience(
        developer: _task == SettingsTask.machine,
        child: Form(
          key: _formKey,
          child: Stack(
            children: [
              ColoredBox(
                color: colors.canvas,
                child: LayoutBuilder(
                  builder: (context, size) {
                    final wideMachine =
                        size.maxWidth >= 1080 && size.maxHeight >= 480;
                    return Column(
                      children: [
                        _toolbar(wideMachine),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: _applying,
                            child: _task == null
                                ? _taskList(config)
                                : switch (_task!) {
                                    SettingsTask.jobs => _scrollContent(
                                      'jobs',
                                      _jobs(config),
                                    ),
                                    SettingsTask.display => _scrollContent(
                                      'display',
                                      StatusSettingsTab(
                                        config: config,
                                        snapshot: widget.snapshot,
                                        cameraPermission:
                                            widget.cameraPermission,
                                        onRefreshCameraPermission:
                                            widget.onRefreshCameraPermission,
                                        onRefreshCapabilities:
                                            widget.client.refreshCapabilities,
                                        onSave: _editConfig,
                                        enabled: true,
                                        section:
                                            StatusSettingsSection.interface,
                                      ),
                                    ),
                                    SettingsTask.camera => _cameraWorkspace(
                                      config,
                                    ),
                                    SettingsTask.machine => _machineWorkspace(
                                      config,
                                      wideMachine,
                                    ),
                                  },
                          ),
                        ),
                        if (_task == null &&
                            widget.snapshot.capabilities.canPoweroff)
                          _shutdownFooter(),
                        if (_draft.isDirty || _applying) _applyBar(),
                      ],
                    );
                  },
                ),
              ),
              if (_shutdownInProgress) const _ShutdownProgressOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scrollContent(String id, Widget child) => ListView(
    key: ValueKey('settings-content-$id'),
    padding: const EdgeInsets.all(12),
    children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: child,
        ),
      ),
    ],
  );

  bool get _cameraPermissionNeedsAttention =>
      widget.snapshot.state.camera != 'ready' &&
      widget.snapshot.state.camera != 'paused' &&
      (widget.cameraPermission.blocksCamera ||
          widget.cameraPermission == CameraPermissionStatus.notDetermined);

  Widget _shutdownFooter() => Container(
    decoration: BoxDecoration(
      color: context.workbenchColors.canvas,
      border: Border(
        top: BorderSide(color: context.workbenchColors.lineSubtle),
      ),
    ),
    padding: const EdgeInsets.all(12),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SidebarShutdownButton(
          key: const ValueKey('settings-shutdown'),
          onPressed: widget.snapshot.connected && !_applying
              ? () => _showShutdownConfirmDialog(context)
              : null,
        ),
      ),
    ),
  );

  Widget _taskList(MachineConfig config) {
    final colors = context.workbenchColors;
    final state = widget.snapshot.state;
    final issue =
        !widget.snapshot.connected ||
        _cameraPermissionNeedsAttention ||
        state.camera == 'error' ||
        state.camera == 'missing' ||
        state.model == 'error' ||
        state.model == 'missing';
    return _scrollContent(
      'tasks',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (issue)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: colors.dangerSoft,
                child: ListTile(
                  minTileHeight: 56,
                  leading: Icon(Icons.error_outline, color: colors.danger),
                  title: Text(I18n.t(context, 'settings_attention')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _section = MachineSection.diagnostics;
                    _openTask(SettingsTask.machine);
                  },
                ),
              ),
            ),
          Material(
            color: colors.canvas,
            child: Column(
              children: [
                for (final task in SettingsTask.values) ...[
                  SettingsNavButton(
                    key: ValueKey('settings-task-${task.name}'),
                    selected: false,
                    icon: _taskIcon(task),
                    title: _taskTitle(task),
                    value: task == SettingsTask.jobs
                        ? config.partTypes
                              .where((p) => p.enabled)
                              .take(3)
                              .map((p) => p.name)
                              .join(' · ')
                        : null,
                    onPressed: () => _openTask(task),
                  ),
                  if (task != SettingsTask.values.last)
                    Divider(height: 1, color: colors.lineSubtle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobs(MachineConfig config) {
    if (config.partTypes.isEmpty) {
      return Column(
        children: [
          Text(I18n.t(context, 'no_targets_found')),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _openTask(SettingsTask.machine),
            child: Text(I18n.t(context, 'settings_machine')),
          ),
        ],
      );
    }
    return PartCatalogEditor(
      config: config,
      modelLabels: widget.snapshot.state.modelLabels,
      enabled: true,
      allowClassMapping: false,
      onSave: _saveJob,
    );
  }

  Widget _preview(MachineConfig config) {
    // Show the applied camera and class mapping until the draft is acknowledged.
    final live = widget.snapshot.config;
    final state = widget.snapshot.state;
    final part = live.partTypes
        .where((p) => p.id == state.selectedPartType)
        .firstOrNull;
    final camera = live.cameraSettings;
    // The native pipeline can crop capture frames before publishing preview.
    final previewWidth = int.tryParse(
      RegExp(
            r'width=(?:\(int\))?(\d+)',
          ).firstMatch(state.previewCaps)?.group(1) ??
          '',
    );
    final previewHeight = int.tryParse(
      RegExp(
            r'height=(?:\(int\))?(\d+)',
          ).firstMatch(state.previewCaps)?.group(1) ??
          '',
    );
    final aspectRatio =
        previewWidth != null &&
            previewWidth > 0 &&
            previewHeight != null &&
            previewHeight > 0
        ? previewWidth / previewHeight
        : camera.height > 0
        ? camera.width / camera.height
        : 4 / 3;
    return NativePreviewPane(
      key: const ValueKey('settings-native-preview'),
      state: state,
      connected: widget.snapshot.connected,
      previewSocket: live.previewSocket,
      keywords: part?.keywords ?? const [],
      classNames: part?.classNames ?? const {},
      client: widget.client,
      cameraController: widget.cameraController,
      aspectRatio: aspectRatio,
    );
  }

  Widget _metrics() {
    final state = widget.snapshot.state;
    final colors = context.workbenchColors;
    return Container(
      key: const ValueKey('settings-live-metrics'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: colors.surface,
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          Text(
            '${state.count} ${I18n.t(context, 'items_unit')}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          Text('${state.inferenceFps.toStringAsFixed(1)} fps'),
          Text('${state.processingMs} ms'),
          if (state.previewPaused)
            IconButton(
              onPressed: () => widget.client.setPreviewPaused(false),
              icon: const Icon(Icons.play_arrow),
              tooltip: I18n.t(context, 'resume_preview'),
            ),
          if (state.temperature > 0 && state.thermalState != 'unknown')
            Text('${state.temperature.toStringAsFixed(1)} °C'),
        ],
      ),
    );
  }

  Widget _monitor(MachineConfig config) => Column(
    children: [
      Expanded(child: _preview(config)),
      _metrics(),
    ],
  );

  Widget _cameraWorkspace(MachineConfig config) => LayoutBuilder(
    builder: (context, size) {
      final controls = ConfigEditor(
        config: config,
        capabilities: widget.snapshot.capabilities,
        enabled: widget.snapshot.connected,
        onSave: _saveCamera,
        section: ConfigEditorSection.camera,
      );
      final needsPermission = _cameraPermissionNeedsAttention;
      final form = Column(
        children: [
          if (needsPermission)
            StatusSettingsTab(
              config: config,
              snapshot: widget.snapshot,
              cameraPermission: widget.cameraPermission,
              onRefreshCameraPermission: widget.onRefreshCameraPermission,
              onRefreshCapabilities: widget.client.refreshCapabilities,
              onSave: _editConfig,
              enabled: true,
              section: StatusSettingsSection.cameraPermission,
            ),
          controls,
        ],
      );
      if (size.maxWidth >= 700) {
        return Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _monitor(config),
              ),
            ),
            Expanded(child: _scrollContent('camera', form)),
          ],
        );
      }
      return Column(
        children: [
          SizedBox(
            height: (size.maxHeight * .44).clamp(100, 220),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _preview(config),
            ),
          ),
          if (widget.snapshot.state.previewPaused)
            TextButton.icon(
              onPressed: () => widget.client.setPreviewPaused(false),
              icon: const Icon(Icons.play_arrow),
              label: Text(I18n.t(context, 'resume_preview')),
            ),
          Expanded(child: _scrollContent('camera', form)),
        ],
      );
    },
  );
  Widget _machineWorkspace(MachineConfig config, bool wide) {
    final form = _scrollContent(
      'machine-${_section.name}',
      _machineForm(config),
    );
    if (!wide) {
      return form;
    }
    final colors = context.workbenchColors;
    return Row(
      children: [
        SizedBox(
          width: 184,
          child: ColoredBox(
            color: colors.surface,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final section in MachineSection.values)
                  SidebarDestination(
                    selected: _section == section,
                    icon: _sectionIcon(section),
                    title: _sectionTitle(section),
                    onPressed: () => _changeSection(section),
                  ),
              ],
            ),
          ),
        ),
        Expanded(child: form),
      ],
    );
  }

  Widget _machineForm(MachineConfig config) {
    final state = widget.snapshot.state;
    ModelSettingsTab model(ModelSettingsSection section) => ModelSettingsTab(
      config: config,
      state: state,
      capabilities: widget.snapshot.capabilities,
      enabled: true,
      onSave: _editConfig,
      section: section,
    );
    ConfigEditor camera(ConfigEditorSection section) => ConfigEditor(
      config: config,
      capabilities: widget.snapshot.capabilities,
      enabled: true,
      onSave: _editConfig,
      section: section,
    );
    final modelUnapplied =
        config.modelSettings.ncnnBinPath !=
            widget.snapshot.config.modelSettings.ncnnBinPath ||
        config.modelSettings.modelPath !=
            widget.snapshot.config.modelSettings.modelPath ||
        config.modelSettings.hefPath !=
            widget.snapshot.config.modelSettings.hefPath ||
        config.modelSettings.engine !=
            widget.snapshot.config.modelSettings.engine ||
        config.modelSettings.labelsPath !=
            widget.snapshot.config.modelSettings.labelsPath ||
        config.modelSettings.labelsMode !=
            widget.snapshot.config.modelSettings.labelsMode;
    return switch (_section) {
      MachineSection.model => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          model(ModelSettingsSection.model),
          if (modelUnapplied)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(I18n.t(context, 'settings_apply_model_first')),
            )
          else
            PartCatalogEditor(
              config: config,
              modelLabels: state.modelLabels,
              allowClassMapping: true,
              enabled: true,
              onSave: _editConfig,
            ),
        ],
      ),
      MachineSection.detection => Column(
        children: [
          camera(ConfigEditorSection.counting),
          model(ModelSettingsSection.detection),
          model(ModelSettingsSection.counting),
        ],
      ),
      MachineSection.performance => Column(
        children: [
          model(ModelSettingsSection.performance),
          camera(ConfigEditorSection.performance),
        ],
      ),
      MachineSection.devices => Column(
        children: [camera(ConfigEditorSection.hardware)],
      ),
      MachineSection.diagnostics => Column(
        children: [
          HardwareTestTab(
            state: state,
            diagnostic: widget.snapshot.diagnostic,
            client: widget.client,
          ),
          StatusSettingsTab(
            config: config,
            snapshot: widget.snapshot,
            cameraPermission: widget.cameraPermission,
            onRefreshCameraPermission: widget.onRefreshCameraPermission,
            onRefreshCapabilities: widget.client.refreshCapabilities,
            onSave: _editConfig,
            enabled: true,
            section: StatusSettingsSection.overview,
          ),
          StatusSettingsTab(
            config: config,
            snapshot: widget.snapshot,
            cameraPermission: widget.cameraPermission,
            onRefreshCameraPermission: widget.onRefreshCameraPermission,
            onRefreshCapabilities: widget.client.refreshCapabilities,
            onSave: _editConfig,
            enabled: true,
            section: StatusSettingsSection.service,
          ),
          model(ModelSettingsSection.service),
        ],
      ),
    };
  }
}

class SettingsNavGroupLabel extends StatelessWidget {
  const SettingsNavGroupLabel({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Text(
          title,
          style: TextStyle(
            color: tokens.muted,
            fontSize: 11.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class SettingsNavButton extends StatelessWidget {
  const SettingsNavButton({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onPressed,
    this.value,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onPressed;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final color = selected ? tokens.ink : tokens.muted;
    return Material(
      color: selected ? tokens.lineSubtle : Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? tokens.actionText : tokens.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (constraints.maxWidth >= 560 &&
                      value?.isNotEmpty == true) ...[
                    const SizedBox(width: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.35,
                      ),
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: tokens.muted.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarDestination extends StatelessWidget {
  const SidebarDestination({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected ? tokens.lineSubtle : Colors.transparent,
        borderRadius: BorderRadius.zero,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: WorkbenchMetric.technicianHitTarget,
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: selected ? tokens.action : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? tokens.actionText : tokens.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected ? tokens.actionText : tokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarShutdownButton extends StatelessWidget {
  const SidebarShutdownButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.power_settings_new, size: 24),
        label: Text(I18n.t(context, 'shutdown_btn')),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          foregroundColor: tokens.danger,
          side: BorderSide(color: tokens.line),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _ShutdownProgressOverlay extends StatelessWidget {
  const _ShutdownProgressOverlay();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.48),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BeenutTheme.radiusPanel,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoActivityIndicator(
                    radius: 14,
                    color: scheme.onSurface,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    I18n.t(context, 'shutting_down'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    I18n.t(context, 'shutdown_waiting'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
