import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/service_client.dart';
import '../../core/system_permissions.dart';
import '../../core/theme.dart';
import '../../core/workbench_tokens.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/config_tab.dart';
import 'tabs/model_tab.dart';
import 'tabs/status_tab.dart';
import 'tabs/test_tab.dart';
import '../../core/i18n.dart';

enum SettingsDestination {
  overview,
  targets,
  counting,
  camera,
  model,
  hardware,
  interface,
  service,
}

enum SettingsDestinationGroup { operation, device, system }

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.snapshot,
    required this.client,
    required this.cameraPermission,
    required this.onRefreshCameraPermission,
    required this.onClose,
  });

  final MachineSnapshot snapshot;
  final KioskServiceClient client;
  final CameraPermissionStatus cameraPermission;
  final Future<void> Function() onRefreshCameraPermission;
  final VoidCallback onClose;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsDestination activeDestination = SettingsDestination.overview;
  final ScrollController _sidebarScrollController = ScrollController();
  Timer? _refreshTimer;
  Timer? _shutdownTimeout;
  bool _shutdownInProgress = false;
  int _shutdownRequestStartedAt = 0;
  late String _lastSaveResultSignature;

  @override
  void initState() {
    super.initState();
    _lastSaveResultSignature = _saveResultSignature(widget.snapshot.saveResult);
    widget.client.refreshCapabilities();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        widget.client.refreshCapabilities();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _shutdownTimeout?.cancel();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final saveResult = widget.snapshot.saveResult;
    final saveResultSignature = _saveResultSignature(saveResult);
    if (saveResult.hasData && saveResultSignature != _lastSaveResultSignature) {
      _lastSaveResultSignature = saveResultSignature;
      if (!saveResult.ok) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showConfigSaveFailure(saveResult);
        });
      }
    }
    final diagnostic = widget.snapshot.diagnostic;
    if (_shutdownInProgress &&
        diagnostic.target == 'shutdown' &&
        !diagnostic.ok &&
        diagnostic.timestampMs >= _shutdownRequestStartedAt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showShutdownDenied();
      });
    }
  }

  String _saveResultSignature(ConfigSaveResult result) =>
      '${result.timestampMs}|${result.ok}|${result.message}|${result.detail}';

  void _showConfigSaveFailure(ConfigSaveResult result) {
    final scheme = Theme.of(context).colorScheme;
    final message = result.message.trim().isNotEmpty
        ? result.message
        : result.detail;
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

  String _destinationTitle(
    BuildContext context,
    SettingsDestination destination,
  ) => switch (destination) {
    SettingsDestination.overview => I18n.t(context, 'tab_overview'),
    SettingsDestination.targets => I18n.t(context, 'tab_targets'),
    SettingsDestination.counting => I18n.t(context, 'tab_counting'),
    SettingsDestination.camera => I18n.t(context, 'tab_camera'),
    SettingsDestination.model => I18n.t(context, 'tab_model'),
    SettingsDestination.hardware => I18n.t(context, 'tab_hardware'),
    SettingsDestination.interface => I18n.t(context, 'tab_interface'),
    SettingsDestination.service => I18n.t(context, 'tab_service'),
  };

  String? _destinationDescription(
    BuildContext context,
    SettingsDestination destination,
  ) => switch (destination) {
    SettingsDestination.overview => I18n.t(context, 'overview_description'),
    SettingsDestination.targets => I18n.t(context, 'targets_description'),
    SettingsDestination.counting => I18n.t(context, 'counting_description'),
    SettingsDestination.camera => I18n.t(context, 'camera_description'),
    SettingsDestination.model => I18n.t(context, 'model_description'),
    SettingsDestination.hardware => I18n.t(context, 'hardware_description'),
    SettingsDestination.interface => I18n.t(context, 'interface_description'),
    SettingsDestination.service => I18n.t(context, 'service_description'),
  };

  IconData _destinationIcon(SettingsDestination destination) =>
      switch (destination) {
        SettingsDestination.overview => Icons.monitor_heart_outlined,
        SettingsDestination.targets => Icons.inventory_2_outlined,
        SettingsDestination.counting => Icons.filter_alt_outlined,
        SettingsDestination.camera => Icons.camera_alt_outlined,
        SettingsDestination.model => Icons.psychology_outlined,
        SettingsDestination.hardware => Icons.developer_board_outlined,
        SettingsDestination.interface => Icons.display_settings_outlined,
        SettingsDestination.service => Icons.home_repair_service_outlined,
      };

  SettingsDestinationGroup _destinationGroup(SettingsDestination destination) =>
      switch (destination) {
        SettingsDestination.overview ||
        SettingsDestination.targets ||
        SettingsDestination.counting => SettingsDestinationGroup.operation,
        SettingsDestination.camera ||
        SettingsDestination.model ||
        SettingsDestination.hardware => SettingsDestinationGroup.device,
        SettingsDestination.interface ||
        SettingsDestination.service => SettingsDestinationGroup.system,
      };

  String _groupTitle(
    BuildContext context,
    SettingsDestinationGroup group,
  ) => switch (group) {
    SettingsDestinationGroup.operation => I18n.t(
      context,
      'settings_group_operation',
    ),
    SettingsDestinationGroup.device => I18n.t(context, 'settings_group_device'),
    SettingsDestinationGroup.system => I18n.t(context, 'settings_group_system'),
  };

  Iterable<SettingsDestination> _destinationsFor(
    SettingsDestinationGroup group,
  ) => SettingsDestination.values.where(
    (destination) => _destinationGroup(destination) == group,
  );

  SettingsDestination? activeDestinationForMobile;

  void _beginShutdown() {
    setState(() {
      _shutdownInProgress = true;
      _shutdownRequestStartedAt = DateTime.now().millisecondsSinceEpoch;
    });
    _shutdownTimeout?.cancel();
    _shutdownTimeout = Timer(const Duration(seconds: 10), () {
      if (mounted && _shutdownInProgress) _showShutdownDenied();
    });
    widget.client.shutdown();
  }

  void _showShutdownDenied() {
    if (!_shutdownInProgress) return;
    _shutdownTimeout?.cancel();
    setState(() => _shutdownInProgress = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'shutdown_not_permitted'))),
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
              Icon(Icons.warning_amber_outlined, color: scheme.error, size: 20),
              const SizedBox(width: 8),
              Text(
                I18n.t(context, 'confirm_shutdown'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            I18n.t(context, 'shutdown_warning'),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
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

  @override
  Widget build(BuildContext context) {
    final config = widget.snapshot.config;
    final state = widget.snapshot.state;
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 640;
            if (isMobile) {
              return _buildMobileLayout(context, config, state);
            }
            return _buildDesktopLayout(context, config, state);
          },
        ),
        if (_shutdownInProgress) const _ShutdownProgressOverlay(),
      ],
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    MachineConfig config,
    MachineState state,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.workbenchColors;
    return ColoredBox(
      color: tokens.canvas,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.raised,
              border: Border(right: BorderSide(color: tokens.line)),
            ),
            child: SizedBox(
              width: WorkbenchMetric.sidebarWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: widget.onClose,
                          tooltip: I18n.t(context, 'back_to_kiosk'),
                          icon: const Icon(Icons.arrow_back, size: 20),
                          style: IconButton.styleFrom(
                            foregroundColor: scheme.onSurface,
                            minimumSize: const Size.square(
                              WorkbenchMetric.technicianHitTarget,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            I18n.t(context, 'settings_title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: tokens.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: tokens.line),
                  Expanded(
                    child: Scrollbar(
                      controller: _sidebarScrollController,
                      child: ListView(
                        controller: _sidebarScrollController,
                        primary: false,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        children: [
                          for (final group
                              in SettingsDestinationGroup.values) ...[
                            SettingsNavGroupLabel(
                              title: _groupTitle(context, group),
                            ),
                            for (final destination in _destinationsFor(group))
                              SidebarDestination(
                                selected: activeDestination == destination,
                                icon: _destinationIcon(destination),
                                title: _destinationTitle(context, destination),
                                onPressed: () => setState(() {
                                  activeDestination = destination;
                                  activeDestinationForMobile = destination;
                                }),
                              ),
                            if (group != SettingsDestinationGroup.values.last)
                              const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (widget.snapshot.capabilities.canPoweroff)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: SidebarShutdownButton(
                        onPressed: () => _showShutdownConfirmDialog(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, contentConstraints) {
                final horizontalPadding = contentConstraints.maxWidth >= 1040
                    ? WorkbenchSpace.x8
                    : WorkbenchSpace.x6;
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    WorkbenchSpace.x8,
                    horizontalPadding,
                    WorkbenchSpace.x8,
                  ),
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: WorkbenchMetric.contentMaxWidth,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.topLeft,
                              children: [...previousChildren, ?currentChild],
                            );
                          },
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          child: _buildDesktopDestinationPane(
                            context,
                            activeDestination,
                            config,
                            state,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    MachineConfig config,
    MachineState state,
  ) {
    final currentDestination = activeDestinationForMobile;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.workbenchColors;
    final canPoweroff = widget.snapshot.capabilities.canPoweroff;
    if (currentDestination == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: AppBar(
          backgroundColor: tokens.raised,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: scheme.onSurface, size: 20),
            onPressed: widget.onClose,
          ),
          title: Text(
            I18n.t(context, 'settings_title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: scheme.outlineVariant),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          children: [
            for (final group in SettingsDestinationGroup.values)
              _buildMobileNavigationGroup(context, group),
            if (canPoweroff)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SidebarShutdownButton(
                  onPressed: () => _showShutdownConfirmDialog(context),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.raised,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: scheme.onSurface,
            size: 18,
          ),
          onPressed: () => setState(() => activeDestinationForMobile = null),
        ),
        title: Text(
          _destinationTitle(context, currentDestination),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        children: [
          if (_destinationDescription(context, currentDestination)
              case final description?) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WorkbenchSpace.x2,
              ),
              child: Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.muted),
              ),
            ),
            const SizedBox(height: WorkbenchSpace.x4),
          ],
          _buildDestinationContent(currentDestination, config, state),
        ],
      ),
    );
  }

  Widget _buildMobileNavigationGroup(
    BuildContext context,
    SettingsDestinationGroup group,
  ) {
    final tokens = context.workbenchColors;
    final destinations = _destinationsFor(group).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: WorkbenchSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsNavGroupLabel(title: _groupTitle(context, group)),
          Material(
            color: tokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BeenutTheme.radiusPanel,
              side: BorderSide(color: tokens.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int index = 0; index < destinations.length; index++) ...[
                  SettingsNavButton(
                    selected: false,
                    icon: _destinationIcon(destinations[index]),
                    title: _destinationTitle(context, destinations[index]),
                    onPressed: () => setState(() {
                      activeDestination = destinations[index];
                      activeDestinationForMobile = destinations[index];
                    }),
                  ),
                  if (index < destinations.length - 1)
                    Divider(height: 1, indent: 48, color: tokens.lineSubtle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationContent(
    SettingsDestination destination,
    MachineConfig config,
    MachineState state,
  ) {
    switch (destination) {
      case SettingsDestination.overview:
        return StatusSettingsTab(
          key: ValueKey(destination),
          config: config,
          snapshot: widget.snapshot,
          cameraPermission: widget.cameraPermission,
          onRefreshCameraPermission: widget.onRefreshCameraPermission,
          onRefreshCapabilities: widget.client.refreshCapabilities,
          onSave: widget.client.saveConfig,
          enabled: true,
          section: StatusSettingsSection.overview,
        );
      case SettingsDestination.targets:
        return Column(
          key: ValueKey(destination),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PartCatalogEditor(
              config: config,
              modelLabels: state.modelLabels,
              enabled: true,
              onSave: widget.client.saveConfig,
            ),
          ],
        );
      case SettingsDestination.counting:
        return Column(
          key: ValueKey(destination),
          children: [
            ConfigEditor(
              key: const ValueKey('counting-trigger-settings'),
              config: config,
              capabilities: widget.snapshot.capabilities,
              enabled: true,
              onSave: widget.client.saveConfig,
              section: ConfigEditorSection.counting,
            ),
            ModelSettingsTab(
              key: const ValueKey('counting-behavior-settings'),
              config: config,
              state: state,
              capabilities: widget.snapshot.capabilities,
              enabled: true,
              onSave: widget.client.saveConfig,
              section: ModelSettingsSection.counting,
            ),
          ],
        );
      case SettingsDestination.camera:
        return ConfigEditor(
          key: ValueKey(destination),
          config: config,
          capabilities: widget.snapshot.capabilities,
          enabled: true,
          onSave: widget.client.saveConfig,
          section: ConfigEditorSection.camera,
        );
      case SettingsDestination.model:
        return ModelSettingsTab(
          key: ValueKey(destination),
          config: config,
          state: state,
          capabilities: widget.snapshot.capabilities,
          enabled: true,
          onSave: widget.client.saveConfig,
          section: ModelSettingsSection.model,
        );
      case SettingsDestination.hardware:
        return ConfigEditor(
          key: ValueKey(destination),
          config: config,
          capabilities: widget.snapshot.capabilities,
          enabled: true,
          onSave: widget.client.saveConfig,
          section: ConfigEditorSection.hardware,
        );
      case SettingsDestination.interface:
        return StatusSettingsTab(
          key: ValueKey(destination),
          config: config,
          snapshot: widget.snapshot,
          cameraPermission: widget.cameraPermission,
          onRefreshCameraPermission: widget.onRefreshCameraPermission,
          onRefreshCapabilities: widget.client.refreshCapabilities,
          onSave: widget.client.saveConfig,
          enabled: true,
          section: StatusSettingsSection.interface,
        );
      case SettingsDestination.service:
        return Column(
          key: ValueKey(destination),
          children: [
            HardwareTestTab(
              key: const ValueKey('service-diagnostics-settings'),
              state: state,
              diagnostic: widget.snapshot.diagnostic,
              client: widget.client,
            ),
            StatusSettingsTab(
              key: const ValueKey('service-status-settings'),
              config: config,
              snapshot: widget.snapshot,
              cameraPermission: widget.cameraPermission,
              onRefreshCameraPermission: widget.onRefreshCameraPermission,
              onRefreshCapabilities: widget.client.refreshCapabilities,
              onSave: widget.client.saveConfig,
              enabled: true,
              section: StatusSettingsSection.service,
            ),
            ModelSettingsTab(
              key: const ValueKey('service-fallback-settings'),
              config: config,
              state: state,
              capabilities: widget.snapshot.capabilities,
              enabled: true,
              onSave: widget.client.saveConfig,
              section: ModelSettingsSection.service,
            ),
          ],
        );
    }
  }

  Widget _buildDesktopDestinationPane(
    BuildContext context,
    SettingsDestination destination,
    MachineConfig config,
    MachineState state,
  ) {
    return Column(
      key: ValueKey('destination-pane-$destination'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsContentHeader(
          title: _destinationTitle(context, destination),
          description: _destinationDescription(context, destination),
        ),
        const SizedBox(height: WorkbenchSpace.x6),
        _buildDestinationContent(destination, config, state),
      ],
    );
  }
}

class SettingsContentHeader extends StatelessWidget {
  const SettingsContentHeader({
    super.key,
    required this.title,
    this.description,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.workbenchColors;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.headlineSmall),
          if (description case final value?) ...[
            const SizedBox(height: WorkbenchSpace.x1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(
                value,
                style: textTheme.bodyMedium?.copyWith(color: tokens.muted),
              ),
            ),
          ],
        ],
      ),
    );
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: Text(
          title,
          style: TextStyle(
            color: tokens.muted,
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w400,
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
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    return Material(
      color: selected ? tokens.actionSoft : Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? tokens.actionText : tokens.muted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? tokens.actionText : tokens.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: selected ? tokens.actionText : tokens.muted,
                ),
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? tokens.actionSoft : Colors.transparent,
        borderRadius: BeenutTheme.radiusSharp,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BeenutTheme.radiusSharp,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: WorkbenchMetric.technicianHitTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? tokens.actionText : tokens.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
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

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.workbenchColors;
    final label = I18n.t(context, 'shutdown_btn');
    return Tooltip(
      message: label,
      child: Material(
        color: tokens.dangerSoft,
        borderRadius: BeenutTheme.radiusSharp,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BeenutTheme.radiusSharp,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(Icons.power_settings_new, size: 20, color: tokens.danger),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: tokens.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                    I18n.t(context, 'waiting_daemon_stop'),
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
