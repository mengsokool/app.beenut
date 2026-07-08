import 'package:beenut/core/models.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/kiosk/kiosk_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('kiosk icon actions expose accessible labels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: KioskPage(
            snapshot: _snapshot,
            client: _FakeClient(),
            cameraPermission: CameraPermissionStatus.authorized,
            onOpenSettings: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byTooltip('Shutdown'), findsNothing);
  });
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

final _snapshot = MachineSnapshot(
  connected: true,
  config: _config,
  state: MachineState.empty.copyWith(
    selectedPartType: 'washer',
    trayPresent: true,
  ),
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
