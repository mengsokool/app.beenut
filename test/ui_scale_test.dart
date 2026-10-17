import 'package:beenut/core/ui_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.linux, TargetPlatform.macOS]) {
    testWidgets('scales an 800x480 $platform kiosk window', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = const Size(800, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Size? available;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: UiScaleScope(
            scale: 1.5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                available = constraints.biggest;
                return const Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    key: ValueKey('target'),
                    width: 100,
                    height: 48,
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(available!.width, closeTo(800 / 1.5, .01));
      expect(available!.height, closeTo(480 / 1.5, .01));
      expect(tester.getRect(find.byKey(const ValueKey('target'))).width, 150);
      expect(tester.getRect(find.byKey(const ValueKey('target'))).height, 72);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact Android keeps the viewport for orientation layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.physicalSize = const Size(800, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: const UiScaleScope(
          scale: 1.5,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(key: ValueKey('target'), width: 100, height: 48),
          ),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const ValueKey('target'))).width, 100);
    expect(tester.takeException(), isNull);
  });
}
