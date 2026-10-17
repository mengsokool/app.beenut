import 'package:beenut/core/config_draft.dart';
import 'package:beenut/core/i18n.dart';
import 'package:beenut/core/models.dart';
import 'package:beenut/core/service_client.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/core/ui_scale.dart';
import 'package:beenut/ui/common/setting_rows.dart';
import 'package:beenut/ui/common/settings_experience.dart';
import 'package:beenut/ui/common/virtual_keyboard.dart';
import 'package:beenut/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    I18n.updateFromConfig(MachineConfig.empty);
    UiScaleController.clearPreview();
    UiScaleController.update(1);
  });
  tearDown(() {
    UiScaleController.clearPreview();
    UiScaleController.update(1);
  });

  test(
    'draft preserves unrelated live changes and clears when values revert',
    () {
      final initial = MachineConfig.empty.copyWithModel({
        'engine': 'ncnn',
        'ncnn_threads': 2,
      });
      final current = initial.copyWithModelSettings(initial.modelSettings);
      final draft = ConfigDraft();
      draft.update(
        current,
        current.copyWithModelSettings(
          current.modelSettings.copyWith(ncnnThreads: 4),
        ),
      );
      final refreshed = current.copyWithCameraSettings(
        current.cameraSettings.copyWith(fps: 15),
      );
      expect(draft.resolve(refreshed).cameraSettings.fps, 15);
      expect(draft.resolve(refreshed).modelSettings.ncnnThreads, 4);
      draft.update(
        refreshed,
        draft.resolve(refreshed).copyWithModelSettings(current.modelSettings),
      );
      expect(draft.isDirty, isFalse);
      expect(draft.resolve(refreshed).cameraSettings.fps, 15);
    },
  );

  testWidgets(
    'UI scale previews immediately and persists after acknowledgement',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = _Client();
      final live = ValueNotifier(snapshot);
      addTearDown(live.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light.copyWith(platform: TargetPlatform.linux),
          builder: (context, child) => ValueListenableBuilder<double>(
            valueListenable: UiScaleController.scale,
            builder: (context, scale, _) =>
                UiScaleScope(scale: scale, child: child!),
          ),
          home: ValueListenableBuilder(
            valueListenable: live,
            builder: (context, value, _) => Scaffold(
              body: SettingsPage(
                initialTask: SettingsTask.display,
                snapshot: value,
                client: client,
                cameraPermission: CameraPermissionStatus.authorized,
                onRefreshCameraPermission: () async {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('100 %'));
      await tester.pumpAndSettle();
      // Basic mode starts with a touch keypad; the initial value is selected.
      await tester.tap(find.widgetWithText(OutlinedButton, '1'));
      await tester.tap(find.widgetWithText(OutlinedButton, '2'));
      await tester.tap(find.widgetWithText(OutlinedButton, '0'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('settings-number-done')));
      await tester.pumpAndSettle();
      expect(find.text('120 %'), findsOneWidget);
      expect(client.saved, isEmpty);
      expect(
        tester.getRect(find.byKey(const ValueKey('settings-toolbar'))).height,
        closeTo(56 * 1.2, 0.01),
      );
      await tester.tap(find.byKey(const ValueKey('settings-apply')));
      await tester.pump();
      expect(client.saved, hasLength(1));
      expect(client.saved.single.uiSettings.scale, 1.2);
      expect(find.text('Applying…'), findsOneWidget);
      live.value = snapshot.copyWith(
        saveResult: const ConfigSaveResult(
          ok: false,
          message: 'Rejected configuration',
          detail: '',
          timestampMs: 1,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('120 %'), findsOneWidget);
      expect(UiScaleController.scale.value, 1.2);
      expect(find.byKey(const ValueKey('settings-apply-bar')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-apply')));
      await tester.pump();
      expect(client.saved, hasLength(2));
      live.value = snapshot.copyWith(
        config: client.saved.last,
        saveResult: const ConfigSaveResult(
          ok: true,
          message: '',
          detail: '',
          timestampMs: 2,
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-apply-bar')), findsNothing);
      expect(UiScaleController.scale.value, 1.2);
      await tester.tap(find.byKey(const ValueKey('settings-back')));
      await tester.pumpAndSettle();
      expect(UiScaleController.scale.value, 1.2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('discarding the scale draft restores the saved size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SettingsPage(
            initialTask: SettingsTask.display,
            snapshot: snapshot,
            client: _Client(),
            cameraPermission: CameraPermissionStatus.authorized,
            onRefreshCameraPermission: () async {},
            onClose: () {},
          ),
        ),
      ),
    );
    final scaleRow = find.widgetWithText(StepperSettingRow, 'UI Scale');
    await tester.tap(
      find.descendant(of: scaleRow, matching: find.byIcon(Icons.add)),
    );
    await tester.pumpAndSettle();
    expect(UiScaleController.scale.value, 1.05);
    // A stale service scale must not replace the draft preview.
    UiScaleController.update(1);
    expect(UiScaleController.scale.value, 1.05);
    await tester.tap(find.byKey(const ValueKey('settings-discard')));
    await tester.pumpAndSettle();
    expect(UiScaleController.scale.value, 1);
    expect(find.text('100 %'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-apply-bar')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('machine number input validates inline and supports typing', (
    tester,
  ) async {
    var changed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SettingsExperience(
            developer: true,
            child: StepperSettingRow(
              label: 'Threads',
              description: '',
              value: 2,
              min: 1,
              max: 32,
              enabled: true,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      ),
    );
    final field = find.byKey(const ValueKey('setting-number-Threads'));
    await tester.enterText(field, '33');
    await tester.pump();
    expect(changed, 0);
    expect(find.text('1–32'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(field, '4');
    await tester.pump();
    expect(changed, 4);
    expect(find.text('1–32'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('setting-keypad-Threads')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '7'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(changed, 4);
  });

  testWidgets('touch keypad exposes zero on a short landscape screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var changed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SettingsExperience(
            developer: false,
            child: StepperSettingRow(
              label: 'Threads',
              description: '',
              value: 2,
              min: 1,
              max: 32,
              enabled: true,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    final zero = find.widgetWithText(OutlinedButton, '0');
    expect(tester.getCenter(zero).dy, lessThan(400));
    await tester.tap(zero);
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('settings-number-done')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '2'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-number-done')));
    await tester.pumpAndSettle();
    expect(changed, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thai touch keyboard fits short screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 432));
    tester.view.physicalSize = const Size(800, 432);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: BeenutFullscreenKeyboard(initialText: '', onSave: (_) {}),
        ),
      ),
    );
    await tester.tap(find.text('TH'));
    await tester.pump();
    expect(find.text('EN'), findsOneWidget);
    await tester.tap(find.text('123 /'));
    await tester.pump();
    expect(find.text('/'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final snapshot = MachineSnapshot(
  connected: true,
  config: MachineConfig.empty,
  state: MachineState.empty,
  capabilities: HardwareCapabilities.empty,
  validation: ConfigValidation.empty,
  diagnostic: DiagnosticEvent.empty,
  saveResult: ConfigSaveResult.empty,
);

class _Client extends KioskServiceClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final saved = <MachineConfig>[];
  @override
  void refreshCapabilities() {}
  @override
  void saveConfig(MachineConfig config) => saved.add(config);
}
