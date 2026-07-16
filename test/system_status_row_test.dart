import 'package:beenut/core/i18n.dart';
import 'package:beenut/core/models.dart';
import 'package:beenut/core/system_permissions.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/ui/common/setting_types.dart';
import 'package:beenut/ui/common/system_status_row.dart';
import 'package:beenut/ui/settings/tabs/status_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('system health separates status, metrics, and raw details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const cameraDeviceId = '3642F2CD-E322-42E7-9360-19815B003AA6';
    final config = MachineConfig.empty
        .copyWithCamera({
          'source': 'avfoundation',
          'device': cameraDeviceId,
          'width': 1920,
          'height': 1080,
          'fps': 30,
        })
        .copyWithModel({
          'engine': 'onnx',
          'model_path': '/opt/beenut/models/yolo26n.onnx',
        });
    I18n.updateFromConfig(config);
    final snapshot = MachineSnapshot(
      connected: true,
      config: config,
      state: MachineState.empty.copyWith(
        camera: 'ready',
        cameraDetail:
            'avfvideosrc device-index=0 ! video/x-raw,width=1920,height=1080',
        captureFps: 30,
        model: 'ready',
        modelDetail: 'ONNX Runtime ready · CPU threads 4',
        modelLabels: const ['nut', 'bolt'],
        inferenceFps: 9.7,
      ),
      capabilities: const HardwareCapabilities(
        cameras: [
          {
            'source': 'avfoundation',
            'device': cameraDeviceId,
            'name': 'FaceTime HD Camera',
          },
        ],
        previewTransports: [],
        aiRuntimes: [],
        gpio: {},
        gstreamer: {},
        system: {},
      ),
      validation: ConfigValidation.empty,
      diagnostic: DiagnosticEvent.empty,
      saveResult: ConfigSaveResult.empty,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatusSettingsTab(
              config: config,
              snapshot: snapshot,
              cameraPermission: CameraPermissionStatus.authorized,
              onRefreshCameraPermission: () async {},
              onRefreshCapabilities: () {},
              onSave: (_) {},
              enabled: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ready'), findsNWidgets(2));
    expect(find.text('FaceTime HD Camera'), findsOneWidget);
    expect(find.text(cameraDeviceId), findsNothing);
    expect(
      find.textContaining('1920 × 1080', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('30.0 fps', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('yolo26n.onnx', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('9.7 fps', findRichText: true), findsOneWidget);
    expect(find.textContaining('avfvideosrc'), findsNothing);
    expect(
      tester.widget<Text>(find.text('FaceTime HD Camera')).style?.fontFamily,
      BeenutTheme.fontFamily,
    );
    expect(
      tester.widget<Text>(find.text('1920 × 1080')).style?.fontFamily,
      'monospace',
    );
    expect(
      tester.widget<Text>(find.text('No errors found')).style?.fontFamily,
      BeenutTheme.fontFamily,
    );

    await tester.tap(find.text('Show technical details').first);
    await tester.pump();

    expect(find.textContaining('avfvideosrc'), findsOneWidget);
    expect(find.text(cameraDeviceId), findsOneWidget);
    expect(find.text('Hide technical details'), findsOneWidget);
  });

  testWidgets('semantic Thai metrics use the interface font', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: const Scaffold(
          body: SystemStatusRow(
            icon: Icons.check_box_outlined,
            iconColor: Colors.green,
            label: 'การตรวจสอบค่าระบบ',
            status: 'ถูกต้อง',
            tone: RowTone.success,
            metrics: [
              SystemStatusMetric(label: 'ผลตรวจ', value: 'ไม่พบข้อผิดพลาด'),
              SystemStatusMetric(
                label: 'อัตราภาพ',
                value: '30.0 fps',
                monospace: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('ไม่พบข้อผิดพลาด')).style?.fontFamily,
      BeenutTheme.fontFamily,
    );
    expect(
      tester.widget<Text>(find.text('30.0 fps')).style?.fontFamily,
      'monospace',
    );
  });

  testWidgets('system health stays overflow-free at compact width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final config = MachineConfig.empty.copyWithCamera({
      'source': 'avfoundation',
      'device': 'compact-camera-id',
      'width': 1920,
      'height': 1080,
    });
    final snapshot = MachineSnapshot(
      connected: true,
      config: config,
      state: MachineState.empty.copyWith(
        camera: 'ready',
        model: 'ready',
        captureFps: 30,
        inferenceFps: 10,
      ),
      capabilities: const HardwareCapabilities(
        cameras: [
          {
            'source': 'avfoundation',
            'device': 'compact-camera-id',
            'name': 'USB camera with a very long device name',
          },
        ],
        previewTransports: [],
        aiRuntimes: [],
        gpio: {},
        gstreamer: {},
        system: {},
      ),
      validation: ConfigValidation.empty,
      diagnostic: DiagnosticEvent.empty,
      saveResult: ConfigSaveResult.empty,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: BeenutTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatusSettingsTab(
              config: config,
              snapshot: snapshot,
              cameraPermission: CameraPermissionStatus.authorized,
              onRefreshCameraPermission: () async {},
              onRefreshCapabilities: () {},
              onSave: (_) {},
              enabled: true,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining(
        'USB camera with a very long device name',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });
}
