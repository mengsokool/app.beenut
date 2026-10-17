import 'package:beenut/core/models.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/core/theme_controller.dart';
import 'package:beenut/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Challenger 2 M2 Run 3.2 Empirical Verification', () {
    final themeMap = <AppThemeMode, ThemeData>{
      AppThemeMode.light: BeenutTheme.light,
      AppThemeMode.dark: BeenutTheme.dark,
      AppThemeMode.kioskHighContrast: BeenutTheme.kioskHighContrast,
    };

    const samplePart = PartType(
      id: 'hex_bolt_m10',
      name: 'M10 Hex Bolt - High Tensile Steel',
      image: '',
      keywords: ['bolt', 'm10', 'steel'],
      enabled: true,
    );

    testWidgets('Renders all 5 M2 components across light, dark, and kioskHighContrast modes without overflow or exception', (tester) async {
      for (final mode in AppThemeMode.values) {
        await tester.binding.setSurfaceSize(const Size(1280, 1024));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: themeMap[mode],
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
                      hardwareTemperature: 48.6,
                      onThemeModeChanged: (_) {},
                      onOpenSettings: () {},
                    ),
                    const SizedBox(height: 16),

                    // 2. LiveStreamCameraPane
                    SizedBox(
                      height: 380,
                      child: LiveStreamCameraPane(
                        state: MachineState.empty.copyWith(
                          camera: 'ok',
                          previewPaused: false,
                          detections: const [
                            Detection(
                              label: 'bolt',
                              confidence: 0.96,
                              x: 0.2,
                              y: 0.2,
                              w: 0.3,
                              h: 0.3,
                            ),
                          ],
                        ),
                        connected: true,
                        keywords: const ['bolt', 'm10'],
                        onTogglePause: () {},
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. PartSelectorCard
                    PartSelectorCard(
                      selectedPart: samplePart,
                      availablePartsCount: 5,
                      onTapOpenCatalog: () {},
                    ),
                    const SizedBox(height: 16),

                    // 4. CountDashboardPanel
                    SizedBox(
                      height: 320,
                      child: CountDashboardPanel(
                        count: 24,
                        targetCount: 50,
                        status: CountDashboardStatus.counting,
                        statusTitle: 'COUNTING',
                        statusSubtitle: 'Batch in progress',
                        classBreakdowns: const [
                          ClassBreakdownItem(
                            label: 'M10 Hex Bolt',
                            count: 24,
                            color: Colors.amber,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. KioskFormControls
                    KioskCard(
                      child: Column(
                        children: [
                          KioskButton(
                            label: 'Start Inspection',
                            onPressed: () {},
                            variant: KioskButtonVariant.primary,
                            fullWidth: true,
                          ),
                          const SizedBox(height: 8),
                          KioskSwitch(
                            label: 'High Accuracy Mode',
                            subtitle: 'Enable sub-pixel inference alignment',
                            value: true,
                            onChanged: (_) {},
                          ),
                          const SizedBox(height: 8),
                          KioskSlider(
                            label: 'Confidence Threshold',
                            valueLabel: '90%',
                            value: 0.90,
                            onChanged: (_) {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('ONLINE'), findsOneWidget);
        expect(find.text('Camera Ready'), findsOneWidget);
        expect(find.text('yolo26n.onnx'), findsOneWidget);
        expect(find.text('LIVE 30 FPS'), findsOneWidget);
        expect(find.text('M10 Hex Bolt - High Tensile Steel'), findsOneWidget);
        expect(find.text('24'), findsNWidgets(2)); // hero count + breakdown count
        expect(find.text('Start Inspection'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Rapid theme switching between light, dark, and kioskHighContrast triggers smooth rebuilds without exception', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final themeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.light);

      await tester.pumpWidget(
        ValueListenableBuilder<AppThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, _) {
            return MaterialApp(
              theme: themeMap[currentMode],
              home: Scaffold(
                body: Column(
                  children: [
                    KioskHeaderStatusBar(
                      connectionState: DaemonConnectionState.connected,
                      cameraStatusText: 'Camera Ready',
                      activeModelName: 'yolo26n.onnx',
                      currentThemeMode: currentMode,
                      onThemeModeChanged: (newMode) => themeNotifier.value = newMode,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: CountDashboardPanel(
                        count: 100,
                        targetCount: 100,
                        status: CountDashboardStatus.counted,
                        statusTitle: 'COMPLETE',
                        statusSubtitle: 'Batch target met',
                        classBreakdowns: const [],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Cycle light -> dark
      themeNotifier.value = AppThemeMode.dark;
      await tester.pump(const Duration(milliseconds: 100));

      // Cycle dark -> kioskHighContrast
      themeNotifier.value = AppThemeMode.kioskHighContrast;
      await tester.pump(const Duration(milliseconds: 100));

      // Cycle kioskHighContrast -> light
      themeNotifier.value = AppThemeMode.light;
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });
}
