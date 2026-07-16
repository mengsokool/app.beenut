import 'package:beenut/core/i18n.dart';
import 'package:beenut/core/models.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/core/workbench_tokens.dart';
import 'package:beenut/ui/kiosk/count_panel.dart';
import 'package:beenut/ui/kiosk/kiosk_page.dart';
import 'package:beenut/ui/kiosk/part_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => I18n.updateFromConfig(_config));

  testWidgets('wide kiosk prioritizes preview and natural count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKiosk(tester, snapshot: _readySnapshot);

    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byTooltip('Shutdown'), findsNothing);
    expect(find.text('Current target'), findsOneWidget);
    expect(find.text('Washer'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('007'), findsNothing);
    expect(find.text('items'), findsOneWidget);

    final previewSize = tester.getSize(
      find.byKey(const ValueKey('kiosk-preview')),
    );
    final countSize = tester.getSize(find.byType(CountPanel));
    expect(previewSize.width, greaterThan(countSize.width));

    final pageRect = tester.getRect(find.byType(KioskPage));
    final previewRect = tester.getRect(
      find.byKey(const ValueKey('kiosk-preview')),
    );
    final railRect = tester.getRect(find.byType(PartSelector));
    final leftGutter = previewRect.left - pageRect.left;
    final middleGutter = railRect.left - previewRect.right;
    final rightGutter = pageRect.right - railRect.right;
    expect(leftGutter, WorkbenchSpace.x3);
    expect(middleGutter, WorkbenchSpace.x3);
    expect(rightGutter, WorkbenchSpace.x3);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('kiosk-settings-action')))
          .height,
      WorkbenchMetric.operatorControlHeight,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('kiosk-pause-action'))).height,
      WorkbenchMetric.operatorControlHeight,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact kiosk keeps operator flow and stays overflow-free', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpKiosk(tester, snapshot: _readySnapshot);

    final previewTop = tester.getTopLeft(
      find.byKey(const ValueKey('kiosk-preview')),
    );
    final selectorTop = tester.getTopLeft(find.byType(PartSelector));
    final countTop = tester.getTopLeft(find.byType(CountPanel));
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

    expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(find.text('---'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpKiosk(
  WidgetTester tester, {
  required MachineSnapshot snapshot,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: BeenutTheme.light,
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

final _config = MachineConfig.empty.copyWithPartCatalog(
  partTypes: const [_part],
  selectedPartType: 'washer',
);

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

class _FakeClient implements KioskServiceClient {
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
