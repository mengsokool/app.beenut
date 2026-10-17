import 'package:beenut/core/models.dart';
import 'package:beenut/core/i18n.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/common/setting_rows.dart';
import 'package:beenut/ui/settings/tabs/model_tab.dart';
import 'package:beenut/ui/kiosk/preview_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NCNN settings survive JSON and unrelated model changes', () {
    final config = MachineConfig.empty.copyWithModel({
      'engine': 'ncnn',
      'model_path': '/models/count.param',
      'ncnn_bin_path': '/weights/count.bin',
      'ncnn_device': 'gpu',
      'ncnn_threads': 3,
    });
    final changed = config.copyWithModelSettings(
      config.modelSettings.copyWith(maxFps: 5),
    );
    final loaded = MachineConfig.fromJson(changed.toJson()).modelSettings;
    expect(loaded.engine, 'ncnn');
    expect(loaded.modelPath, '/models/count.param');
    expect(loaded.ncnnBinPath, '/weights/count.bin');
    expect(loaded.ncnnDevice, 'gpu');
    expect(loaded.ncnnThreads, 3);
    expect(ModelSettings.fromJson({}).ncnnDevice, 'cpu');
    expect(ModelSettings.fromJson({}).ncnnThreads, 2);
  });

  testWidgets('machine setup can select NCNN, device and threads', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    I18n.updateFromConfig(MachineConfig.empty.copyWithUi({'language': 'en'}));
    var config = MachineConfig.empty;
    final caps = HardwareCapabilities.empty.copyWith(
      aiRuntimes: [
        {'id': 'ncnn', 'available': true, 'gpuAvailable': true},
      ],
    );
    var section = ModelSettingsSection.model;
    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ModelSettingsTab(
              section: section,
              config: config,
              state: MachineState.empty,
              capabilities: caps,
              enabled: true,
              onSave: (next) => config = next,
            ),
          ),
        ),
      ),
    );
    await pump();
    await tester.tap(find.text('NCNN'));
    expect(config.modelSettings.engine, 'ncnn');
    await pump();
    expect(find.text('NCNN .param'), findsOneWidget);
    expect(find.text('NCNN .bin'), findsOneWidget);
    section = ModelSettingsSection.performance;
    await pump();
    await tester.tap(find.text('GPU (Vulkan)'));
    expect(config.modelSettings.ncnnDevice, 'gpu');
    await pump();
    final threads = find.ancestor(
      of: find.text('CPU threads'),
      matching: find.byType(StepperSettingRow),
    );
    final plus = find.descendant(of: threads, matching: find.byIcon(Icons.add));
    await tester.ensureVisible(plus);
    await tester.tap(plus);
    expect(config.modelSettings.ncnnThreads, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing preview plugin shows a recoverable error', (
    tester,
  ) async {
    const channel = MethodChannel('beenut/preview_texture');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    I18n.updateFromConfig(MachineConfig.empty.copyWithUi({'language': 'en'}));
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException('preview bridge unavailable');
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ShmNv12Preview(path: '/tmp/preview')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The native preview plugin is not installed.'),
      findsOneWidget,
    );
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'create' ? 42 : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tester.widget<Texture>(find.byType(Texture)).textureId, 42);
    expect(find.text('Preview unavailable'), findsNothing);
  });

  testWidgets('changing preview path releases the previous texture', (
    tester,
  ) async {
    const channel = MethodChannel('beenut/preview_texture');
    final calls = <MethodCall>[];
    var id = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'create' ? ++id : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Future<void> pump(String path) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ShmNv12Preview(path: path)),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump('/tmp/a');
    await pump('/tmp/b');
    expect(tester.widget<Texture>(find.byType(Texture)).textureId, 2);
    expect(
      calls.where((c) => c.method == 'dispose').first.arguments['textureId'],
      1,
    );
    expect(
      calls.where((c) => c.method == 'create').last.arguments['path'],
      '/tmp/b',
    );
  });
}
