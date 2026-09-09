import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/screens/workout_history_screen.dart';
import 'package:anhpt/screens/workout_session_detail_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session({
  required String id,
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
  int completedSteps = 4,
  int totalSteps = 4,
  String? profileName = 'Me',
}) {
  final endedAt = DateTime(2026, 9, 9, 7, 30);
  return WorkoutSession(
    id: id,
    workoutId: 'demo-workout',
    workoutName: 'Morning Mobility',
    profileId: 'me',
    profileName: profileName,
    startedAt: endedAt.subtract(const Duration(minutes: 18)),
    endedAt: endedAt,
    activeDuration: const Duration(minutes: 18),
    completedSteps: completedSteps,
    totalSteps: totalSteps,
    status: status,
  );
}

AppController _controller({bool includeWorkout = true}) {
  final controller = AppController(LocalStore());
  if (includeWorkout) {
    controller.workouts = [
      WorkoutParser.parse(
        '''
version: 2
name: Morning Mobility
start_countdown: 0s
voice:
  language: en
  announce_start: false
  announce_step_name: false
  announce_finish: false
steps:
  - name: Reach up
    duration: 30s
''',
        id: 'demo-workout',
        defaultVoiceLanguage: 'en',
      ),
    ];
  }
  return controller;
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes += 1;
    super.didPush(route, previousRoute);
  }
}

void main() {
  testWidgets('completed session detail shows persisted summary fields',
      (tester) async {
    final session = _session(id: 'completed');

    await tester.pumpWidget(
      MaterialApp(home: WorkoutSessionDetailScreen(session: session)),
    );

    expect(find.text('Session details'), findsOneWidget);
    expect(find.text('Morning Mobility'), findsOneWidget);
    expect(find.text('Workout completed'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('18 min'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('incomplete session shows neutral partial-progress state',
      (tester) async {
    final session = _session(
      id: 'incomplete',
      status: WorkoutSessionStatus.incomplete,
      completedSteps: 2,
      totalSteps: 5,
    );

    await tester.pumpWidget(
      MaterialApp(home: WorkoutSessionDetailScreen(session: session)),
    );

    expect(find.text('Incomplete session'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(
      find.text(
        'Progress reflects the steps recorded before this session ended.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('zero-step session renders zero progress safely and hides profile',
      (tester) async {
    final session = _session(
      id: 'zero',
      completedSteps: 0,
      totalSteps: 0,
      profileName: null,
    );

    await tester.pumpWidget(
      MaterialApp(home: WorkoutSessionDetailScreen(session: session)),
    );

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('session-detail-progress')),
    );
    expect(progress.value, 0);
  });

  testWidgets('tapping workout history session opens its detail screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final session = _session(id: 'history');
    await store.saveWorkoutSessions([session]);
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutHistoryScreen(
          store: store,
          profileId: 'me',
          profileName: 'Me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('workout-history-session-history')),
        findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('workout-history-session-history')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Session details'), findsOneWidget);
    expect(find.text('Morning Mobility'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('installed workout exposes repeat action', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _controller();

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutSessionDetailScreen(
          session: _session(id: 'repeat-installed'),
          controller: controller,
        ),
      ),
    );

    expect(find.text('Repeat workout'), findsOneWidget);
    expect(
      find.byKey(const Key('session-detail-repeat-workout')),
      findsOneWidget,
    );
  });

  testWidgets('removed workout does not expose a broken repeat action',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _controller(includeWorkout: false);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutSessionDetailScreen(
          session: _session(id: 'repeat-missing'),
          controller: controller,
        ),
      ),
    );

    expect(find.text('Repeat workout'), findsNothing);
    expect(
      find.byKey(const Key('session-detail-repeat-workout')),
      findsNothing,
    );
  });

  testWidgets('repeat action pushes the existing workout flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _controller();
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: WorkoutSessionDetailScreen(
          session: _session(id: 'repeat-navigation'),
          controller: controller,
        ),
      ),
    );

    expect(observer.pushes, 1);
    await tester.tap(find.text('Repeat workout'));

    expect(observer.pushes, 2);
  });
}
