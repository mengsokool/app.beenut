import 'package:flutter/material.dart';
import '../core/service_client.dart';
import '../core/system_permissions.dart';
import '../core/ui_scale.dart';
import '../core/theme_controller.dart';
import 'kiosk/kiosk_page.dart';
import 'kiosk/splash_page.dart';
import 'settings/settings_page.dart';

class BeenutShell extends StatefulWidget {
  const BeenutShell({super.key, required this.cameraPermission});

  final CameraPermissionStatus cameraPermission;

  @override
  State<BeenutShell> createState() => _BeenutShellState();
}

class _BeenutShellState extends State<BeenutShell> with WidgetsBindingObserver {
  late final ServiceClient client;
  bool settingsOpen = false;
  String? _lastSyncedMode;
  late CameraPermissionStatus _cameraPermission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraPermission = widget.cameraPermission;
    client = ServiceClient()..start();
    client.addListener(_syncClientState);
    _syncUiScale();
  }

  Future<void> _refreshCameraPermission() async {
    final next = await SystemPermissions.requestCameraIfNeeded();
    if (!mounted) return;
    setState(() {
      _cameraPermission = next;
    });
  }

  Future<void> _readCameraPermission() async {
    final next = await SystemPermissions.currentCameraStatus();
    if (!mounted) return;
    setState(() {
      _cameraPermission = next;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    client.removeListener(_syncClientState);
    UiScaleController.update(1.0);
    client.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _readCameraPermission();
    }
  }

  void _syncClientState() {
    _syncTriggerMode();
    _syncUiScale();
    _syncTheme();
  }

  void _syncUiScale() {
    final next = client.snapshot.connected
        ? client.snapshot.config.uiSettings.scale
        : 1.0;
    UiScaleController.update(next);
  }

  void _syncTheme() {
    if (!client.snapshot.connected) return;
    final theme = client.snapshot.config.uiSettings.theme;
    ThemeController.update(theme);
  }

  void _syncTriggerMode() {
    if (!client.snapshot.connected) return;
    final mode = client.snapshot.config.countingSettings.triggerMode;
    if (mode != _lastSyncedMode) {
      _lastSyncedMode = mode;
      if (mode == 'real_time') {
        client.testTray(true);
      } else {
        client.testTray(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: client,
      builder: (context, _) {
        final snapshot = client.snapshot;
        return Scaffold(
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                if (child.key == const ValueKey('settings')) {
                  final slideIn = Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(animation);
                  return SlideTransition(position: slideIn, child: child);
                } else {
                  final slideOut = Tween<Offset>(
                    begin: const Offset(-0.15, 0.0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slideOut, child: child),
                  );
                }
              },
              layoutBuilder:
                  (Widget? currentChild, List<Widget> previousChildren) {
                    final children = <Widget>[...previousChildren];
                    if (currentChild != null) {
                      children.add(currentChild);
                    }
                    children.sort((a, b) {
                      final aIsSettings = a.key == const ValueKey('settings');
                      final bIsSettings = b.key == const ValueKey('settings');
                      if (aIsSettings && !bIsSettings) return 1;
                      if (!aIsSettings && bIsSettings) return -1;
                      return 0;
                    });
                    return Stack(children: children);
                  },
              child: !snapshot.connected
                  ? const SplashPage(key: ValueKey('splash'))
                  : settingsOpen
                  ? SettingsPage(
                      key: const ValueKey('settings'),
                      snapshot: snapshot,
                      client: client,
                      cameraPermission: _cameraPermission,
                      onRefreshCameraPermission: _refreshCameraPermission,
                      onClose: () => setState(() => settingsOpen = false),
                    )
                  : KioskPage(
                      key: const ValueKey('kiosk'),
                      snapshot: snapshot,
                      client: client,
                      cameraPermission: _cameraPermission,
                      onOpenSettings: () => setState(() => settingsOpen = true),
                    ),
            ),
          ),
        );
      },
    );
  }
}
