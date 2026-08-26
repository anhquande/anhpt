import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/workout.dart';

class AudioFeedbackService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  String _language = 'vi';
  bool _ready = false;
  Completer<void>? _speechCompleter;

  Future<void> configure(Workout workout) async {
    _language = workout.voice.language;

    // Do not use awaitSpeakCompletion(true) here. On desktop platforms it can
    // behave differently from mobile. Instead we resolve our own completer
    // from the TTS completion/cancel/error callbacks.
    _tts.setCompletionHandler(_finishWaitingSpeech);
    _tts.setCancelHandler(_finishWaitingSpeech);
    _tts.setErrorHandler((_) => _finishWaitingSpeech());

    await _tts.setLanguage(_language == 'vi' ? 'vi-VN' : 'en-US');
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _ready = true;
  }

  void _finishWaitingSpeech() {
    final completer = _speechCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _speechCompleter = null;
  }

  Future<void> stopSpeech() async {
    await _tts.stop();
    _finishWaitingSpeech();
  }

  /// Fire-and-forget speech. Use this for timer announcements/countdowns.
  Future<void> speak(String text, {bool interrupt = false}) async {
    if (!_ready || text.trim().isEmpty) return;
    if (interrupt) {
      await stopSpeech();
    }
    await _tts.speak(text);
  }

  /// Speaks [text] and waits until the engine reports completion.
  /// This is used for step name + guide so the step timer starts afterwards.
  Future<void> speakAndWait(
    String text, {
    bool interrupt = false,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!_ready || text.trim().isEmpty) return;

    if (interrupt) {
      await stopSpeech();
    }

    // Finish any stale waiter before starting a new utterance.
    _finishWaitingSpeech();
    final completer = Completer<void>();
    _speechCompleter = completer;

    try {
      await _tts.speak(text);
      await completer.future.timeout(
        timeout,
        onTimeout: () {
          _finishWaitingSpeech();
        },
      );
    } catch (_) {
      _finishWaitingSpeech();
      rethrow;
    }
  }

  Future<void> playCue(String cue) async {
    if (cue == 'none') return;
    final asset = switch (cue) {
      'bell' => 'audio/bell.wav',
      'click' => 'audio/click.wav',
      _ => 'audio/beep.wav',
    };
    await _player.stop();
    await _player.play(AssetSource(asset), volume: 0.75);
  }

  String remainingPhrase(int seconds) {
    if (_language == 'vi') return 'Còn $seconds giây';
    return '$seconds seconds remaining';
  }

  String startPhrase(String workoutName) {
    if (_language == 'vi') return 'Bắt đầu $workoutName';
    return 'Starting $workoutName';
  }

  String pausedPhrase() => _language == 'vi' ? 'Tạm dừng' : 'Paused';

  String resumePhrase(String stepName) =>
      _language == 'vi' ? 'Tiếp tục. $stepName' : 'Resume. $stepName';

  String finishPhrase() =>
      _language == 'vi' ? 'Hoàn thành. Làm tốt lắm!' : 'Workout complete. Great job!';

  Future<void> dispose() async {
    _finishWaitingSpeech();
    await _tts.stop();
    await _player.dispose();
  }
}
