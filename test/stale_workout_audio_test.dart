import 'dart:async';

import 'package:anhpt/core/session_engine.dart';
import 'package:anhpt/models/workout.dart';
import 'package:anhpt/services/audio_feedback_service.dart';
import 'package:anhpt/services/voice_guide_controller.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('late callback from stopped TTS cannot complete the next operation',
      () async {
    final tts = _FakeFlutterTts();
    final service = AudioFeedbackService(tts: tts, initializePlayer: false);
    await service.configure(_workout());

    final first = service.speakAndWait('first');
    await Future<void>.delayed(Duration.zero);
    final firstCompletion = tts.completionHandlers.single;

    await service.stopSpeech();
    await first;

    var secondCompleted = false;
    final second = service.speakAndWait('second').then((_) {
      secondCompleted = true;
    });
    await Future<void>.delayed(Duration.zero);

    firstCompletion();
    await Future<void>.delayed(Duration.zero);
    expect(secondCompleted, isFalse);

    tts.completionHandlers.last();
    await second;
    expect(secondCompleted, isTrue);
  });

  test('pause invalidates an in-flight guide and replays it on resume',
      () async {
    final workout = _workout();
    final engine = SessionEngine(workout);
    final audio = _ControlledAudioFeedbackService();
    final controller = VoiceGuideController(
      workout: workout,
      engine: engine,
      audio: audio,
    );
    await controller.initialize();
    engine.start();

    final processing = controller.onEngineChanged();
    await audio.waitForAnnouncementCount(1);
    engine.pause();
    await controller.cancelCurrentWork(replayCurrentStep: true);
    await processing;
    expect(engine.announcementComplete, isFalse);

    engine.resume();
    final resumed = controller.onEngineChanged();
    await audio.waitForAnnouncementCount(2);
    audio.completeAnnouncement();
    await resumed;
    expect(engine.announcementComplete, isTrue);
  });

  test('end and dispose prevent an awaited guide completing the engine',
      () async {
    final workout = _workout();
    final engine = SessionEngine(workout);
    final audio = _ControlledAudioFeedbackService();
    final controller = VoiceGuideController(
      workout: workout,
      engine: engine,
      audio: audio,
    );
    await controller.initialize();
    engine.start();

    final processing = controller.onEngineChanged();
    await audio.waitForAnnouncementCount(1);
    engine.endEarly();
    controller.dispose();
    await processing;

    expect(engine.status, SessionStatus.incomplete);
    expect(engine.announcementComplete, isFalse);
    expect(audio.cancelCount, greaterThanOrEqualTo(1));
  });
}

Workout _workout() => WorkoutParser.parse('''
version: 1
name: Race test
start_countdown: 0s
voice:
  announce_start: false
steps:
  - name: First
    duration: 10s
    guide: A deliberately long guide.
  - name: Second
    duration: 1s
''', id: 'race-test', defaultVoiceLanguage: 'en');

class _FakeFlutterTts extends FlutterTts {
  final List<VoidCallback> completionHandlers = [];

  @override
  void setCompletionHandler(VoidCallback callback) {
    completionHandlers.add(callback);
  }

  @override
  void setCancelHandler(VoidCallback callback) {}

  @override
  void setErrorHandler(ErrorHandler handler) {}

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async => 1;

  @override
  Future<dynamic> stop() async => 1;
}

class _ControlledAudioFeedbackService extends AudioFeedbackService {
  _ControlledAudioFeedbackService() : super(initializePlayer: false);

  final List<Completer<void>> _announcements = [];
  int cancelCount = 0;

  @override
  Future<void> configure(Workout workout) async {}

  @override
  Future<void> stopSpeech() async {}

  @override
  Future<void> playCue(String cue) async {}

  @override
  Future<void> speak(String text, {bool interrupt = false}) async {}

  @override
  Future<void> speakAndWait(
    String text, {
    bool interrupt = false,
    Duration timeout = const Duration(seconds: 60),
  }) {
    final completer = Completer<void>();
    _announcements.add(completer);
    return completer.future;
  }

  Future<void> waitForAnnouncementCount(int count) async {
    while (_announcements.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void completeAnnouncement() {
    final active = _announcements.last;
    if (!active.isCompleted) active.complete();
  }

  @override
  Future<void> cancelCurrentAudio() async {
    cancelCount++;
    for (final announcement in _announcements) {
      if (!announcement.isCompleted) announcement.complete();
    }
  }
}
