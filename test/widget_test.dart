import 'package:beenut/main.dart';
import 'package:beenut/core/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ThemeController.update('system');
  });

  testWidgets('BeeNut app renders splash screen on launch', (tester) async {
    await tester.pumpWidget(const BeenutApp());

    expect(
      find.image(const AssetImage('assets/images/logo.png')),
      findsOneWidget,
    );
  });

  testWidgets('BeeNut app follows explicit theme mode changes', (tester) async {
    ThemeController.update('dark');
    await tester.pumpWidget(const BeenutApp());

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    ThemeController.update('light');
    await tester.pump();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
  });
}
