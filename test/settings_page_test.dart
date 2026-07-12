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

  testWidgets('settings hides shutdown when daemon cannot power off', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SettingsPage(
            snapshot: _snapshot.copyWith(
              capabilities: HardwareCapabilities.empty,
            ),
            client: _FakeClient(),
            cameraPermission: CameraPermissionStatus.authorized,
            onRefreshCameraPermission: () async {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.byType(SidebarShutdownButton), findsNothing);
  });

  testWidgets('shutdown failure closes overlay and shows permission error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final snapshots = ValueNotifier<MachineSnapshot>(_snapshot);
    addTearDown(snapshots.dispose);
    final client = _ShutdownFailingClient(snapshots);

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: ValueListenableBuilder<MachineSnapshot>(
          valueListenable: snapshots,
          builder: (context, snapshot, _) => Scaffold(
            body: SettingsPage(
              snapshot: snapshot,
              client: client,
              cameraPermission: CameraPermissionStatus.authorized,
              onRefreshCameraPermission: () async {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SidebarShutdownButton));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Shutdown'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Shutting down'), findsNothing);
    expect(find.text('System shutdown is not permitted.'), findsOneWidget);
  });

  testWidgets('settings desktop sidebar destinations remain scrollable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 360));
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

    final sidebarListViews = tester
        .widgetList<ListView>(find.byType(ListView))
        .where((list) => list.physics is AlwaysScrollableScrollPhysics);

    expect(sidebarListViews, isNotEmpty);
  });

  testWidgets(
    'settings desktop starts with health and hides secondary detail',
    (tester) async {
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
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('System Health'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Live Device State'), findsOneWidget);
      expect(find.text('Last Detection Count'), findsNothing);

      await tester.tap(find.text('Live Device State'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Last Detection Count'), findsOneWidget);

      await tester.tap(find.byType(SidebarDestination).at(2));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Advanced Model Tuning'), findsOneWidget);
      expect(find.text('Confidence'), findsNothing);

      await tester.tap(find.text('Advanced Model Tuning'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Confidence'), findsOneWidget);
    },
  );

  testWidgets('diagnostics separates checks, controls, and maintenance', (
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
    await tester.tap(find.byType(SidebarDestination).at(4));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Quick Checks'), findsOneWidget);
    expect(find.text('Test Camera'), findsOneWidget);
    expect(find.text('Manual Controls'), findsOneWidget);
    expect(find.text('Service & Maintenance'), findsOneWidget);
    expect(find.text('Turn Light On'), findsNothing);
    expect(find.text('Factory Reset'), findsNothing);

    await tester.tap(find.text('Manual Controls'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Turn Light On'), findsOneWidget);

    await tester.tap(find.text('Service & Maintenance'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Factory Reset'), findsOneWidget);
  });
}

const _snapshot = MachineSnapshot(
  connected: true,
  config: MachineConfig.empty,
  state: MachineState.empty,
  capabilities: HardwareCapabilities(
    cameras: [],
    previewTransports: [],
    aiRuntimes: [],
    gpio: {},
    gstreamer: {},
    system: {},
    poweroff: {'available': true},
  ),
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

class _ShutdownFailingClient extends _FakeClient {
  _ShutdownFailingClient(this.snapshots);

  final ValueNotifier<MachineSnapshot> snapshots;

  @override
  MachineSnapshot get snapshot => snapshots.value;

  @override
  void shutdown() {
    snapshots.value = snapshots.value.copyWith(
      diagnostic: DiagnosticEvent(
        target: 'shutdown',
        ok: false,
        message: 'Unable to request system poweroff',
        detail: 'password is required',
        metrics: const {},
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
