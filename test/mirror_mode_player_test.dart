import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/screens/workout_player_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Workout Player presents camera comparison as Mirror Mode', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      SharedPreferences.setMockInitialValues({});
      final controller = AppController(LocalStore());
      controller.workouts = [
        WorkoutParser.parse(
          '''
version: 2
name: Mirror Mode test
start_countdown: 30s
voice:
  language: en
  announce_start: false
  announce_step_name: false
  announce_finish: false
steps:
  - name: Hold position
    duration: 30s
''',
          id: 'mirror-mode-test',
          defaultVoiceLanguage: 'en',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutPlayerScreen(
            controller: controller,
            workoutId: 'mirror-mode-test',
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Mirror Mode'), findsOneWidget);

      await tester.tap(find.byTooltip('Mirror Mode'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Mirror Mode'), findsOneWidget);
      expect(
        find.text('Compare your movement with the demonstration.'),
        findsOneWidget,
      );
      expect(find.text('Demonstration only'), findsOneWidget);
      expect(find.text('Demo main / You small'), findsOneWidget);
      expect(find.text('You main / Demo small'), findsOneWidget);
      expect(find.text('Side by side'), findsOneWidget);
      expect(find.text('Overlay comparison'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
