import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/app/workout_camera_preference.dart';
import 'package:anhpt/screens/workout_player_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:anhpt/widgets/workout_camera_comparison.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('End workout disables side by side camera before summary exit', (
    tester,
  ) async {
    // Android avoids loading the Windows DLL in the widget-test process.
    // Windows capture teardown is covered with an injected UVC camera separately.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final preference = WorkoutCameraPreference.instance;
    await preference.initialize();
    await preference.setAutoStart(true);
    await preference.setLayout(WorkoutCameraLayout.split);
    final controller = AppController(LocalStore());
    controller.workouts = [
      WorkoutParser.parse(
        '''
version: 2
name: Stop camera regression
start_countdown: 30s
voice:
  announce_start: false
  announce_step_name: false
  announce_finish: false
steps:
  - name: Hold
    duration: 30s
''',
        id: 'stop-camera',
        defaultVoiceLanguage: 'en',
      ),
    ];
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutPlayerScreen(
            controller: controller,
            workoutId: 'stop-camera',
          ),
        ),
      );
      await tester.pump();
      var comparison = tester.widget<WorkoutCameraComparison>(
        find.byType(WorkoutCameraComparison),
      );
      expect(comparison.layout, WorkoutCameraLayout.split);
      expect(comparison.cameraEnabled, isTrue);
      await tester.tap(find.byTooltip('End workout'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(FilledButton, 'End'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      comparison = tester.widget<WorkoutCameraComparison>(
        find.byType(WorkoutCameraComparison),
      );
      expect(comparison.cameraEnabled, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
      await preference.setAutoStart(false);
      await preference.setLayout(WorkoutCameraLayout.pictureInPicture);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
