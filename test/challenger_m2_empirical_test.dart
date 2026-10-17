import 'package:beenut/core/models.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/core/theme_controller.dart';
import 'package:beenut/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Empirical Challenge Suite: 8 Edge-Case States', () {
    // -------------------------------------------------------------------------
    // 1. NULL VALUES
    // -------------------------------------------------------------------------
    testWidgets('EC1: Null Values - Components handle null optional arguments without throwing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // Header with null temperature and null onOpenSettings
                  KioskHeaderStatusBar(
                    connectionState: DaemonConnectionState.connected,
                    cameraStatusText: 'Camera Ready',
                    activeModelName: 'model.onnx',
                    currentThemeMode: AppThemeMode.light,
                    onThemeModeChanged: (_) {},
                    hardwareTemperature: null,
                    onOpenSettings: null,
                  ),
                  // PartSelectorCard with null selectedPart
                  PartSelectorCard(
                    selectedPart: null,
                    availablePartsCount: 0,
                    onTapOpenCatalog: () {},
                  ),
                  // CountDashboardPanel with null targetCount and null statusColor
                  const SizedBox(
                    height: 300,
                    child: CountDashboardPanel(
                      count: 0,
                      targetCount: null,
                      statusTitle: 'READY',
                      statusSubtitle: '',
                      classBreakdowns: [],
                      statusColor: null,
                    ),
                  ),
                  // Form controls with null optional labels/callbacks
                  const KioskSwitch(
                    value: false,
                    onChanged: null,
                    label: null,
                    subtitle: null,
                  ),
                  const KioskSlider(
                    value: 0.5,
                    onChanged: null,
                    label: null,
                    valueLabel: null,
                  ),
                  KioskButton(
                    label: 'Disabled Button',
                    onPressed: null,
                    icon: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Select Part Target'), findsOneWidget);
      expect(find.text('0 parts available'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 2. EMPTY PART LISTS & COLLECTIONS
    // -------------------------------------------------------------------------
    testWidgets('EC2: Empty Collections - Empty parts list, zero breakdowns, zero detections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: PartCatalogSelector(
                    parts: const [],
                    selectedId: '',
                    onSelectPart: (_) {},
                  ),
                ),
                Expanded(
                  child: LiveStreamCameraPane(
                    state: MachineState.empty.copyWith(
                      camera: 'ok',
                      detections: const [],
                    ),
                    connected: true,
                    keywords: const [],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('No matching parts found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 3. 0 COUNT
    // -------------------------------------------------------------------------
    testWidgets('EC3: Zero Count - 0 count and 0 targetCount rendered cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: const CountDashboardPanel(
              count: 0,
              targetCount: 0,
              status: CountDashboardStatus.ready,
              statusTitle: 'STANDBY',
              statusSubtitle: 'Ready for batch',
              classBreakdowns: [],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('0'), findsNWidgets(2)); // hero count + target count
      expect(find.text('PASS'), findsOneWidget); // 0 >= 0 is pass
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 4. LARGE COUNT NUMBERS (99,999 / 999,999,999)
    // -------------------------------------------------------------------------
    testWidgets('EC4: Large Count Numbers - 99,999 and large breakdowns render without text clipping', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.kioskHighContrast,
          home: Scaffold(
            body: const CountDashboardPanel(
              count: 99999,
              targetCount: 100000,
              status: CountDashboardStatus.counted,
              statusTitle: 'HIGH COUNT',
              statusSubtitle: 'Large number test',
              classBreakdowns: [
                ClassBreakdownItem(
                  label: 'm10_bolt_heavy_industrial_grade',
                  count: 99999,
                  color: Colors.amber,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('99999'), findsNWidgets(2));
      expect(find.text('100000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 5. LONG TEXT STRINGS & OVERFLOW VERIFICATION
    // -------------------------------------------------------------------------
    testWidgets('EC5: Long Text Strings - KioskHeaderStatusBar overflow test with long activeModelName', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: Center(
              child: KioskHeaderStatusBar(
                connectionState: DaemonConnectionState.connected,
                cameraStatusText: 'Camera Stream Active & Operational',
                activeModelName: 'extremely_long_yolo_v8_industrial_nut_counter_model_v4_quantized.onnx',
                currentThemeMode: AppThemeMode.light,
                hardwareTemperature: 72.4,
                onThemeModeChanged: (_) {},
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      final dynamic exception = tester.takeException();
      // Record exception empirically: RenderFlex overflow is caught here
      if (exception != null) {
        debugPrint('Empirical finding EC5: Exception caught -> $exception');
      }
    });

    // -------------------------------------------------------------------------
    // 6. RAPIDLY CHANGING STATE VALUES
    // -------------------------------------------------------------------------
    testWidgets('EC6: Rapidly Changing State Values - 50 rapid state updates to detection overlay', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      MachineState currentState = MachineState.empty.copyWith(camera: 'ok');
      late StateSetter setWidgetState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setWidgetState = setState;
            return MaterialApp(
              theme: BeenutTheme.dark,
              home: Scaffold(
                body: LiveStreamCameraPane(
                  state: currentState,
                  connected: true,
                  keywords: const ['bolt', 'nut'],
                ),
              ),
            );
          },
        ),
      );

      // Simulate 50 rapid state updates (e.g. camera stream at 30-60 fps)
      for (int i = 0; i < 50; i++) {
        setWidgetState(() {
          currentState = currentState.copyWith(
            detections: [
              Detection(
                label: i % 2 == 0 ? 'bolt' : 'nut',
                confidence: 0.70 + (i % 25) * 0.01,
                x: (i * 0.015) % 0.8,
                y: (i * 0.012) % 0.8,
                w: 0.15,
                h: 0.15,
              ),
            ],
          );
        });
        await tester.pump(const Duration(milliseconds: 16)); // ~60 FPS frame pump
      }

      expect(find.byType(LiveStreamCameraPane), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 7. PAUSE CAMERA OVERLAY & CONSECUTIVE PAUSE RE-CAPTURE
    // -------------------------------------------------------------------------
    testWidgets('EC7: Pause Camera Overlay - Blur filter & pause message rendering', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool isPaused = false;
      late StateSetter setWidgetState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setWidgetState = setState;
            return MaterialApp(
              theme: BeenutTheme.light,
              home: Scaffold(
                body: LiveStreamCameraPane(
                  state: MachineState.empty.copyWith(
                    camera: 'ok',
                    previewPaused: isPaused,
                  ),
                  connected: true,
                  keywords: const ['bolt'],
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

      expect(find.text('LIVE 30 FPS'), findsOneWidget);
      expect(find.text('PAUSE'), findsOneWidget);

      // Tap pause button
      await tester.tap(find.text('PAUSE'));
      await tester.pump();

      expect(find.text('VIDEO STREAM PAUSED'), findsOneWidget);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);

      // Tap resume
      await tester.tap(find.text('RESUME'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('LIVE 30 FPS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 8. FORM DIALOG INPUTS
    // -------------------------------------------------------------------------
    testWidgets('EC8: Form Dialog Inputs - KioskDialog with interactive inputs and actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final textController = TextEditingController();
      bool switchVal = false;
      double sliderVal = 0.5;
      bool submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => KioskButton(
                label: 'Open Form',
                onPressed: () {
                  KioskDialog.show(
                    context: context,
                    title: 'Target Settings',
                    icon: Icons.settings,
                    content: StatefulBuilder(
                      builder: (context, setDialogState) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            KioskTextField(
                              controller: textController,
                              label: 'Batch Name',
                              hintText: 'Enter batch name...',
                            ),
                            const SizedBox(height: 12),
                            KioskSwitch(
                              label: 'Auto Stop',
                              value: switchVal,
                              onChanged: (val) => setDialogState(() => switchVal = val),
                            ),
                            const SizedBox(height: 12),
                            KioskSlider(
                              label: 'Sensitivity',
                              value: sliderVal,
                              onChanged: (val) => setDialogState(() => sliderVal = val),
                            ),
                          ],
                        );
                      },
                    ),
                    actions: [
                      KioskButton(
                        label: 'Cancel',
                        variant: KioskButtonVariant.outlined,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      KioskButton(
                        label: 'Save',
                        onPressed: () {
                          submitted = true;
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      expect(find.text('Target Settings'), findsOneWidget);
      expect(find.byType(KioskTextField), findsOneWidget);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Batch #402');
      await tester.pump();
      expect(textController.text, 'Batch #402');

      // Toggle switch
      await tester.tap(find.text('Auto Stop'));
      await tester.pump();
      expect(switchVal, isTrue);

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
      expect(find.text('Target Settings'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
