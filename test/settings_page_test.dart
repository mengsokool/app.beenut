import 'package:beenut/core/models.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings desktop uses rail navigation and constrained content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SettingsPage(
            snapshot: _snapshot,
            client: _FakeClient(),
            cameraPermission: CameraPermissionStatus.authorized,
            onRefreshCameraPermission: () async {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.byType(SidebarDestination), findsAtLeast(1));
    expect(find.byType(SidebarShutdownButton), findsOneWidget);
    expect(find.byType(SettingsNavButton), findsNothing);

    final constrainedBoxes = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .where((box) => box.constraints.maxWidth == 960);
    expect(constrainedBoxes, isNotEmpty);
  });

  testWidgets('settings compact layout starts with destination list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SettingsPage(
            snapshot: _snapshot,
            client: _FakeClient(),
            cameraPermission: CameraPermissionStatus.authorized,
            onRefreshCameraPermission: () async {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.byType(SidebarDestination), findsNothing);
    expect(
      find.byType(SettingsNavButton),
      findsNWidgets(SettingsTab.values.length),
    );
    expect(find.byType(SidebarShutdownButton), findsOneWidget);
  });
}

const _snapshot = MachineSnapshot(
  connected: true,
  config: MachineConfig.empty,
  state: MachineState.empty,
  capabilities: HardwareCapabilities.empty,
  validation: ConfigValidation.empty,
  diagnostic: DiagnosticEvent.empty,
  saveResult: ConfigSaveResult.empty,
);

class _FakeClient implements KioskServiceClient {
  @override
  MachineSnapshot get snapshot => _snapshot;

  @override
  void countOnce() {}

  @override
  void refreshCapabilities() {}

  @override
  void runDiagnostic(String target) {}

  @override
  void saveConfig(MachineConfig config) {}

  @override
  void selectPartType(String partType) {}

  @override
  void setPreviewPaused(bool paused) {}

  @override
  void shutdown() {}

  @override
  void start() {}

  @override
  void testLight(bool enabled) {}

  @override
  void testTray(bool? present) {}

  @override
  void validateConfig(MachineConfig config) {}
}
