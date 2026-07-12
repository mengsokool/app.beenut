import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/maintenance_actions.dart';
import '../../../core/models.dart';
import '../../../core/service_client.dart';
import '../../../core/i18n.dart';
import '../../common/widgets.dart';

class HardwareTestTab extends StatefulWidget {
  const HardwareTestTab({
    super.key,
    required this.state,
    required this.diagnostic,
    required this.client,
  });

  final MachineState state;
  final DiagnosticEvent diagnostic;
  final KioskServiceClient client;

  @override
  State<HardwareTestTab> createState() => _HardwareTestTabState();
}

class _HardwareTestTabState extends State<HardwareTestTab> {
  bool _exportingDiagnostics = false;
  bool _resettingFactory = false;
  bool _runningUsbUpdate = false;
  MaintenanceActionResult? _maintenanceResult;

  Future<void> _exportDiagnostics() async {
    setState(() => _exportingDiagnostics = true);
    final result = await MaintenanceActions.collectDiagnostics();
    if (!mounted) return;
    setState(() {
      _exportingDiagnostics = false;
      _maintenanceResult = result;
    });
  }

  Future<void> _confirmFactoryReset() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Factory reset'),
            content: const Text(
              'Restore runtime configuration to the package default. Models and device identity are kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reset'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _resettingFactory = true);
    final result = await MaintenanceActions.factoryReset();
    if (!mounted) return;
    setState(() {
      _resettingFactory = false;
      _maintenanceResult = result;
    });
    if (result.ok) {
      widget.client.refreshCapabilities();
    }
  }

  Future<void> _runUsbUpdate({required bool dryRun}) async {
    final updateDir = await _selectUsbUpdateDirectory();
    if (updateDir == null || !mounted) return;

    if (!dryRun) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Apply USB update'),
              content: Text(
                'Install the update from:\n$updateDir\n\nThe service may restart and rollback if the health check fails.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }

    setState(() => _runningUsbUpdate = true);
    final result = await MaintenanceActions.applyUsbUpdate(
      updateDir: updateDir,
      dryRun: dryRun,
    );
    if (!mounted) return;
    setState(() {
      _runningUsbUpdate = false;
      _maintenanceResult = result;
    });
    if (result.ok && !dryRun) {
      widget.client.refreshCapabilities();
    }
  }

  Future<String?> _selectUsbUpdateDirectory() async {
    final dirs = MaintenanceActions.findUsbUpdateDirectories();
    if (dirs.isEmpty) {
      setState(() {
        _maintenanceResult = const MaintenanceActionResult(
          ok: false,
          message: 'No USB update found',
          detail:
              'Insert a USB drive containing a beenut-update folder, then scan again.',
        );
      });
      return null;
    }
    if (dirs.length == 1) return dirs.single;
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select update folder'),
        children: [
          for (final dir in dirs)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(dir),
              child: Text(dir),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final diagnostic = widget.diagnostic;
    final client = widget.client;
    return Column(
      children: [
        SettingsGroup(
          title: I18n.t(context, 'quick_checks'),
          icon: Icons.fact_check_outlined,
          children: [
            ActionSettingRow(
              icon: Icons.camera_alt_outlined,
              iconColor: scheme.primary,
              label: 'Camera Pipeline',
              description:
                  'Check active camera pipeline, capture FPS, and preview caps',
              actions: [
                RowAction(
                  label: 'Test Camera',
                  primary: true,
                  onPressed: () => client.runDiagnostic('camera'),
                ),
              ],
            ),
            ActionSettingRow(
              icon: Icons.psychology_outlined,
              iconColor: scheme.tertiary,
              label: 'AI Runtime',
              description:
                  'Check model runtime readiness and latest inference metrics',
              actions: [
                RowAction(
                  label: 'Benchmark',
                  primary: true,
                  onPressed: () => client.runDiagnostic('model'),
                ),
              ],
            ),
            ActionSettingRow(
              icon: Icons.cable_outlined,
              iconColor: scheme.onSurfaceVariant,
              label: 'GPIO Backend',
              description: 'Check sensor and relay backend state',
              actions: [
                RowAction(
                  label: 'Test GPIO',
                  primary: true,
                  onPressed: () => client.runDiagnostic('gpio'),
                ),
              ],
            ),
            if (diagnostic.hasData)
              IconInfoRow(
                icon: diagnostic.ok
                    ? Icons.check_box_outlined
                    : Icons.error_outline,
                iconColor: diagnostic.ok ? scheme.tertiary : scheme.error,
                label: 'Last Diagnostic',
                description: diagnostic.detail,
                value: '${diagnostic.target}: ${diagnostic.message}',
                tone: diagnostic.ok ? RowTone.success : RowTone.danger,
              ),
          ],
        ),
        SettingsGroup(
          title: I18n.t(context, 'manual_controls'),
          description: I18n.t(context, 'manual_controls_desc'),
          icon: Icons.touch_app_outlined,
          collapsible: true,
          initiallyExpanded: false,
          children: [
            ActionSettingRow(
              icon: Icons.lightbulb_outline,
              iconColor: scheme.secondary,
              label: 'LED Relay',
              description: 'Turn off/on lighting relay',
              actions: [
                RowAction(
                  label: I18n.t(context, 'turn_light_on'),
                  onPressed: () => client.testLight(true),
                ),
                RowAction(
                  label: I18n.t(context, 'turn_light_off'),
                  onPressed: () => client.testLight(false),
                ),
              ],
            ),
            ActionSettingRow(
              icon: Icons.inventory_2_outlined,
              iconColor: scheme.primary,
              label: 'Tray Simulation',
              description: 'Simulate placing or pulling the tray',
              actions: [
                RowAction(
                  label: I18n.t(context, 'place_tray'),
                  onPressed: () => client.testTray(true),
                ),
                RowAction(
                  label: I18n.t(context, 'remove_tray'),
                  onPressed: () => client.testTray(false),
                ),
              ],
            ),
            ActionSettingRow(
              icon: Icons.camera_alt_outlined,
              iconColor: scheme.tertiary,
              label: 'Manual Count',
              description: state.countTestMessage.isEmpty
                  ? 'Trigger snapshot count verification sequence'
                  : state.countTestMessage,
              actions: [
                RowAction(
                  label: state.countTestRunning
                      ? I18n.t(context, 'counting')
                      : I18n.t(context, 'test_count'),
                  primary: true,
                  onPressed: state.countTestRunning ? null : client.countOnce,
                ),
              ],
            ),
          ],
        ),
        SettingsGroup(
          title: I18n.t(context, 'service_maintenance'),
          description: I18n.t(context, 'service_maintenance_desc'),
          icon: Icons.home_repair_service_outlined,
          collapsible: true,
          initiallyExpanded: false,
          children: [
            ActionSettingRow(
              icon: Icons.archive_outlined,
              iconColor: scheme.primary,
              label: 'Diagnostics Bundle',
              description:
                  (_maintenanceResult?.artifactPath.isNotEmpty ?? false)
                  ? _maintenanceResult!.artifactPath
                  : 'Export redacted config, logs, backend capabilities, and diagnostic events',
              actions: [
                RowAction(
                  label: _exportingDiagnostics ? 'Exporting...' : 'Export',
                  primary: true,
                  onPressed: _exportingDiagnostics
                      ? null
                      : () => unawaited(_exportDiagnostics()),
                ),
              ],
            ),
            ActionSettingRow(
              icon: Icons.restore_outlined,
              iconColor: scheme.secondary,
              label: 'Factory Reset',
              description:
                  'Restore default runtime config while keeping models and device identity',
              actions: [
                RowAction(
                  label: _resettingFactory ? 'Resetting...' : 'Reset',
                  onPressed: _resettingFactory
                      ? null
                      : () => unawaited(_confirmFactoryReset()),
                ),
              ],
            ),
            ActionSettingRow(
              icon: Icons.system_update_alt_outlined,
              iconColor: scheme.tertiary,
              label: 'USB Offline Update',
              description:
                  'Find a beenut-update folder on an attached drive, validate it, then apply when ready',
              actions: [
                RowAction(
                  label: _runningUsbUpdate ? 'Checking...' : 'Dry Run',
                  onPressed: _runningUsbUpdate
                      ? null
                      : () => unawaited(_runUsbUpdate(dryRun: true)),
                ),
                RowAction(
                  label: _runningUsbUpdate ? 'Updating...' : 'Apply',
                  primary: true,
                  onPressed: _runningUsbUpdate
                      ? null
                      : () => unawaited(_runUsbUpdate(dryRun: false)),
                ),
              ],
            ),
            if (_maintenanceResult != null)
              IconInfoRow(
                icon: _maintenanceResult!.ok
                    ? Icons.check_box_outlined
                    : Icons.error_outline,
                iconColor: _maintenanceResult!.ok
                    ? scheme.tertiary
                    : scheme.error,
                label: 'Maintenance Action',
                description: _maintenanceResult!.detail,
                value: _maintenanceResult!.message,
                tone: _maintenanceResult!.ok ? RowTone.success : RowTone.danger,
              ),
          ],
        ),
      ],
    );
  }
}
