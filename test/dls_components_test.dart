import 'package:beenut/core/models.dart';
import 'package:beenut/core/theme.dart';
import 'package:beenut/core/theme_controller.dart';
import 'package:beenut/ui/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testThemes = <String, ThemeData>{
    'Light Warm Mode': BeenutTheme.light,
    'Dark Obsidian Mode': BeenutTheme.dark,
    'Kiosk High-Contrast': BeenutTheme.kioskHighContrast,
  };

  const samplePart1 = PartType(
    id: 'm10_bolt',
    name: 'M10 Hex Bolt',
    image: '',
    keywords: ['bolt', 'm10'],
    enabled: true,
  );

  const samplePart2 = PartType(
    id: 'm8_nut',
    name: 'M8 Flange Nut',
    image: '',
    keywords: ['nut'],
    enabled: true,
  );

  group('Group 1: KioskHeaderStatusBar Widget Tests', () {
    for (final entry in testThemes.entries) {
      testWidgets('KioskHeaderStatusBar renders correctly in ${entry.key}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1024, 120));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        AppThemeMode selectedThemeMode = AppThemeMode.light;

        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            home: Scaffold(
              body: Center(
                child: KioskHeaderStatusBar(
                  connectionState: DaemonConnectionState.connected,
                  cameraStatusText: 'Camera Ready',
                  activeModelName: 'yolo26n.onnx',
                  currentThemeMode: AppThemeMode.light,
                  hardwareTemperature: 42.5,
                  onThemeModeChanged: (mode) => selectedThemeMode = mode,
                  onOpenSettings: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('ONLINE'), findsOneWidget);
        expect(find.text('Camera Ready'), findsOneWidget);
        expect(find.text('yolo26n.onnx'), findsOneWidget);
        expect(find.text('42.5°C'), findsOneWidget);

        // Tap theme toggle button
        await tester.tap(find.byTooltip('Switch Theme Mode'));
        await tester.pumpAndSettle();

        expect(find.text('Light Warm Mode'), findsOneWidget);
        expect(find.text('Dark Obsidian Mode'), findsOneWidget);
        expect(find.text('Kiosk High Contrast'), findsOneWidget);

        // Select Dark Mode
        await tester.tap(find.text('Dark Obsidian Mode'));
        await tester.pumpAndSettle();
        expect(selectedThemeMode, AppThemeMode.dark);
      });
    }
  });

  group('Group 2: LiveStreamCameraPane Widget Tests', () {
    for (final entry in testThemes.entries) {
      testWidgets(
        'LiveStreamCameraPane renders preview & overlay in ${entry.key}',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          bool pauseToggled = false;

          await tester.pumpWidget(
            MaterialApp(
              theme: entry.value,
              home: Scaffold(
                body: Center(
                  child: LiveStreamCameraPane(
                    state: MachineState.empty.copyWith(
                      camera: 'ready',
                      previewPaused: false,
                      detections: const [
                        Detection(
                          label: 'bolt',
                          confidence: 0.98,
                          x: 0.2,
                          y: 0.2,
                          w: 0.3,
                          h: 0.3,
                        ),
                      ],
                    ),
                    connected: true,
                    keywords: const ['bolt', 'nut'],
                    onTogglePause: () => pauseToggled = true,
                  ),
                ),
              ),
            ),
          );

          expect(find.text('LIVE 30 FPS'), findsOneWidget);
          expect(find.text('PAUSE'), findsOneWidget);

          await tester.tap(find.text('PAUSE'));
          await tester.pump();
          expect(pauseToggled, isTrue);
        },
      );

      testWidgets(
        'LiveStreamCameraPane shows paused message overlay when paused',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: entry.value,
              home: Scaffold(
                body: LiveStreamCameraPane(
                  state: MachineState.empty.copyWith(previewPaused: true),
                  connected: true,
                  keywords: const ['bolt'],
                ),
              ),
            ),
          );

          expect(find.text('VIDEO STREAM PAUSED'), findsOneWidget);
          expect(find.text('PAUSED'), findsOneWidget);
        },
      );
    }
  });

  group('Group 3: PartSelectorCard & PartCatalogSelector Widget Tests', () {
    for (final entry in testThemes.entries) {
      testWidgets(
        'PartSelectorCard renders active part and opens catalog sheet in ${entry.key}',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          bool openCatalogTriggered = false;

          await tester.pumpWidget(
            MaterialApp(
              theme: entry.value,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: PartSelectorCard(
                      selectedPart: samplePart1,
                      availablePartsCount: 2,
                      onTapOpenCatalog: () => openCatalogTriggered = true,
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.text('M10 Hex Bolt'), findsOneWidget);
          expect(find.text('2 classes mapped'), findsOneWidget);

          await tester.tap(find.byType(PartSelectorCard));
          await tester.pump();
          expect(openCatalogTriggered, isTrue);
        },
      );

      testWidgets(
        'PartCatalogSelector displays search and filters parts correctly',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          PartType? selectedPart;

          await tester.pumpWidget(
            MaterialApp(
              theme: entry.value,
              home: Scaffold(
                body: PartCatalogSelector(
                  parts: [
                    samplePart1,
                    samplePart2,
                    for (var i = 0; i < 7; i++)
                      PartType(
                        id: 'part-$i',
                        name: 'Part $i',
                        image: '',
                        keywords: const [],
                        enabled: true,
                      ),
                  ],
                  selectedId: 'm10_bolt',
                  onSelectPart: (part) => selectedPart = part,
                ),
              ),
            ),
          );

          expect(find.text('Choose target'), findsOneWidget);
          expect(find.text('M10 Hex Bolt'), findsOneWidget);
          expect(find.text('M8 Flange Nut'), findsOneWidget);

          // Enter search text "Nut"
          await tester.enterText(find.byType(TextField), 'Nut');
          await tester.pump();

          expect(find.text('M8 Flange Nut'), findsOneWidget);
          expect(find.text('M10 Hex Bolt'), findsNothing);

          // Tap selected part
          await tester.tap(find.text('M8 Flange Nut'));
          await tester.pump();

          expect(selectedPart?.id, 'm8_nut');
        },
      );
    }
  });

  group('Group 4: CountDashboardPanel Widget Tests', () {
    for (final entry in testThemes.entries) {
      testWidgets(
        'CountDashboardPanel displays 88pt hero count and class breakdowns in ${entry.key}',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(600, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MaterialApp(
              theme: entry.value,
              home: Scaffold(
                body: CountDashboardPanel(
                  count: 42,
                  targetCount: 50,
                  status: CountDashboardStatus.counted,
                  statusTitle: 'Counted',
                  statusSubtitle: 'Items processed',
                  classBreakdowns: const [
                    ClassBreakdownItem(
                      label: 'm10_bolt',
                      count: 30,
                      color: Colors.amber,
                    ),
                    ClassBreakdownItem(
                      label: 'm8_nut',
                      count: 12,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(find.text('42'), findsOneWidget);
          expect(find.text('Counted'), findsOneWidget);
          expect(find.text('TARGET'), findsOneWidget);
          expect(find.text('50'), findsOneWidget);
          expect(find.text('REMAINING'), findsOneWidget);
          expect(find.text('Breakdown by Class'), findsOneWidget);
          expect(find.text('m10_bolt'), findsOneWidget);
          expect(find.text('30'), findsOneWidget);
          expect(find.text('m8_nut'), findsOneWidget);
          expect(find.text('12'), findsOneWidget);
        },
      );
    }
  });

  group('Group 5: KioskFormControls Widget Tests', () {
    for (final entry in testThemes.entries) {
      testWidgets(
        'KioskFormControls enforce touch targets and callbacks in ${entry.key}',
        (tester) async {
          bool buttonPressed = false;
          bool switchVal = false;
          double sliderVal = 0.5;

          await tester.pumpWidget(
            MaterialApp(
              theme: entry.value,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      KioskButton(
                        label: 'Submit Action',
                        onPressed: () => buttonPressed = true,
                      ),
                      StatefulBuilder(
                        builder: (context, setState) {
                          return KioskSwitch(
                            label: 'Enable Feature',
                            value: switchVal,
                            onChanged: (val) => setState(() => switchVal = val),
                          );
                        },
                      ),
                      StatefulBuilder(
                        builder: (context, setState) {
                          return KioskSlider(
                            label: 'Brightness',
                            value: sliderVal,
                            onChanged: (val) => setState(() => sliderVal = val),
                          );
                        },
                      ),
                      KioskTextField(
                        controller: TextEditingController(text: 'Initial Text'),
                        label: 'Operator Note',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // Verify min 48dp height on KioskButton
          final btnSize = tester.getSize(find.byType(KioskButton));
          expect(btnSize.height, greaterThanOrEqualTo(48.0));

          // Tap KioskButton
          await tester.tap(find.text('Submit Action'));
          await tester.pump();
          expect(buttonPressed, isTrue);

          // Tap KioskSwitch
          await tester.tap(find.text('Enable Feature'));
          await tester.pump();
          expect(switchVal, isTrue);
        },
      );
    }
  });
}
