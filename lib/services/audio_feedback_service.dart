import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/workout.dart';

class AudioFeedbackService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  String _language = 'vi';
  bool _ready = false;

  Future<void> configure(Workout workout) async {
    _language = workout.voice.language;
    await _tts.setLanguage(_language == 'vi' ? 'vi-VN' : 'en-US');
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }

  Future<void> stopSpeech() async {
    await _tts.stop();
  }

  Future<void> speak(String text, {bool interrupt = false}) async {
    if (!_ready || text.trim().isEmpty) return;
    if (interrupt) {
      await _tts.stop();
    }
    await _tts.speak(text);
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
    await _tts.stop();
    await _player.dispose();
  }
}
