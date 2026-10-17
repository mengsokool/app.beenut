import 'package:beenut/core/models.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/core/theme_controller.dart';
import 'package:beenut/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Empirical Challenger M2 Gen2 Stress Suite', () {
    // -------------------------------------------------------------------------
    // 1. KioskHeaderStatusBar Boundary & Overflow Stress Test
    // -------------------------------------------------------------------------
    testWidgets('Header Status Bar: Stress test narrow widths and long strings without overflow', (tester) async {
      final narrowWidths = [1280.0, 1024.0, 800.0, 600.0, 480.0];

      for (final width in narrowWidths) {
        await tester.binding.setSurfaceSize(Size(width, 100));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: BeenutTheme.light,
            home: Scaffold(
              body: Center(
                child: KioskHeaderStatusBar(
                  connectionState: DaemonConnectionState.connecting,
                  cameraStatusText: 'Camera Reconnecting & Stream Warmup Active',
                  activeModelName: 'extremely_long_yolo_v8_industrial_nut_counter_model_v4_quantized_precision.onnx',
                  currentThemeMode: AppThemeMode.kioskHighContrast,
                  hardwareTemperature: 84.5,
                  hardwareHealthState: HardwareHealthState.fault,
                  onThemeModeChanged: (_) {},
                  onOpenSettings: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final exception = tester.takeException();
        expect(exception, isNull, reason: 'KioskHeaderStatusBar threw exception at width $width: $exception');
      }
    });

    // -------------------------------------------------------------------------
    // 2. CountDashboardPanel Extreme Counts & Class Breakdown Stress Test
    // -------------------------------------------------------------------------
    testWidgets('Count Dashboard Panel: Extreme count values (0, 999,999, 999,999,999)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testCounts = [0, 999999, 999999999];

      for (final count in testCounts) {
        await tester.pumpWidget(
          MaterialApp(
            theme: BeenutTheme.dark,
            home: Scaffold(
              body: CountDashboardPanel(
                count: count,
                targetCount: 1000000,
                status: CountDashboardStatus.counted,
                statusTitle: 'COUNT COMPLETE',
                statusSubtitle: 'Batch count completed successfully',
                classBreakdowns: const [
                  ClassBreakdownItem(
                    label: 'M10 Hex Bolt Heavy Duty Industrial Grade',
                    count: 500000,
                    color: Colors.blue,
                  ),
                  ClassBreakdownItem(
                    label: 'M8 Stainless Steel Washer High Temperature Spec',
                    count: 499999,
                    color: Colors.amber,
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('$count'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Count Dashboard Panel: 100 Class Breakdown Items scrolling stress test', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final manyBreakdowns = List.generate(
        100,
        (i) => ClassBreakdownItem(
          label: 'Class #$i: Long Industrial Part Specification Name $i',
          count: (i + 1) * 10,
          color: Colors.primaries[i % Colors.primaries.length],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: CountDashboardPanel(
              count: 55000,
              targetCount: 100000,
              status: CountDashboardStatus.counting,
              statusTitle: 'COUNTING',
              statusSubtitle: 'Processing 100 classes',
              classBreakdowns: manyBreakdowns,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('CLASS BREAKDOWN'), findsOneWidget);
      expect(find.textContaining('Class #0:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 3. LiveStreamCameraPane High FPS & Frame Pause Overlay Stress Test
    // -------------------------------------------------------------------------
    testWidgets('LiveStreamCameraPane: High Framerate Simulation & Rapid Pause Overlay Toggling', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool isPaused = false;
      int frameCount = 0;
      late StateSetter setWidgetState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setWidgetState = setState;
            return MaterialApp(
              theme: BeenutTheme.dark,
              home: Scaffold(
                body: LiveStreamCameraPane(
                  state: MachineState.empty.copyWith(
                    camera: 'ok',
                    previewPaused: isPaused,
                    detections: [
                      Detection(
                        label: frameCount % 2 == 0 ? 'bolt' : 'nut',
                        confidence: 0.90 + (frameCount % 10) * 0.01,
                        x: (frameCount * 0.02) % 0.7,
                        y: (frameCount * 0.015) % 0.7,
                        w: 0.2,
                        h: 0.2,
                      ),
                    ],
                  ),
                  connected: true,
                  keywords: const ['bolt', 'nut'],
                  onTogglePause: () {
                    setWidgetState(() {
                      isPaused = !isPaused;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      // High FPS tick simulation (120 FPS over 60 steps)
      for (int i = 0; i < 60; i++) {
        setWidgetState(() {
          frameCount++;
        });
        await tester.pump(const Duration(milliseconds: 8));
      }

      expect(find.text('LIVE 30 FPS'), findsOneWidget);

      // Rapidly toggle pause 10 times
      for (int p = 0; p < 10; p++) {
        await tester.tap(find.byType(KioskTouchScale).last);
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('LiveStreamCameraPane: 500 Overlapping Bounding Boxes Extreme Overload', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final extremeDetections = List.generate(
        500,
        (i) => Detection(
          label: i % 3 == 0 ? 'bolt' : (i % 3 == 1 ? 'nut' : 'washer'),
          confidence: 0.5 + (i % 50) * 0.01,
          x: (i % 25) * 0.038,
          y: (i ~/ 25) * 0.045,
          w: 0.035,
          h: 0.035,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: LiveStreamCameraPane(
              state: MachineState.empty.copyWith(
                camera: 'ok',
                detections: extremeDetections,
              ),
              connected: true,
              keywords: const ['bolt', 'nut', 'washer'],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(LiveStreamCameraPane), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 4. PartSelectorCard & Catalog Zero Items & Long Part Names
    // -------------------------------------------------------------------------
    testWidgets('Part Selector: Zero items in catalog (empty catalog state)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                PartSelectorCard(
                  selectedPart: null,
                  availablePartsCount: 0,
                  onTapOpenCatalog: () {},
                ),
                Expanded(
                  child: PartCatalogSelector(
                    parts: const [],
                    selectedId: '',
                    onSelectPart: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Select Part Target'), findsOneWidget);
      expect(find.text('0 parts available'), findsOneWidget);
      expect(find.text('No matching parts found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Part Catalog Selector: Long part names and 50 keywords wrapping test', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final megaPart = PartType(
        id: 'mega_part_001',
        name: 'Super High Precision Aerospace Grade Titanized Hexagon Socket Head Cap Screw Model M12x1.75x80mm Grade 12.9 ISO 4762 Black Oxide Finish Special Edition',
        image: '',
        keywords: List.generate(50, (k) => 'kw_$k'),
        enabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.dark,
          home: Scaffold(
            body: PartCatalogSelector(
              parts: [megaPart],
              selectedId: 'mega_part_001',
              onSelectPart: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Super High Precision Aerospace'), findsOneWidget);
      expect(find.text('kw_0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
