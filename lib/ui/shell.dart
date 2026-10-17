import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/android_camera_controller.dart';
import '../core/android_ffi_service_client.dart';
import '../core/service_client.dart';
import '../core/system_permissions.dart';
import '../core/ui_scale.dart';
import '../core/theme_controller.dart';
import 'kiosk/kiosk_page.dart';
import 'kiosk/splash_page.dart';
import 'settings/settings_page.dart';

class BeenutShell extends StatefulWidget {
  const BeenutShell({
    super.key,
    required this.cameraPermission,
    this.clientOverride,
  });

  final CameraPermissionStatus cameraPermission;
  final KioskServiceClient? clientOverride;

  @override
  State<BeenutShell> createState() => _BeenutShellState();
}

class _BeenutShellState extends State<BeenutShell> with WidgetsBindingObserver {
  late final KioskServiceClient client;
  AndroidCameraController? cameraController;
  bool settingsOpen = false;
  String? _lastSyncedMode;
  late CameraPermissionStatus _cameraPermission;
  Timer? _splashTimeoutTimer;
  bool _splashTimedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraPermission = widget.cameraPermission;
    client = widget.clientOverride ?? (createServiceClient()..start());
    if (client is AndroidFfiServiceClient) {
      cameraController = AndroidCameraController(
        client: client as AndroidFfiServiceClient,
      )..start();
    }
    client.addListener(_syncClientState);
    _syncUiScale();
    if (!client.snapshot.connected) {
      _splashTimeoutTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !client.snapshot.connected) {
          if (!_dismissedNativeSplash) {
            _dismissedNativeSplash = true;
            const MethodChannel(
              'beenut/splash',
            ).invokeMethod<void>('appReady').catchError((_) {});
          }
          setState(() {
            _splashTimedOut = true;
          });
        }
      });
    }
  }

  Future<void> _refreshCameraPermission() async {
    var next = await SystemPermissions.currentCameraStatus();
    if (next == CameraPermissionStatus.notDetermined ||
        next == CameraPermissionStatus.unknown) {
      next = await SystemPermissions.requestCameraIfNeeded();
    }
    if (!mounted) return;
    setState(() {
      _cameraPermission = next;
    });
    if (next == CameraPermissionStatus.authorized) {
      await cameraController?.ensureInitialized();
    }
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
    _splashTimeoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    client.removeListener(_syncClientState);
    cameraController?.dispose();
    UiScaleController.update(1.0);
    if (widget.clientOverride == null) {
      client.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _readCameraPermission();
    }
  }

  bool _lastConnected = false;
  bool _dismissedNativeSplash = false;

  void _syncClientState() {
    _syncTriggerMode();
    _syncUiScale();
    _syncTheme();
    final connected = client.snapshot.connected;
    if (connected) {
      _splashTimeoutTimer?.cancel();
    }
    if (connected && !_dismissedNativeSplash) {
      _dismissedNativeSplash = true;
      const MethodChannel(
        'beenut/splash',
      ).invokeMethod<void>('appReady').catchError((_) {});
    }
    if (connected != _lastConnected) {
      _lastConnected = connected;
      if (mounted) {
        setState(() {});
      }
    }
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
    final connected = client.snapshot.connected;
    final showSplash = !connected && !_splashTimedOut;
    final transitionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return PopScope<Object>(
      key: const ValueKey('shell-pop-scope'),
      canPop: !settingsOpen,
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: transitionDuration,
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
                  return Stack(fit: StackFit.expand, children: children);
                },
            child: showSplash
                ? (Platform.isAndroid
                      ? const SizedBox.shrink(key: ValueKey('splash'))
                      : const SplashPage(key: ValueKey('splash')))
                : settingsOpen
                ? AnimatedBuilder(
                    key: const ValueKey('settings'),
                    animation: client,
                    builder: (context, _) => SettingsPage(
                      cameraController: cameraController,
                      snapshot: client.snapshot,
                      client: client,
                      cameraPermission: _cameraPermission,
                      onRefreshCameraPermission: _refreshCameraPermission,
                      onClose: () => setState(() => settingsOpen = false),
                    ),
                  )
                : AnimatedBuilder(
                    key: const ValueKey('kiosk'),
                    animation: client,
                    builder: (context, _) => KioskPage(
                      snapshot: client.snapshot,
                      client: client,
                      cameraController: cameraController,
                      cameraPermission: _cameraPermission,
                      onOpenSettings: () {
                        _readCameraPermission();
                        setState(() => settingsOpen = true);
                      },
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
