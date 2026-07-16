import 'package:beenut/core/models.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/core/workbench_tokens.dart';
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
    expect(
      find.byType(SettingsNavGroupLabel),
      findsNWidgets(SettingsDestinationGroup.values.length),
    );
    expect(find.byType(SidebarShutdownButton), findsOneWidget);
    expect(find.byType(SettingsNavButton), findsNothing);

    final constrainedBoxes = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .where(
          (box) => box.constraints.maxWidth == WorkbenchMetric.contentMaxWidth,
        );
    expect(constrainedBoxes, isNotEmpty);
    expect(find.byType(SettingsContentHeader), findsOneWidget);
    expect(
      find.text('Current system readiness and live device state.'),
      findsOneWidget,
    );
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
      findsNWidgets(SettingsDestination.values.length),
    );
    expect(find.text('Operation'), findsOneWidget);
    expect(find.text('Device'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.byType(SidebarShutdownButton), findsOneWidget);
  });

  testWidgets('settings compact layout opens a task destination', (
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

    await tester.tap(find.widgetWithText(SettingsNavButton, 'Counting'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsNavButton), findsNothing);
    expect(find.text('Counting'), findsOneWidget);
    expect(find.text('Count trigger'), findsOneWidget);
    expect(find.text('Counting behavior'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('successful config save is quiet and failure remains visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final snapshots = ValueNotifier<MachineSnapshot>(_snapshot);
    addTearDown(snapshots.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: ValueListenableBuilder<MachineSnapshot>(
          valueListenable: snapshots,
          builder: (context, snapshot, _) => Scaffold(
            body: SettingsPage(
              snapshot: snapshot,
              client: _FakeClient(),
              cameraPermission: CameraPermissionStatus.authorized,
              onRefreshCameraPermission: () async {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    snapshots.value = _snapshot.copyWith(
      saveResult: const ConfigSaveResult(
        ok: true,
        message: 'Config saved and applied',
        detail: '',
        timestampMs: 100,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Config saved and applied'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    snapshots.value = _snapshot.copyWith(
      saveResult: const ConfigSaveResult(
        ok: false,
        message: 'Unable to save configuration',
        detail: 'Backend rejected the update',
        timestampMs: 200,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Unable to save configuration'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 3),
    );
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

      expect(find.text('System health'), findsOneWidget);
      expect(find.text('Overview'), findsNWidgets(2));
      expect(find.text('Live device state'), findsOneWidget);
      expect(find.text('Display settings'), findsNothing);
      expect(find.text('Last detection count'), findsNothing);

      await tester.tap(find.text('Live device state'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Last detection count'), findsOneWidget);

      await tester.tap(find.widgetWithText(SidebarDestination, 'Model'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Advanced model tuning'), findsOneWidget);
      expect(find.text('Confidence'), findsNothing);

      await tester.tap(find.text('Advanced model tuning'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Confidence'), findsOneWidget);
    },
  );

  testWidgets('workbench desktop boundary remains overflow-free in dark mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.dark,
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

    expect(find.byType(SidebarDestination), findsWidgets);
    expect(find.byType(SettingsContentHeader), findsOneWidget);
    expect(tester.takeException(), isNull);

    final selectedMaterials = tester
        .widgetList<Material>(
          find.descendant(
            of: find.widgetWithText(SidebarDestination, 'Overview'),
            matching: find.byType(Material),
          ),
        )
        .where((material) => material.color == WorkbenchColors.dark.actionSoft);
    expect(selectedMaterials, isNotEmpty);
  });

  testWidgets('service separates checks, controls, and maintenance', (
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
    await tester.tap(find.widgetWithText(SidebarDestination, 'Service'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Quick checks'), findsOneWidget);
    expect(find.text('Test camera'), findsOneWidget);
    expect(find.text('Manual controls'), findsOneWidget);
    expect(find.text('Service & maintenance'), findsOneWidget);
    expect(find.text('Turn Light On'), findsNothing);
    expect(find.text('Factory reset'), findsNothing);

    await tester.tap(find.text('Manual controls'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Turn Light On'), findsOneWidget);

    await tester.tap(find.text('Service & maintenance'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Factory reset'), findsOneWidget);
  });

  testWidgets(
    'settings destinations follow task-based information architecture',
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

      await tester.tap(find.widgetWithText(SidebarDestination, 'Counting'));
      await tester.pumpAndSettle();
      expect(find.text('Count trigger'), findsOneWidget);
      expect(find.text('Counting behavior'), findsOneWidget);
      expect(find.text('Camera basics'), findsNothing);
      expect(find.text('GPIO mapping'), findsNothing);

      await tester.tap(find.widgetWithText(SidebarDestination, 'Camera'));
      await tester.pumpAndSettle();
      expect(find.text('Camera basics'), findsOneWidget);
      expect(find.text('Camera pipeline'), findsOneWidget);
      expect(find.text('Count trigger'), findsNothing);

      await tester.tap(find.widgetWithText(SidebarDestination, 'Hardware'));
      await tester.pumpAndSettle();
      expect(find.text('Hardware I/O'), findsWidgets);
      expect(find.text('Camera basics'), findsNothing);

      await tester.tap(find.widgetWithText(SidebarDestination, 'Interface'));
      await tester.pumpAndSettle();
      expect(find.text('Display settings'), findsOneWidget);
      expect(find.text('System Health'), findsNothing);

      await tester.tap(find.widgetWithText(SidebarDestination, 'Service'));
      await tester.pumpAndSettle();
      expect(find.text('Quick checks'), findsOneWidget);
      expect(find.text('Performance history'), findsOneWidget);
      expect(find.text('Technical details'), findsOneWidget);
      expect(find.text('Safety & fallback'), findsOneWidget);
    },
  );
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
