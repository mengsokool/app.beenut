import 'package:beenut/core/models.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/core/theme_controller.dart';
import 'package:beenut/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final themesMap = <AppThemeMode, ThemeData>{
    AppThemeMode.light: BeenutTheme.light,
    AppThemeMode.dark: BeenutTheme.dark,
    AppThemeMode.kioskHighContrast: BeenutTheme.kioskHighContrast,
  };

  const sampleParts = [
    PartType(
      id: 'p1',
      name: 'Standard M10 Hex Bolt Grade 8.8 Galvanized Steel',
      image: '',
      keywords: ['bolt', 'm10', 'steel', 'hex'],
      enabled: true,
    ),
    PartType(
      id: 'p2',
      name: 'M8 Stainless Washer',
      image: '',
      keywords: ['washer', 'm8'],
      enabled: true,
    ),
    PartType(
      id: 'p3',
      name: 'Ultra-Long Part Name That Could Potentially Cause Text Overflow If Not Properly Ellipsized',
      image: '',
      keywords: ['long_part'],
      enabled: true,
    ),
  ];

  group('Challenger M2 Verification: Comprehensive Theme Switching & Rendering', () {
    testWidgets('Renders all 5 M2 components in Light, Dark, and High-Contrast modes without overflow', (
      tester,
    ) async {
      for (final mode in [
        AppThemeMode.light,
        AppThemeMode.dark,
        AppThemeMode.kioskHighContrast,
      ]) {
        await tester.binding.setSurfaceSize(const Size(1024, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final themeData = themesMap[mode]!;

        await tester.pumpWidget(
          MaterialApp(
            theme: themeData,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // 1. KioskHeaderStatusBar
                    KioskHeaderStatusBar(
                      connectionState: DaemonConnectionState.connected,
                      cameraStatusText: 'Camera Ready',
                      activeModelName: 'yolo26n.onnx',
                      currentThemeMode: mode,
                      hardwareTemperature: 45.0,
                      onThemeModeChanged: (_) {},
                      onOpenSettings: () {},
                    ),
                    const SizedBox(height: 16),

                    // 2. LiveStreamCameraPane
                    SizedBox(
                      height: 400,
                      child: LiveStreamCameraPane(
                        state: MachineState.empty.copyWith(
                          camera: 'ok',
                          previewPaused: false,
                          detections: const [
                            Detection(
                              label: 'bolt',
                              confidence: 0.95,
                              x: 0.1,
                              y: 0.1,
                              w: 0.2,
                              h: 0.2,
                            ),
                          ],
                        ),
                        connected: true,
                        keywords: const ['bolt', 'washer'],
                        onTogglePause: () {},
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. PartSelectorCard
                    PartSelectorCard(
                      selectedPart: sampleParts.first,
                      availablePartsCount: sampleParts.length,
                      onTapOpenCatalog: () {},
                    ),
                    const SizedBox(height: 16),

                    // 4. CountDashboardPanel
                    SizedBox(
                      height: 350,
                      child: CountDashboardPanel(
                        count: 150,
                        targetCount: 200,
                        status: CountDashboardStatus.counting,
                        statusTitle: 'COUNTING',
                        statusSubtitle: 'High speed vision counting active',
                        classBreakdowns: const [
                          ClassBreakdownItem(
                            label: 'm10_bolt',
                            count: 100,
                            color: Colors.amber,
                          ),
                          ClassBreakdownItem(
                            label: 'm8_washer',
                            count: 50,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. KioskFormControls
                    Column(
                      children: [
                        KioskButton(
                          label: 'Primary Button',
                          onPressed: () {},
                          variant: KioskButtonVariant.primary,
                        ),
                        const SizedBox(height: 8),
                        KioskButton(
                          label: 'Danger Action',
                          onPressed: () {},
                          variant: KioskButtonVariant.danger,
                        ),
                        const SizedBox(height: 8),
                        KioskSwitch(
                          label: 'Auto Stop on Target',
                          subtitle: 'Automatically pause daemon when target is reached',
                          value: true,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 8),
                        KioskSlider(
                          label: 'Confidence Threshold',
                          valueLabel: '85%',
                          value: 0.85,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 8),
                        KioskTextField(
                          controller: TextEditingController(text: 'Operator 001'),
                          label: 'Operator Identifier',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Verify elements rendered
        expect(find.text('ONLINE'), findsOneWidget);
        expect(find.text('LIVE 30 FPS'), findsOneWidget);
        expect(find.text('150'), findsOneWidget);
        expect(find.text('Primary Button'), findsOneWidget);
      }
    });

    testWidgets('Dynamic theme mode switching across all 3 themes does not throw exceptions or overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final themeController = ValueNotifier<AppThemeMode>(AppThemeMode.light);

      await tester.pumpWidget(
        ValueListenableBuilder<AppThemeMode>(
          valueListenable: themeController,
          builder: (context, currentMode, _) {
            return MaterialApp(
              theme: themesMap[currentMode],
              home: Scaffold(
                body: Row(
                  children: [
                    // Left Column: Header + Camera
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          KioskHeaderStatusBar(
                            connectionState: DaemonConnectionState.connected,
                            cameraStatusText: 'Camera Ready',
                            activeModelName: 'yolo26n.onnx',
                            currentThemeMode: currentMode,
                            hardwareTemperature: 55.2,
                            onThemeModeChanged: (newMode) {
                              themeController.value = newMode;
                            },
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: LiveStreamCameraPane(
                              state: MachineState.empty.copyWith(
                                camera: 'ok',
                                previewPaused: false,
                              ),
                              connected: true,
                              keywords: const ['bolt'],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right Column: Part Selector + Dashboard + Controls
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          PartSelectorCard(
                            selectedPart: sampleParts[0],
                            availablePartsCount: 3,
                            onTapOpenCatalog: () {},
                          ),
                          const SizedBox(height: 12),
                          const Expanded(
                            child: CountDashboardPanel(
                              count: 88,
                              targetCount: 100,
                              status: CountDashboardStatus.counted,
                              statusTitle: 'DONE',
                              statusSubtitle: 'Batch completed',
                              classBreakdowns: [
                                ClassBreakdownItem(
                                  label: 'Bolt',
                                  count: 88,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          KioskButton(
                            label: 'Reset Counter',
                            onPressed: () {},
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('ONLINE'), findsOneWidget);

      // Switch to Dark mode
      themeController.value = AppThemeMode.dark;
      await tester.pumpAndSettle();
      expect(find.text('ONLINE'), findsOneWidget);

      // Switch to Kiosk High Contrast mode
      themeController.value = AppThemeMode.kioskHighContrast;
      await tester.pumpAndSettle();
      expect(find.text('ONLINE'), findsOneWidget);

      // Switch back to Light mode
      themeController.value = AppThemeMode.light;
      await tester.pumpAndSettle();
      expect(find.text('ONLINE'), findsOneWidget);
    });

    testWidgets('KioskHeaderStatusBar handles long model names without overflowing', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: Center(
              child: KioskHeaderStatusBar(
                connectionState: DaemonConnectionState.connecting,
                cameraStatusText: 'Camera Initializing...',
                activeModelName: 'extremely_long_yolo_v8_industrial_nut_counter_model_v4_quantized.onnx',
                currentThemeMode: AppThemeMode.light,
                hardwareTemperature: 78.5,
                hardwareHealthState: HardwareHealthState.warning,
                onThemeModeChanged: (_) {},
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('CONNECTING'), findsOneWidget);
      expect(find.text('78.5°C'), findsOneWidget);
    });

    testWidgets('LiveStreamCameraPane stress test with 50+ detection bounding boxes', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final manyDetections = List.generate(
        50,
        (i) => Detection(
          label: i % 2 == 0 ? 'bolt' : 'washer',
          confidence: 0.8 + (i % 20) * 0.01,
          x: (i % 10) * 0.09,
          y: (i ~/ 10) * 0.18,
          w: 0.08,
          h: 0.08,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.dark,
          home: Scaffold(
            body: LiveStreamCameraPane(
              state: MachineState.empty.copyWith(
                camera: 'ok',
                detections: manyDetections,
              ),
              connected: true,
              keywords: const ['bolt', 'washer'],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LiveStreamCameraPane), findsOneWidget);
    });

    testWidgets('PartCatalogSelector works seamlessly under high contrast theme', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      PartType? chosen;

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.kioskHighContrast,
          home: Scaffold(
            body: PartCatalogSelector(
              parts: sampleParts,
              selectedId: 'p1',
              onSelectPart: (p) => chosen = p,
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Select Target Part'), findsOneWidget);
      expect(find.text('Standard M10 Hex Bolt Grade 8.8 Galvanized Steel'), findsOneWidget);

      await tester.tap(find.text('M8 Stainless Washer'));
      await tester.pump();
      expect(chosen?.id, 'p2');
    });

    testWidgets('CountDashboardPanel renders large figures (999,999) and dense layout', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 180)); // Dense constraint
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.light,
          home: Scaffold(
            body: const CountDashboardPanel(
              count: 999999,
              targetCount: 1000000,
              status: CountDashboardStatus.counting,
              statusTitle: 'RUNNING',
              statusSubtitle: 'Dense viewport',
              classBreakdowns: [],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('999999'), findsOneWidget);
    });

    testWidgets('KioskDialog modal displays properly with full touchscreen controls', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeenutTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    KioskDialog.show(
                      context: context,
                      title: 'Confirm Calibration',
                      icon: Icons.tune_rounded,
                      content: const Text('Do you want to re-calibrate camera vision field?'),
                      actions: [
                        KioskButton(
                          label: 'Cancel',
                          variant: KioskButtonVariant.outlined,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        KioskButton(
                          label: 'Calibrate',
                          variant: KioskButtonVariant.primary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Calibration'), findsOneWidget);
      expect(find.text('Do you want to re-calibrate camera vision field?'), findsOneWidget);
      expect(find.text('Calibrate'), findsOneWidget);

      await tester.tap(find.text('Calibrate'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Calibration'), findsNothing);
    });
  });
}
