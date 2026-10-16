import 'dart:async';

import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/services/exercise_event_voice_coach.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExerciseEvent event(String code, {int? rep}) => ExerciseEvent(
        type: ExerciseEventType.repetitionCompleted,
        timestamp: DateTime.utc(2026, 1, 1),
        code: code,
        repetitionCount: rep,
      );

  test('speaks a recognized event in the configured language', () async {
    final phrases = <String>[];
    final coach = ExerciseEventVoiceCoach(
      speak: (text) async { phrases.add(text); },
      canSpeak: () => true,
      isAudioBusy: () => false,
      language: () => 'vi',
    );
    coach.handle(event('squat_repetition_completed', rep: 2));
    await Future<void>.delayed(Duration.zero);
    expect(phrases, ['Lần 2']);
    coach.dispose();
  });

  test('drops events when muted, busy, or disposed', () async {
    var enabled = false;
    var busy = false;
    final phrases = <String>[];
    final coach = ExerciseEventVoiceCoach(
      speak: (text) async { phrases.add(text); },
      canSpeak: () => enabled,
      isAudioBusy: () => busy,
      language: () => 'en',
    );
    coach.handle(event('push_up_repetition_completed', rep: 1));
    enabled = true;
    busy = true;
    coach.handle(event('push_up_repetition_completed', rep: 1));
    busy = false;
    coach.handle(event('unknown'));
    coach.dispose();
    coach.handle(event('push_up_repetition_completed', rep: 1));
    await Future<void>.delayed(Duration.zero);
    expect(phrases, isEmpty);
  });

  test('rate limits and never queues overlapping speech', () async {
    var now = DateTime.utc(2026, 1, 1);
    final blocker = Completer<void>();
    final phrases = <String>[];
    final coach = ExerciseEventVoiceCoach(
      speak: (text) async {
        phrases.add(text);
        if (phrases.length == 1) await blocker.future;
      },
      canSpeak: () => true,
      isAudioBusy: () => false,
      language: () => 'en',
      clock: () => now,
    );
    coach.handle(event('squat_repetition_completed', rep: 1));
    // Still inside the cooldown when the first speech finishes.
    now = now.add(const Duration(seconds: 2));
    coach.handle(event('squat_repetition_completed', rep: 2));
    blocker.complete();
    await Future<void>.delayed(Duration.zero);
    coach.handle(event('squat_repetition_completed', rep: 3));
    now = now.add(const Duration(seconds: 4));
    coach.handle(event('squat_repetition_completed', rep: 4));
    await Future<void>.delayed(Duration.zero);
    expect(phrases, ['Rep 1', 'Rep 4']);
    coach.dispose();
  });
}
