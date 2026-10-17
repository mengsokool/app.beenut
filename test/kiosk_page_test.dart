import 'package:beenut/core/i18n.dart';
import 'package:beenut/core/models.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/kiosk/kiosk_page.dart';
import 'package:beenut/ui/kiosk/touch_workbench.dart';
import 'package:beenut/ui/kiosk/preview_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => I18n.updateFromConfig(_config));

  testWidgets('box labels use target names and refresh when renamed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<String?> labels() {
      final paint = find.descendant(
        of: find.byType(AnimatedDetectionsOverlay),
        matching: find.byType(CustomPaint),
      );
      return tester
          .widget<CustomPaint>(paint)
          .painter!
          .semanticsBuilder!(tester.getSize(paint))
          .map((entry) => entry.properties.label)
          .toList();
    }

    final snapshot = _readySnapshot.copyWith(
      state: _readySnapshot.state.copyWith(
        detections: const [
          Detection(
            label: 'washer',
            confidence: .93,
            x: .1,
            y: .1,
            w: .7,
            h: .7,
          ),
        ],
      ),
    );
    Future<void> render(Map<String, String> names) => _pumpKiosk(
      tester,
      snapshot: snapshot.copyWith(
        config: _config.copyWithPartCatalog(
          partTypes: [_part.copyWith(classNames: names)],
          selectedPartType: _part.id,
        ),
      ),
    );
    await render({'washer': 'แหวนรอง'});
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byType(AnimatedDetectionsOverlay));
    await tester.pump(const Duration(milliseconds: 250));
    expect(labels(), ['แหวนรอง 93%']);
    expect(labels(), isNot(contains('washer 93%')));
    await render({'washer': 'แหวนรอง M6'});
    await tester.pump(const Duration(milliseconds: 250));
    expect(labels(), ['แหวนรอง M6 93%']);
    await render({});
    await tester.pump(const Duration(milliseconds: 250));
    expect(labels(), ['washer 93%']);
  });

  testWidgets('wide kiosk prioritizes preview and natural count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKiosk(
      tester,
      snapshot: _readySnapshot.copyWith(
        state: _readySnapshot.state.copyWith(previewTransport: 'android_ffi'),
      ),
    );

    expect(find.byKey(const ValueKey('kiosk-settings-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('kiosk-pause-action')), findsOneWidget);
    expect(find.byTooltip('Shutdown'), findsNothing);
    expect(find.byTooltip('Select target'), findsOneWidget);
    expect(find.text('Washer'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('007'), findsNothing);
    expect(find.text('items'), findsOneWidget);

    final previewSize = tester.getSize(
      find.byKey(const ValueKey('kiosk-preview')),
    );
    final countSize = tester.getSize(find.byType(TouchWorkbench));
    expect(previewSize.width, greaterThan(countSize.width / 2));

    final pageRect = tester.getRect(find.byType(KioskPage));
    final previewRect = tester.getRect(
      find.byKey(const ValueKey('kiosk-preview')),
    );
    final railRect = tester.getRect(
      find.byKey(const ValueKey('kiosk-target-action')),
    );
    final leftGutter = previewRect.left - pageRect.left;
    final middleGutter = railRect.left - previewRect.right;
    final rightGutter = pageRect.right - railRect.right;
    expect(leftGutter, 8);
    expect(middleGutter, 8);
    expect(rightGutter, 8);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('kiosk-settings-action')))
          .height,
      56,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('kiosk-pause-action'))).height,
      56,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact kiosk keeps operator flow and stays overflow-free', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKiosk(
      tester,
      snapshot: _readySnapshot.copyWith(
        state: _readySnapshot.state.copyWith(previewTransport: 'android_ffi'),
      ),
    );

    final previewTop = tester.getTopLeft(
      find.byKey(const ValueKey('kiosk-preview')),
    );
    final selectorTop = tester.getTopLeft(
      find.byKey(const ValueKey('kiosk-target-action')),
    );
    final countTop = tester.getTopLeft(
      find.byKey(const ValueKey('kiosk-count-panel')),
    );
    final actionsTop = tester.getTopLeft(
      find.byKey(const ValueKey('kiosk-settings-action')),
    );

    expect(previewTop.dy, lessThan(selectorTop.dy));
    expect(selectorTop.dy, lessThan(countTop.dy));
    expect(countTop.dy, lessThan(actionsTop.dy));
    expect(find.text('7'), findsOneWidget);
    expect(find.text('007'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape phone keeps preview and controls side by side', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(853, 384));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKiosk(
      tester,
      snapshot: _readySnapshot.copyWith(
        state: _readySnapshot.state.copyWith(previewTransport: 'android_ffi'),
      ),
    );

    final preview = tester.getRect(find.byKey(const ValueKey('kiosk-preview')));
    final controls = tester.getRect(
      find.byKey(const ValueKey('kiosk-target-action')),
    );
    expect(preview.left, lessThan(controls.left));
    expect((preview.top - controls.top).abs(), lessThan(1));
    expect(preview.width / preview.height, closeTo(1.0, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused kiosk emphasizes resume without fake count digits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKiosk(
      tester,
      snapshot: _readySnapshot.copyWith(
        state: _readySnapshot.state.copyWith(previewPaused: true),
      ),
    );

    expect(find.text('Resume'), findsOneWidget);
    expect(find.byKey(const ValueKey('touch-attention-title')), findsNothing);
    expect(find.text('—'), findsNothing);
    expect(find.byKey(const ValueKey('touch-count-value')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch workbench keeps healthy state nearly text free', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKiosk(
      tester,
      platform: TargetPlatform.macOS,
      snapshot: _readySnapshot,
    );

    expect(find.byType(TouchWorkbench), findsOneWidget);
    expect(find.text('Washer'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('items'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
    expect(find.text('Total Count'), findsNothing);
    expect(find.text('Breakdown by Class'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch workbench replaces count with actionable fault', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKiosk(
      tester,
      platform: TargetPlatform.macOS,
      snapshot: _readySnapshot.copyWith(
        state: _readySnapshot.state.copyWith(camera: 'error'),
      ),
    );

    expect(find.byKey(const ValueKey('touch-attention-title')), findsOneWidget);
    expect(find.text('Machine error'), findsOneWidget);
    expect(find.text('Diagnostic mode'), findsOneWidget);
    expect(find.byKey(const ValueKey('touch-count-value')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('800x480 touch layout keeps Thai controls usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    I18n.updateFromConfig(_config.copyWithUi({'language': 'th'}));

    await _pumpKiosk(tester, snapshot: _readySnapshot);

    expect(find.byType(TouchWorkbench), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('kiosk-target-action'))).height,
      greaterThanOrEqualTo(64),
    );
    for (final key in ['kiosk-settings-action', 'kiosk-pause-action']) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(56),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed result has a centered count without a status badge', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKiosk(
      tester,
      snapshot: _readySnapshot.copyWith(
        state: _readySnapshot.state.copyWith(trayPresent: true),
      ),
    );

    expect(find.text('Count complete'), findsNothing);
    final panel = tester.getRect(
      find.byKey(const ValueKey('kiosk-count-panel')),
    );
    final number = tester.getRect(
      find.byKey(const ValueKey('touch-count-value')),
    );
    expect((number.center.dx - panel.center.dx).abs(), lessThan(2));
    expect(number.top, greaterThan(panel.top));
    expect(number.bottom, lessThan(panel.bottom));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(800, 480), const Size(853, 384)]) {
    testWidgets('multi class names and counts stay visible at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mapped = _part.copyWith(
        keywords: ['washer_m6', 'nut_m3'],
        classNames: {'washer_m6': 'แหวนรอง M6', 'nut_m3': 'น็อต M3'},
      );
      Detection detection(String label) =>
          Detection(label: label, confidence: 1, x: 0, y: 0, w: .1, h: .1);
      await _pumpKiosk(
        tester,
        snapshot: _readySnapshot.copyWith(
          config: _config.copyWithPartCatalog(
            partTypes: [mapped],
            selectedPartType: mapped.id,
          ),
          state: _readySnapshot.state.copyWith(
            trayPresent: true,
            detections: [
              for (var i = 0; i < 5; i++) detection('washer_m6'),
              for (var i = 0; i < 2; i++) detection('nut_m3'),
              detection('nut_m30'),
            ],
          ),
        ),
      );
      expect(find.text('แหวนรอง M6'), findsOneWidget);
      expect(find.text('น็อต M3'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('class-count-washer_m6')))
            .data,
        '5',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('class-count-nut_m3')))
            .data,
        '2',
      );
      final panel = tester.getRect(
        find.byKey(const ValueKey('kiosk-count-panel')),
      );
      for (final label in ['washer_m6', 'nut_m3']) {
        final number = tester.getRect(
          find.byKey(ValueKey('class-count-$label')),
        );
        expect(number.top, greaterThan(panel.top));
        expect(number.bottom, lessThan(panel.bottom));
      }
      expect(find.text('washer_m6'), findsNothing);
      expect(find.text('nut_m3'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpKiosk(
  WidgetTester tester, {
  required MachineSnapshot snapshot,
  TargetPlatform platform = TargetPlatform.android,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: BeenutTheme.light.copyWith(platform: platform),
      home: Scaffold(
        body: KioskPage(
          snapshot: snapshot,
          client: _FakeClient(snapshot),
          cameraPermission: CameraPermissionStatus.authorized,
          onOpenSettings: () {},
        ),
      ),
    ),
  );
}

const _part = PartType(
  id: 'washer',
  name: 'Washer',
  image: '',
  keywords: ['washer'],
  enabled: true,
);

final _config = MachineConfig.empty
    .copyWithPartCatalog(partTypes: const [_part], selectedPartType: 'washer')
    .copyWithModel({'engine': 'mock', 'model_path': 'mock'});

final _readySnapshot = MachineSnapshot(
  connected: true,
  config: _config,
  state: MachineState.empty.copyWith(
    safeMode: false,
    selectedPartType: 'washer',
    count: 7,
    camera: 'ready',
    model: 'ready',
  ),
  capabilities: HardwareCapabilities.empty,
  validation: ConfigValidation.empty,
  diagnostic: DiagnosticEvent.empty,
  saveResult: ConfigSaveResult.empty,
);

class _FakeClient extends KioskServiceClient {
  _FakeClient(this._snapshot);

  final MachineSnapshot _snapshot;

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
