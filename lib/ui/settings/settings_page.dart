import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/service_client.dart';
import '../../core/system_permissions.dart';
import '../../core/theme.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/config_tab.dart';
import 'tabs/model_tab.dart';
import 'tabs/status_tab.dart';
import 'tabs/test_tab.dart';
import '../../core/i18n.dart';

enum SettingsTab { general, camera, ai, catalog, test }

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
  SettingsTab activeTab = SettingsTab.general;
  Timer? _refreshTimer;
  Timer? _shutdownTimeout;
  bool _shutdownInProgress = false;
  int _shutdownRequestStartedAt = 0;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  String _tabTitle(BuildContext context, SettingsTab tab) => switch (tab) {
    SettingsTab.general => I18n.t(context, 'tab_general'),
    SettingsTab.camera => I18n.t(context, 'tab_camera'),
    SettingsTab.ai => I18n.t(context, 'tab_ai'),
    SettingsTab.catalog => I18n.t(context, 'tab_catalog'),
    SettingsTab.test => I18n.t(context, 'tab_test'),
  };

  IconData _tabIcon(SettingsTab tab) => switch (tab) {
    SettingsTab.general => Icons.monitor_heart_outlined,
    SettingsTab.camera => Icons.camera_alt_outlined,
    SettingsTab.ai => Icons.psychology_outlined,
    SettingsTab.catalog => Icons.inventory_2_outlined,
    SettingsTab.test => Icons.science_outlined,
  };

  SettingsTab? activeTabForMobile;

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
                style: const TextStyle(fontWeight: FontWeight.w600),
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
    return ColoredBox(
      color: scheme.surface,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(
                right: BorderSide(color: BeenutTheme.outlineVariant(context)),
              ),
            ),
            child: SizedBox(
              width: 232,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 16, 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: widget.onClose,
                          tooltip: I18n.t(context, 'back_to_kiosk'),
                          icon: const Icon(Icons.arrow_back, size: 20),
                          style: IconButton.styleFrom(
                            foregroundColor: scheme.onSurface,
                            minimumSize: const Size(44, 44),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            I18n.t(context, 'settings_title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  Expanded(
                    child: Scrollbar(
                      child: ListView(
                        primary: false,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        children: [
                          for (final tab in SettingsTab.values)
                            SidebarDestination(
                              selected: activeTab == tab,
                              icon: _tabIcon(tab),
                              title: _tabTitle(context, tab),
                              onPressed: () => setState(() {
                                activeTab = tab;
                                activeTabForMobile = tab;
                              }),
                            ),
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
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
                      child: _buildTabContent(activeTab, config, state),
                    ),
                  ),
                ),
              ],
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
    final currentTab = activeTabForMobile;
    final scheme = Theme.of(context).colorScheme;
    final canPoweroff = widget.snapshot.capabilities.canPoweroff;
    if (currentTab == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        body: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: SettingsTab.values.length + (canPoweroff ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (canPoweroff && index == SettingsTab.values.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SidebarShutdownButton(
                  onPressed: () => _showShutdownConfirmDialog(context),
                ),
              );
            }
            final tab = SettingsTab.values[index];
            return SettingsNavButton(
              selected: false,
              icon: _tabIcon(tab),
              title: _tabTitle(context, tab),
              onPressed: () => setState(() {
                activeTab = tab;
                activeTabForMobile = tab;
              }),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: scheme.onSurface,
            size: 18,
          ),
          onPressed: () => setState(() => activeTabForMobile = null),
        ),
        title: Text(
          _tabTitle(context, currentTab),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        children: [_buildTabContent(currentTab, config, state)],
      ),
    );
  }

  Widget _buildTabContent(
    SettingsTab tab,
    MachineConfig config,
    MachineState state,
  ) {
    switch (tab) {
      case SettingsTab.general:
        return StatusSettingsTab(
          key: ValueKey(tab),
          config: config,
          snapshot: widget.snapshot,
          cameraPermission: widget.cameraPermission,
          onRefreshCameraPermission: widget.onRefreshCameraPermission,
          onRefreshCapabilities: widget.client.refreshCapabilities,
          onSave: widget.client.saveConfig,
          enabled: true,
        );
      case SettingsTab.camera:
        return ConfigEditor(
          key: ValueKey(tab),
          config: config,
          capabilities: widget.snapshot.capabilities,
          enabled: true,
          onSave: widget.client.saveConfig,
        );
      case SettingsTab.ai:
        return ModelSettingsTab(
          key: ValueKey(tab),
          config: config,
          state: state,
          capabilities: widget.snapshot.capabilities,
          enabled: true,
          onSave: widget.client.saveConfig,
        );
      case SettingsTab.catalog:
        return Column(
          key: ValueKey(tab),
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
      case SettingsTab.test:
        return HardwareTestTab(
          key: ValueKey(tab),
          state: state,
          diagnostic: widget.snapshot.diagnostic,
          client: widget.client,
        );
    }
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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      borderRadius: BeenutTheme.radiusSharp,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BeenutTheme.radiusSharp,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurface,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ],
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BeenutTheme.radiusSharp,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BeenutTheme.radiusSharp,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
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

class SidebarShutdownButton extends StatelessWidget {
  const SidebarShutdownButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = I18n.t(context, 'shutdown_btn');
    return Tooltip(
      message: label,
      child: Material(
        color: scheme.errorContainer.withValues(alpha: 0.48),
        borderRadius: BeenutTheme.radiusSharp,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BeenutTheme.radiusSharp,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  Icons.power_settings_new,
                  size: 20,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onErrorContainer,
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
                      fontWeight: FontWeight.w700,
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
