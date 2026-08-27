import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/main.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/screens/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app shows onboarding on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());
    await controller.initialize();

    await tester.pumpWidget(AnhPtApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('AnhPT'), findsWidgets);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('settings owns Windows microphone permission guidance',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(controller: controller),
    ));
    await tester.pump();

    expect(find.text('Microphone access'), findsOneWidget);
    expect(find.textContaining('Windows Privacy settings'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
