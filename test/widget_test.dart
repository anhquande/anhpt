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
      ]
      ..installedBucketWorkouts = [
        InstalledWorkoutProvenance(
          workoutId: 'sticky',
          sourceId: 'official',
          sourceName: 'AnhPT Official',
          entryId: 'original-sticky-workout',
          originalName: 'Original Sticky Workout',
          version: '1.0.0',
          packageUrl: 'https://example.com/sticky.zip',
          sha256: 'a' * 64,
          installedAt: DateTime.utc(2026, 8, 28),
        ),
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
    expect(
      find.text('From AnhPT Official · Originally “Original Sticky Workout”'),
      findsOneWidget,
    );
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
      'View source',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('View source'));
    await tester.pumpAndSettle();
    expect(find.text('Source: AnhPT Official'), findsOneWidget);
    expect(find.text('Workout ID: original-sticky-workout'), findsOneWidget);
    expect(find.text('Original name: Original Sticky Workout'), findsOneWidget);
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

  testWidgets('Home is compact and searches local workouts without accents',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore())
      ..workouts = [
        WorkoutParser.parse('''
version: 2
name: Khởi động nhanh
tags: [Mobility]
steps:
  - name: Move
''', id: 'warmup', defaultVoiceLanguage: 'vi'),
        WorkoutParser.parse('''
version: 2
name: Strength Builder
steps:
  - name: Lift
''', id: 'strength', defaultVoiceLanguage: 'en'),
      ]
      ..installedBucketWorkouts = [
        InstalledWorkoutProvenance(
          workoutId: 'warmup',
          sourceId: 'official',
          sourceName: 'AnhPT Official',
          entryId: 'morning-warmup',
          originalName: 'Morning Warmup',
          version: '1.0.0',
          packageUrl: 'https://example.com/warmup.zip',
          sha256: 'b' * 64,
          installedAt: DateTime.utc(2026, 8, 28),
        ),
      ];

    await tester
        .pumpWidget(MaterialApp(home: HomeScreen(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('My Workouts'), findsOneWidget);
    expect(find.text('New workout'), findsOneWidget);
    expect(find.text('Browse workouts'), findsOneWidget);
    expect(find.text('From AnhPT Official'), findsOneWidget);
    expect(find.text('Originally “Morning Warmup”'), findsOneWidget);
    expect(find.text('Import package'), findsNothing);
    expect(find.text('Import YAML'), findsNothing);
    expect(find.byTooltip('More ways to add'), findsOneWidget);
    expect(find.byTooltip('Import workouts'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Ready to move?'), findsNothing);

    await tester.tap(find.byTooltip('More ways to add'));
    await tester.pumpAndSettle();
    expect(find.text('Import package'), findsOneWidget);
    expect(find.text('Import YAML'), findsOneWidget);

    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'khoi dong');
    await tester.pump();
    expect(find.text('Khởi động nhanh'), findsOneWidget);
    expect(find.text('Strength Builder'), findsNothing);
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
    expect(find.text('Workout sources'), findsOneWidget);
    expect(find.textContaining('Windows Privacy settings'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Home opens Browse Workouts with accent-insensitive search',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore())
      ..bucketSources = const [
        WorkoutBucketSource(
          id: 'official',
          name: 'Official',
          catalogUrl: 'https://example.com/bucket.json',
        ),
      ]
      ..bucketCatalogEntries = [
        WorkoutBucketEntry(
          sourceId: 'official',
          id: 'warmup',
          name: 'Khởi động buổi sáng',
          description: 'Nhẹ nhàng bắt đầu ngày mới.',
          version: '1.0.0',
          packageUrl: 'https://example.com/warmup.zip',
          sha256: List.filled(64, '0').join(),
          tags: const ['Beginner', 'Mobility'],
        ),
        WorkoutBucketEntry(
          sourceId: 'official',
          id: 'strength',
          name: 'Strength Builder',
          version: '1.0.0',
          packageUrl: 'https://example.com/strength.zip',
          sha256: List.filled(64, '1').join(),
        ),
      ];

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(controller: controller),
    ));
    await tester.tap(find.text('Browse workouts'));
    await tester.pumpAndSettle();

    expect(find.text('Browse Workouts'), findsOneWidget);
    expect(find.text('Khởi động buổi sáng'), findsOneWidget);
    expect(find.text('Strength Builder'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'khoi dong');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Khởi động buổi sáng'), findsOneWidget);
    expect(find.text('Strength Builder'), findsNothing);

    await tester.tap(find.byTooltip('Manage workout sources'));
    await tester.pumpAndSettle();
    expect(find.text('Workout sources'), findsOneWidget);
  });
}
