import 'package:anhpt/models/workout_draft.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:anhpt/services/workout_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy voice modes map to independent timing flags', () {
    final expected = {
      'continuous': [true, false, false],
      'interval': [false, true, false],
      'ending': [false, false, true],
      'combined': [false, true, true],
    };
    for (final mode in expected.entries) {
      final workout = WorkoutParser.parse(
        '''
version: 2
name: Legacy mode
voice:
  mode: ${mode.key}
steps:
  - name: Plank
    duration: 30s
''',
        id: 'legacy-mode',
        defaultVoiceLanguage: 'en',
      );
      expect(workout.voice.announceElapsedTime, mode.value[0]);
      expect(workout.voice.announceInterval, mode.value[1]);
      expect(workout.voice.announceFinalCountdown, mode.value[2]);
    }
  });

  test('legacy voice timing durations remain supported', () {
    final workout = WorkoutParser.parse(
      '''
version: 2
name: Legacy fields
voice:
  announce_every: 10s
  countdown_from: 5s
steps:
  - name: Plank
    duration: 30s
''',
      id: 'legacy-fields',
      defaultVoiceLanguage: 'en',
    );

    expect(workout.voice.announceEvery, const Duration(seconds: 10));
    expect(workout.voice.countdownFrom, const Duration(seconds: 5));
  });

  test('new timing flags can be combined independently', () {
    final workout = WorkoutParser.parse(
      '''
version: 2
name: Independent timing
voice:
  timing:
    elapsed_time: true
    interval: false
    interval_every: 15s
    final_countdown: true
    countdown_from: 3s
steps:
  - name: Plank
    duration: 30s
''',
      id: 'independent',
      defaultVoiceLanguage: 'en',
    );

    expect(workout.voice.announceElapsedTime, isTrue);
    expect(workout.voice.announceInterval, isFalse);
    expect(workout.voice.announceFinalCountdown, isTrue);
    expect(workout.voice.announceEvery, const Duration(seconds: 15));
    expect(workout.voice.countdownFrom, const Duration(seconds: 3));
  });

  test('serializer writes named timing flags instead of mode', () {
    final yaml = WorkoutSerializer.toYaml(
      WorkoutDraft(
        name: 'Timing flags',
        announceElapsedTime: true,
        announceInterval: true,
        announceFinalCountdown: false,
        announceEvery: '15s',
        countdownFrom: '5s',
        steps: [StepDraft(name: 'Plank', duration: '30s')],
      ),
    );

    expect(yaml, contains('  timing:'));
    expect(yaml, contains('    elapsed_time: true'));
    expect(yaml, contains('    interval: true'));
    expect(yaml, contains('    interval_every: 15s'));
    expect(yaml, contains('    final_countdown: false'));
    expect(yaml, isNot(contains('  mode:')));
  });
}
