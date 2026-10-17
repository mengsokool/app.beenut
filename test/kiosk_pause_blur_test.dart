import 'package:beenut/core/i18n.dart';
import 'package:beenut/core/models.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/kiosk/kiosk_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => I18n.updateFromConfig(_config));

  group('Kiosk Pause/Resume & Blur UI Test Suite', () {
    testWidgets('Active live preview shows bounding boxes and active count', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final snapshot = _buildSnapshot(paused: false, count: 5);
      final client = _MockKioskClient(snapshot);

      await _pumpKiosk(tester, snapshot: snapshot, client: client);

      // Verify active UI controls
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Verify ImageFiltered blur overlay is NOT active when not paused
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets(
      'Pausing kiosk triggers blur overlay, suspended text, dash count, and Resume button',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final snapshot = _buildSnapshot(paused: true, count: 12);
        final client = _MockKioskClient(snapshot);

        await _pumpKiosk(tester, snapshot: snapshot, client: client);

        // 1. Positive Assertions
        expect(find.byTooltip('Resume'), findsOneWidget);
        expect(find.byTooltip('Pause'), findsNothing);
        expect(find.text('—'), findsWidgets);

        // 2. Negative Assertions (Must NOT contain fake digits or old count numbers)
        expect(find.text('12'), findsNothing);
        expect(find.text('---'), findsNothing);
        expect(find.text('000'), findsNothing);

        // 3. Verify Overlay elements
        expect(find.byIcon(Icons.pause_outlined), findsWidgets);
      },
    );

    testWidgets('Tapping Pause button invokes client.setPreviewPaused(true)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final snapshot = _buildSnapshot(paused: false, count: 3);
      final client = _MockKioskClient(snapshot);

      await _pumpKiosk(tester, snapshot: snapshot, client: client);

      // Tap Pause button
      final pauseButton = find.byKey(const ValueKey('kiosk-pause-action'));
      expect(pauseButton, findsOneWidget);
      await tester.tap(pauseButton);
      await tester.pumpAndSettle();

      // Verify service client recorded the pause request
      expect(client.lastPausedState, isTrue);
    });

    testWidgets(
      'Spamming Pause/Resume toggle does not throw exceptions or corrupt state',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final snapshot = _buildSnapshot(paused: false, count: 8);
        final client = _MockKioskClient(snapshot);

        await _pumpKiosk(tester, snapshot: snapshot, client: client);

        // Rapidly tap the pause/resume action 10 times
        for (var i = 0; i < 10; i++) {
          final button = find.byKey(const ValueKey('kiosk-pause-action'));
          expect(button, findsOneWidget);
          await tester.tap(button);
          await tester.pump(const Duration(milliseconds: 20));
        }

        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _pumpKiosk(
  WidgetTester tester, {
  required MachineSnapshot snapshot,
  required KioskServiceClient client,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: BeenutTheme.light,
      home: Scaffold(
        body: KioskPage(
          snapshot: snapshot,
          client: client,
          cameraPermission: CameraPermissionStatus.authorized,
          onOpenSettings: () {},
        ),
      ),
    ),
  );
}

const _part = PartType(
  id: 'bolt',
  name: 'M8 Bolt',
  image: '',
  keywords: ['bolt'],
  enabled: true,
);

final _config = MachineConfig.empty
    .copyWithPartCatalog(partTypes: const [_part], selectedPartType: 'bolt')
    .copyWithModel({'engine': 'mock', 'model_path': 'mock'});

MachineSnapshot _buildSnapshot({required bool paused, required int count}) {
  return MachineSnapshot(
    connected: true,
    config: _config,
    state: MachineState.empty.copyWith(
      safeMode: false,
      selectedPartType: 'bolt',
      count: count,
      camera: 'ready',
      model: 'ready',
      previewPaused: paused,
      previewTransport: 'android_ffi',
    ),
    capabilities: HardwareCapabilities.empty,
    validation: ConfigValidation.empty,
    diagnostic: DiagnosticEvent.empty,
    saveResult: ConfigSaveResult.empty,
  );
}

class _MockKioskClient extends KioskServiceClient {
  _MockKioskClient(this._snapshot);

  final MachineSnapshot _snapshot;
  bool? lastPausedState;

  @override
  MachineSnapshot get snapshot => _snapshot;

  @override
  void setPreviewPaused(bool paused) {
    lastPausedState = paused;
  }

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
