import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/main.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/screens/settings_screen.dart';
import 'package:anhpt/screens/home_screen.dart';
import 'package:anhpt/models/workout_bucket.dart';
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
    expect(find.text('Workout Buckets'), findsOneWidget);
    expect(find.textContaining('Windows Privacy settings'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('bucket catalog supports back navigation and return to Home',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore())
      ..bucketSources = const [
        WorkoutBucketSource(
          id: 'official',
          name: 'Official',
          catalogUrl: 'https://example.com/bucket.json',
        ),
      ];

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(controller: controller),
    ));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workout Buckets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse catalog'));
    await tester.pumpAndSettle();

    expect(find.text('Workout Catalog'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Workout Buckets'), findsOneWidget);

    await tester.tap(find.text('Browse catalog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Return to Home'));
    await tester.pumpAndSettle();
    expect(find.text('My Workouts'), findsOneWidget);
    expect(find.text('Workout Catalog'), findsNothing);
  });
}
