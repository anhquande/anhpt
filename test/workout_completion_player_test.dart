import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/screens/workout_player_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('completed Player is replaced by workout completion summary',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());
    controller.workouts = [
      WorkoutParser.parse(
        '''
version: 2
name: Completion flow test
start_countdown: 0s
voice:
  language: en
  announce_start: false
  announce_step_name: false
  announce_finish: false
steps:
  - name: Short step
    duration: 0s
''',
        id: 'completion-flow-test',
        defaultVoiceLanguage: 'en',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutPlayerScreen(
          controller: controller,
          workoutId: 'completion-flow-test',
          profileName: 'Test profile',
        ),
      ),
    );

    // SessionEngine measures timed steps with a real Stopwatch, which is not
    // advanced by WidgetTester.pump. A zero-duration step is valid AnhPT YAML
    // and lets this integration test verify the Player -> Summary transition
    // without depending on wall-clock timing or plugin initialization speed.
    for (var i = 0;
        i < 30 && find.text('Workout complete 🎉').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(find.text('Workout complete 🎉'), findsOneWidget);
    expect(find.text('Completion flow test'), findsOneWidget);
    expect(find.text('Test profile'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
