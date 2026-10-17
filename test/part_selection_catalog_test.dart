import 'package:beenut/core/i18n.dart';
import 'package:beenut/core/models.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/kiosk/kiosk_page.dart';
import 'package:beenut/ui/components/part_selector_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => I18n.updateFromConfig(_configWithParts));

  group('Part Selection & Catalog Test Suite', () {
    testWidgets('Part Selector presents selected part name and opens menu', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final snapshot = _buildSnapshot(
        config: _configWithParts,
        selectedPart: 'washer',
      );
      final client = _MockKioskClient(snapshot);

      await _pumpKiosk(tester, snapshot: snapshot, client: client);

      // The full target row is a touch target on the counting screen.
      expect(find.byKey(const ValueKey('kiosk-target-action')), findsOneWidget);
      expect(find.text('Washer'), findsOneWidget);

      // Open menu
      await tester.tap(find.byKey(const ValueKey('kiosk-target-action')));
      await tester.pumpAndSettle();

      // Verify menu items inside popup
      expect(find.text('Hex Nut'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Multi-Class'), findsNothing);
      expect(find.byType(PartCatalogSelector), findsNothing);
      final items = find.byType(PopupMenuItem<PartType>);
      expect(items, findsNWidgets(2));
      final target = tester.getRect(
        find.byKey(const ValueKey('kiosk-target-action')),
      );
      final firstItem = tester.getRect(items.first);
      expect(firstItem.top, greaterThanOrEqualTo(target.bottom));
      expect(firstItem.left, closeTo(target.left, 1));
      expect(firstItem.width, closeTo(target.width, 1));
      expect(firstItem.height, greaterThanOrEqualTo(64));
    });

    testWidgets('Selecting a part triggers client.selectPartType()', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final snapshot = _buildSnapshot(
        config: _configWithParts,
        selectedPart: 'washer',
      );
      final client = _MockKioskClient(snapshot);

      await _pumpKiosk(tester, snapshot: snapshot, client: client);

      // Open Part Selector menu
      await tester.tap(find.byKey(const ValueKey('kiosk-target-action')));
      await tester.pumpAndSettle();

      // Tap on Hex Nut option
      final hexNutItem = find.text('Hex Nut');
      expect(hexNutItem, findsOneWidget);
      await tester.tap(hexNutItem);
      await tester.pumpAndSettle();

      expect(client.lastSelectedPartType, equals('hex_nut'));
    });

    testWidgets('Empty catalog displays clear setup prompt without crashes', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final emptyConfig = MachineConfig.empty;
      final snapshot = _buildSnapshot(config: emptyConfig, selectedPart: '');
      final client = _MockKioskClient(snapshot);

      await _pumpKiosk(tester, snapshot: snapshot, client: client);

      // Should show empty state message or prompt without errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('Large count values render cleanly without text overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final snapshot = _buildSnapshot(
        config: _configWithParts,
        selectedPart: 'washer',
        count: 99999,
      );
      final client = _MockKioskClient(snapshot);

      await _pumpKiosk(tester, snapshot: snapshot, client: client);

      expect(find.text('99999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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

const _washer = PartType(
  id: 'washer',
  name: 'Washer',
  image: '',
  keywords: ['washer'],
  enabled: true,
);

const _hexNut = PartType(
  id: 'hex_nut',
  name: 'Hex Nut',
  image: '',
  keywords: ['nut'],
  enabled: true,
);

final _configWithParts = MachineConfig.empty
    .copyWithPartCatalog(
      partTypes: const [_washer, _hexNut],
      selectedPartType: 'washer',
    )
    .copyWithModel({'engine': 'mock', 'model_path': 'mock'});

MachineSnapshot _buildSnapshot({
  required MachineConfig config,
  required String selectedPart,
  int count = 0,
}) {
  return MachineSnapshot(
    connected: true,
    config: config,
    state: MachineState.empty.copyWith(
      safeMode: false,
      selectedPartType: selectedPart,
      count: count,
      camera: 'ready',
      model: 'ready',
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
  String? lastSelectedPartType;

  @override
  MachineSnapshot get snapshot => _snapshot;

  @override
  void selectPartType(String partType) {
    lastSelectedPartType = partType;
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
