import 'package:beenut/core/i18n.dart';
import 'package:beenut/core/models.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/common/setting_controls.dart';
import 'package:beenut/ui/common/setting_rows.dart';
import 'package:beenut/ui/kiosk/preview_pane.dart';
import 'package:beenut/ui/settings/settings_page.dart';
import 'package:beenut/ui/settings/widgets/target_edit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => I18n.updateFromConfig(MachineConfig.empty));
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1200, 800),
    SettingsTask? task,
    MachineSection section = MachineSection.model,
    MachineSnapshot? snapshot,
    KioskServiceClient? client,
    VoidCallback? close,
    ValueNotifier<MachineSnapshot>? live,
    bool dark = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SettingsPage page(MachineSnapshot snapshot) => SettingsPage(
      snapshot: snapshot,
      client: client ?? _FakeClient(),
      cameraPermission: CameraPermissionStatus.authorized,
      onRefreshCameraPermission: () async {},
      onClose: close ?? () {},
      initialTask: task,
      initialSection: section,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? BeenutTheme.dark : BeenutTheme.light,
        home: Scaffold(
          body: live == null
              ? page(snapshot ?? _snapshot)
              : ValueListenableBuilder(
                  valueListenable: live,
                  builder: (_, value, _) => page(value),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(1200, 800),
    const Size(800, 480),
    const Size(500, 700),
  ]) {
    testWidgets('task navigation has one toolbar at $size', (tester) async {
      await mount(tester, size: size, dark: true);
      expect(find.byType(SettingsNavButton), findsNWidgets(4));
      expect(find.text('Basic'), findsNothing);
      expect(find.text('Developer'), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('settings-toolbar'))).height,
        56,
      );
      expect(find.byType(AppBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('system back returns from a task before closing settings', (
    tester,
  ) async {
    var closed = 0;
    await mount(tester, size: const Size(500, 700), close: () => closed++);
    await tester.tap(find.byKey(const ValueKey('settings-task-display')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-content-display')),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsNavButton), findsNWidgets(4));
    expect(closed, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(closed, 1);
  });
  testWidgets(
    'camera task includes live preview and hides technical controls',
    (tester) async {
      final snapshot = _snapshot.copyWith(
        capabilities: _snapshot.capabilities.copyWith(
          cameras: [
            {'name': 'Tray camera', 'source': 'v4l2', 'device': '/dev/video0'},
          ],
        ),
      );
      await mount(
        tester,
        size: const Size(800, 480),
        task: SettingsTask.camera,
        snapshot: snapshot,
      );
      expect(find.byType(NativePreviewPane), findsOneWidget);
      expect(find.text('Camera source'), findsNothing);
      expect(find.text('Resolution'), findsNothing);
      expect(find.text('Preview transport'), findsNothing);
      expect(find.text('Test pattern (Mock)'), findsNothing);
      expect(find.text('Flip Horizontal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('a working daemon camera does not ask for host permission', (
    tester,
  ) async {
    final live = _snapshot.copyWith(
      state: MachineState.empty.copyWith(
        camera: 'ready',
        previewCaps: 'video/x-raw,width=(int)480,height=(int)480',
      ),
    );
    await tester.binding.setSurfaceSize(const Size(800, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SettingsPage(
            snapshot: live,
            client: _FakeClient(),
            cameraPermission: CameraPermissionStatus.notDetermined,
            onRefreshCameraPermission: () async {},
            onClose: () {},
            initialTask: SettingsTask.camera,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request'), findsNothing);
    expect(find.byType(NativePreviewPane), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera choices and flips save live without an apply step', (
    tester,
  ) async {
    final live = ValueNotifier(
      _snapshot.copyWith(
        config: MachineConfig.empty.copyWithUiSettings(
          MachineConfig.empty.uiSettings.copyWith(theme: 'dark'),
        ),
        capabilities: _snapshot.capabilities.copyWith(
          cameras: [
            {'name': 'Tray camera', 'source': 'v4l2', 'device': '/dev/video0'},
            {'name': 'USB camera', 'source': 'v4l2', 'device': '/dev/video1'},
          ],
        ),
      ),
    );
    addTearDown(live.dispose);
    final client = _LiveCameraClient(live);
    await mount(tester, task: SettingsTask.camera, live: live, client: client);
    await tester.tap(find.text('Tray camera'));
    await tester.pump();
    expect(client.saved.single.cameraSettings.device, '/dev/video0');
    Finder flip(String label) => find.descendant(
      of: find.widgetWithText(SwitchSettingRow, label),
      matching: find.byType(WorkbenchSwitch),
    );
    await tester.tap(flip('Flip Horizontal'));
    await tester.pump();
    await tester.tap(flip('Flip Vertical'));
    await tester.pumpAndSettle();
    expect(client.saved, hasLength(3));
    expect(client.saved.last.cameraSettings.flipHorizontal, isTrue);
    expect(client.saved.last.cameraSettings.flipVertical, isTrue);
    expect(client.saved.last.cameraSettings.device, '/dev/video0');
    expect(client.saved.last.uiSettings.theme, 'dark');
    expect(find.byType(NativePreviewPane), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-apply-bar')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsNavButton), findsNWidgets(4));
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rejected live camera saves restore controls and show the error',
    (tester) async {
      final live = ValueNotifier(_snapshot);
      addTearDown(live.dispose);
      final client = _LiveCameraClient(live);
      await mount(
        tester,
        task: SettingsTask.camera,
        live: live,
        client: client,
      );
      final horizontal = find.descendant(
        of: find.widgetWithText(SwitchSettingRow, 'Flip Horizontal'),
        matching: find.byType(WorkbenchSwitch),
      );
      await tester.tap(horizontal);
      await tester.pump();
      expect(tester.widget<WorkbenchSwitch>(horizontal).value, isTrue);
      live.value = live.value.copyWith(
        config: _snapshot.config,
        saveResult: const ConfigSaveResult(
          ok: false,
          message: 'Camera settings rejected',
          detail: '',
          timestampMs: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<WorkbenchSwitch>(horizontal).value, isFalse);
      expect(find.text('Camera settings rejected'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-apply-bar')), findsNothing);
      live.value = live.value.copyWith(connected: false);
      await tester.pumpAndSettle();
      expect(tester.widget<WorkbenchSwitch>(horizontal).onChanged, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'machine workspace uses the form area and changes sections without a monitor',
    (tester) async {
      await mount(tester, task: SettingsTask.machine);
      expect(find.byType(SidebarDestination), findsNWidgets(5));
      expect(find.byType(NativePreviewPane), findsNothing);
      expect(find.byKey(const ValueKey('settings-live-metrics')), findsNothing);
      expect(
        find.byKey(const ValueKey('settings-preview-toggle')),
        findsNothing,
      );
      await tester.tap(
        find.widgetWithText(SidebarDestination, 'Detection and counting'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confidence'), findsOneWidget);
      expect(find.text('Count trigger'), findsNothing);
      expect(find.text('Counting behavior'), findsOneWidget);
      await tester.tap(find.widgetWithText(SidebarDestination, 'Performance'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('setting-number-Max inference FPS')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setting-number-Camera frame rate')),
        findsOneWidget,
      );
      expect(find.text('Confidence'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('compact machine section picker leaves the space for controls', (
    tester,
  ) async {
    await mount(tester, size: const Size(800, 480), task: SettingsTask.machine);
    expect(find.byType(NativePreviewPane), findsNothing);
    expect(find.byKey(const ValueKey('settings-preview-toggle')), findsNothing);
    expect(find.byKey(const ValueKey('settings-live-metrics')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-machine-section')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Performance').last);
    await tester.pumpAndSettle();
    expect(find.text('AI processing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'worker edits names without class mapping and saves the job once',
    (tester) async {
      final client = _RecordingClient();
      final config = MachineConfig.empty.copyWithPartCatalog(
        partTypes: [
          const PartType(
            id: 'job',
            name: 'Fasteners',
            image: '',
            keywords: ['washer_m6'],
            enabled: true,
            classNames: {'washer_m6': 'Washer M6'},
          ),
        ],
        selectedPartType: 'job',
      );
      final live = ValueNotifier(_snapshot.copyWith(config: config));
      addTearDown(live.dispose);
      await mount(tester, task: SettingsTask.jobs, live: live, client: client);
      expect(find.text('washer_m6'), findsNothing);
      expect(find.text('Washer M6'), findsOneWidget);
      await tester.tap(find.text('Fasteners'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-class')), findsNothing);
      expect(
        find.byKey(const ValueKey('remove-class-washer_m6')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('target-name')),
        'M6 kit',
      );
      await tester.tap(find.byKey(const ValueKey('target-save')));
      await tester.pumpAndSettle();
      expect(client.saved, hasLength(1));
      expect(client.saved.single.partTypes.single.name, 'M6 kit');
      expect(client.saved.single.partTypes.single.keywords, ['washer_m6']);
      live.value = live.value.copyWith(
        config: client.saved.single,
        saveResult: const ConfigSaveResult(
          ok: true,
          message: '',
          detail: '',
          timestampMs: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-apply-bar')), findsNothing);
      expect(find.byType(TargetEditDialog), findsNothing);
    },
  );
  testWidgets(
    'leaving a dirty task offers save and preserves it after a rejection',
    (tester) async {
      final client = _RecordingClient();
      final live = ValueNotifier(_snapshot);
      addTearDown(live.dispose);
      await mount(
        tester,
        task: SettingsTask.display,
        live: live,
        client: client,
      );
      final scaleRow = find.ancestor(
        of: find.text('UI Scale'),
        matching: find.byType(StepperSettingRow),
      );
      await tester.tap(
        find.descendant(of: scaleRow, matching: find.byIcon(Icons.add)),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('settings-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pump();
      expect(client.saved, hasLength(1));
      live.value = _snapshot.copyWith(
        saveResult: const ConfigSaveResult(
          ok: false,
          message: 'Rejected',
          detail: '',
          timestampMs: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-content-display')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('settings-apply-bar')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Discard').last);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsNavButton), findsNWidgets(4));
      await tester.tap(find.byKey(const ValueKey('settings-task-machine')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-apply-bar')), findsNothing);
    },
  );
  testWidgets(
    'poweroff stays visible on a short touch screen and requires confirmation',
    (tester) async {
      final client = _RecordingClient();
      var closed = 0;
      final live = ValueNotifier(_snapshot);
      addTearDown(live.dispose);
      await mount(
        tester,
        size: const Size(800, 400),
        live: live,
        client: client,
        close: () => closed++,
      );
      final power = find.byKey(const ValueKey('settings-shutdown'));
      final button = find.descendant(
        of: power,
        matching: find.byType(OutlinedButton),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(56));
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(400));
      await tester.tap(power);
      await tester.pumpAndSettle();
      expect(client.shutdownCalls, 0);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(client.shutdownCalls, 0);
      await tester.tap(power);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Shutdown'));
      await tester.pump();
      expect(client.shutdownCalls, 1);
      expect(find.text('Shutting down'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(closed, 0);
      live.value = live.value.copyWith(
        diagnostic: DiagnosticEvent(
          target: 'shutdown',
          ok: true,
          message: 'Accepted',
          detail: '',
          metrics: const {},
          timestampMs: DateTime.now().millisecondsSinceEpoch + 1,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));
      expect(find.text('Shutting down'), findsOneWidget);
      expect(find.text('System shutdown is not permitted.'), findsNothing);
    },
  );
  testWidgets(
    'poweroff is hidden when unavailable and disabled while disconnected',
    (tester) async {
      await mount(
        tester,
        snapshot: _snapshot.copyWith(capabilities: HardwareCapabilities.empty),
      );
      expect(find.byKey(const ValueKey('settings-shutdown')), findsNothing);
      await mount(tester, snapshot: _snapshot.copyWith(connected: false));
      final button = find.descendant(
        of: find.byKey(const ValueKey('settings-shutdown')),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    },
  );
  testWidgets('missing poweroff acknowledgement restores controls for retry', (
    tester,
  ) async {
    final client = _RecordingClient();
    await mount(tester, client: client);
    final power = find.byKey(const ValueKey('settings-shutdown'));
    await tester.tap(power);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Shutdown'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('Shutting down'), findsNothing);
    expect(find.text('No shutdown response. Try again.'), findsOneWidget);
    await tester.tap(power);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Shutdown'));
    await tester.pump();
    expect(client.shutdownCalls, 2);
  });
  testWidgets('shutdown denial restores operator controls', (tester) async {
    final live = ValueNotifier(_snapshot);
    addTearDown(live.dispose);
    await mount(tester, live: live, client: _ShutdownFailingClient(live));
    await tester.ensureVisible(find.byType(SidebarShutdownButton));
    await tester.tap(find.byType(SidebarShutdownButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Shutdown'));
    await tester.pumpAndSettle();
    expect(find.text('System shutdown is not permitted.'), findsOneWidget);
    expect(find.byType(SidebarShutdownButton), findsOneWidget);
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

class _RecordingClient extends _FakeClient {
  final saved = <MachineConfig>[];
  int shutdownCalls = 0;
  @override
  void shutdown() => shutdownCalls++;
  @override
  void saveConfig(MachineConfig config) => saved.add(config);
}

class _LiveCameraClient extends _RecordingClient {
  _LiveCameraClient(this.live);
  final ValueNotifier<MachineSnapshot> live;
  @override
  MachineSnapshot get snapshot => live.value;
  @override
  void saveConfig(MachineConfig config) {
    super.saveConfig(config);
    live.value = live.value.copyWith(config: config);
  }
}

class _FakeClient extends KioskServiceClient {
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
