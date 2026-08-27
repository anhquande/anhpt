import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/main.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/screens/settings_screen.dart';
import 'package:anhpt/screens/home_screen.dart';
import 'package:anhpt/models/workout_bucket.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:anhpt/screens/workout_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('workout overview has a sticky title, Start, and action menu',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore())
      ..workouts = [
        WorkoutParser.parse('''
version: 2
name: Sticky workout title
description: This is a deliberately long workout description that explains the goal, expected intensity, preparation, breathing, movement quality, and completion criteria so the Overview can verify its compact expandable presentation without overwhelming the structure below.
tags:
  - Strength
  - Beginner
steps:
${List.generate(18, (index) => '  - name: Step ${index + 1}\n    duration: 10s').join('\n')}
''', id: 'sticky', defaultVoiceLanguage: 'en'),
      ];

    await tester.pumpWidget(MaterialApp(
      home: WorkoutDetailScreen(controller: controller, workoutId: 'sticky'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sticky workout title'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    expect(find.byTooltip('Workout actions'), findsOneWidget);
    expect(find.text('START WORKOUT'), findsNothing);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Beginner'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Structure'), findsOneWidget);
    expect(find.text('Step 1'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Less'), findsOneWidget);

    await tester.drag(find.byKey(const PageStorageKey('structure-tab')),
        const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Sticky workout title'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);

    await tester.tap(find.text('Introduction'));
    await tester.pumpAndSettle();
    expect(find.text('Workout introduction recording'), findsOneWidget);
    expect(find.byTooltip('Record workout introduction'), findsOneWidget);

    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    expect(find.text('Background music'), findsOneWidget);

    await tester.tap(find.byTooltip('Workout actions'));
    await tester.pumpAndSettle();
    for (final label in [
      'Edit',
      'Duplicate',
      'Copy YAML',
      'Edit YAML',
      'Export package',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

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
