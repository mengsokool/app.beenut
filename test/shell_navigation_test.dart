import 'package:beenut/core/models.dart';
import 'package:beenut/core/i18n.dart';
import 'package:beenut/ui/common/setting_rows.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/kiosk/kiosk_page.dart';
import 'package:beenut/ui/settings/settings_page.dart';
import 'package:beenut/ui/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => I18n.updateFromConfig(MachineConfig.empty));
  testWidgets('BeenutShell handles Android back navigation via PopScope', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeClient = _FakeClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: BeenutShell(
          cameraPermission: CameraPermissionStatus.authorized,
          clientOverride: fakeClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final popScopeFinder = find.byKey(const ValueKey('shell-pop-scope'));

    // 1. Initially on KioskPage
    expect(find.byType(KioskPage), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);

    // PopScope should allow pop when on KioskPage (canPop == true)
    var popScope = tester.widget<PopScope<Object>>(popScopeFinder);
    expect(popScope.canPop, isTrue);

    // 2. Tap settings button to open settings
    final settingsButton = find.byKey(const ValueKey('kiosk-settings-action'));
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    // Now SettingsPage should be open
    expect(find.byType(SettingsPage), findsOneWidget);

    // PopScope should NOT allow system pop when in settings (canPop == false)
    popScope = tester.widget<PopScope<Object>>(popScopeFinder);
    expect(popScope.canPop, isFalse);

    // A nested task owns its draft and system back must not close the shell.
    await tester.tap(find.byKey(const ValueKey('settings-task-display')));
    await tester.pumpAndSettle();
    final scale = find.ancestor(
      of: find.text('UI Scale'),
      matching: find.byType(StepperSettingRow),
    );
    await tester.tap(
      find.descendant(of: scale, matching: find.byIcon(Icons.add)),
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(KioskPage), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Discard').last);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsNavButton), findsNWidgets(4));

    // 3. Simulate Android system back button / back gesture
    final popHandled = await tester.binding.handlePopRoute();
    expect(popHandled, isTrue);
    await tester.pumpAndSettle();

    // SettingsPage should be dismissed and KioskPage restored
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(KioskPage), findsOneWidget);

    // PopScope should allow pop again
    popScope = tester.widget<PopScope<Object>>(popScopeFinder);
    expect(popScope.canPop, isTrue);
  });

  testWidgets('BeenutShell allows system pop on root KioskPage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeClient = _FakeClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: BeenutShell(
          cameraPermission: CameraPermissionStatus.authorized,
          clientOverride: fakeClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final popScopeFinder = find.byKey(const ValueKey('shell-pop-scope'));
    final popScope = tester.widget<PopScope<Object>>(popScopeFinder);
    expect(popScope.canPop, isTrue);

    final popHandled = await tester.binding.handlePopRoute();
    // On root route with canPop == true and no other routes on stack, handlePopRoute returns false
    expect(popHandled, isFalse);
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
