import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/daemon_manager.dart';
import 'core/system_permissions.dart';
import 'core/theme.dart';
import 'core/ui_scale.dart';
import 'ui/shell.dart';

import 'core/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameraPermission = await SystemPermissions.currentCameraStatus();
  await DaemonManager.start();
  runApp(BeenutApp(cameraPermission: cameraPermission));
}

class BeenutApp extends StatefulWidget {
  const BeenutApp({
    super.key,
    this.cameraPermission = CameraPermissionStatus.unknown,
  });

  final CameraPermissionStatus cameraPermission;

  @override
  State<BeenutApp> createState() => _BeenutAppState();
}

class _BeenutAppState extends State<BeenutApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemeController.themeMode.addListener(_updateSystemTitleBarTheme);
    // Call once initially to align on boot
    _updateSystemTitleBarTheme();
  }

  @override
  void dispose() {
    ThemeController.themeMode.removeListener(_updateSystemTitleBarTheme);
    WidgetsBinding.instance.removeObserver(this);
    DaemonManager.stop();
    super.dispose();
  }

  void _updateSystemTitleBarTheme() {
    final mode = ThemeController.themeMode.value;
    final themeStr = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    const MethodChannel('beenut/theme')
        .invokeMethod('updateTheme', themeStr)
        .catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      DaemonManager.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.themeMode,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'BeeNut',
          theme: BeenutTheme.light,
          darkTheme: BeenutTheme.dark,
          themeMode: ThemeController.themeMode.value,
          builder: (context, child) {
            return AnimatedBuilder(
              animation: UiScaleController.scale,
              builder: (context, _) => UiScaleScope(
                scale: UiScaleController.scale.value,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: BeenutShell(cameraPermission: widget.cameraPermission),
        );
      },
    );
  }
}
