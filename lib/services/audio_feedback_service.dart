import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/workout.dart';

class AudioFeedbackService {
  final void Function(bool active)? onCoachAudioChanged;
  final FlutterTts _tts;
  final AudioPlayer? _player;

  String _language = 'vi';
  bool _ready = false;
  int _nextOperationId = 0;
  int? _activeSpeechOperationId;
  Completer<void>? _speechCompleter;
  int? _activeRecordingOperationId;
  Completer<void>? _recordingCompleter;
  bool _disposed = false;

  AudioFeedbackService({
    this.onCoachAudioChanged,
    FlutterTts? tts,
    AudioPlayer? player,
    @visibleForTesting bool initializePlayer = true,
  })  : _tts = tts ?? FlutterTts(),
        _player = player ?? (initializePlayer ? AudioPlayer() : null);

  static AudioContext mixingAudioContext() => const AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build();

  Future<void> configure(Workout workout) async {
    if (_disposed) throw StateError('Audio feedback service is disposed.');
    _language = workout.voice.language;

    // Coach recordings/cues must mix with the already-playing workout music.
    // AnhPT performs its own ducking, so Android audio focus must not pause the
    // background player when coach audio starts.
    await _player?.setAudioContext(mixingAudioContext());

    // Do not use awaitSpeakCompletion(true) here. On desktop platforms it can
    // behave differently from mobile. Instead we resolve our own completer
    // from the TTS completion/cancel/error callbacks.
    await _tts.setLanguage(_language == 'vi' ? 'vi-VN' : 'en-US');
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    if (_disposed) throw StateError('Audio feedback service is disposed.');
    _ready = true;
  }

  int _beginSpeechOperation() {
    final operationId = ++_nextOperationId;
    _activeSpeechOperationId = operationId;
    _tts.setCompletionHandler(() => _finishWaitingSpeech(operationId));
    _tts.setCancelHandler(() => _finishWaitingSpeech(operationId));
    _tts.setErrorHandler((_) => _finishWaitingSpeech(operationId));
    return operationId;
  }

  void _finishWaitingSpeech(int operationId) {
    if (_activeSpeechOperationId != operationId) return;
    final completer = _speechCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _speechCompleter = null;
    _activeSpeechOperationId = null;
    onCoachAudioChanged?.call(false);
  }

  void _invalidateSpeech() {
    _nextOperationId++;
    _activeSpeechOperationId = null;
    final completer = _speechCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    _speechCompleter = null;
    onCoachAudioChanged?.call(false);
  }

  void _invalidateRecording() {
    _nextOperationId++;
    _activeRecordingOperationId = null;
    final completer = _recordingCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    _recordingCompleter = null;
    onCoachAudioChanged?.call(false);
  }

  Future<void> stopSpeech() async {
    _invalidateSpeech();
    await _tts.stop();
  }

  /// Invalidates all current callbacks synchronously, then stops the backends.
  Future<void> cancelCurrentAudio() async {
    _invalidateSpeech();
    _invalidateRecording();
    await Future.wait([
      _tts.stop(),
      if (_player != null) _player.stop(),
    ]);
  }

  /// Fire-and-forget speech. Use this for timer announcements/countdowns.
  Future<void> speak(String text, {bool interrupt = false}) async {
    if (_disposed || !_ready || text.trim().isEmpty) return;
    if (interrupt) {
      await stopSpeech();
    }
    final operationId = _beginSpeechOperation();
    onCoachAudioChanged?.call(true);
    try {
      await _tts.speak(text);
    } catch (_) {
      _finishWaitingSpeech(operationId);
      rethrow;
    }
  }

  /// Speaks [text] and waits until the engine reports completion.
  /// This is used for step name + guide so the step timer starts afterwards.
  Future<void> speakAndWait(
    String text, {
    bool interrupt = false,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (_disposed || !_ready || text.trim().isEmpty) return;

    if (interrupt) {
      await stopSpeech();
    }

    _invalidateSpeech();
    final operationId = _beginSpeechOperation();
    final completer = Completer<void>();
    _speechCompleter = completer;

    try {
      onCoachAudioChanged?.call(true);
      await _tts.speak(text);
      await completer.future.timeout(
        timeout,
        onTimeout: () {
          _finishWaitingSpeech(operationId);
        },
      );
    } catch (_) {
      _finishWaitingSpeech(operationId);
      rethrow;
    }
  }

  Future<void> playCue(String cue) async {
    if (_disposed || cue == 'none') return;
    final asset = switch (cue) {
      'bell' => 'audio/bell.wav',
      'click' => 'audio/click.wav',
      _ => 'audio/beep.wav',
    };
    _invalidateRecording();
    await _player?.stop();
    await _player?.play(AssetSource(asset), volume: 0.75);
  }

  Future<bool> playLocalRecordingAndWait(String path) async {
    if (_disposed ||
        _player == null ||
        path.trim().isEmpty ||
        !await File(path).exists()) {
      return false;
    }
    _invalidateRecording();
    final operationId = ++_nextOperationId;
    _activeRecordingOperationId = operationId;
    final completer = Completer<void>();
    _recordingCompleter = completer;
    late final StreamSubscription<void> subscription;
    subscription = _player.onPlayerComplete.listen((_) {
      if (_activeRecordingOperationId == operationId &&
          !completer.isCompleted) {
        completer.complete();
      }
    });
    try {
      onCoachAudioChanged?.call(true);
      await _player.stop();
      await _player.play(DeviceFileSource(path));
      await completer.future.timeout(const Duration(minutes: 5));
      return _activeRecordingOperationId == operationId && !_disposed;
    } catch (_) {
      return false;
    } finally {
      if (_activeRecordingOperationId == operationId) {
        _activeRecordingOperationId = null;
        _recordingCompleter = null;
        onCoachAudioChanged?.call(false);
      }
      await subscription.cancel();
    }
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

  String finishPhrase() => _language == 'vi'
      ? 'Hoàn thành. Làm tốt lắm!'
      : 'Workout complete. Great job!';

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _invalidateSpeech();
    _invalidateRecording();
    await _tts.stop();
    await _player?.stop();
    await _player?.dispose();
  }
}
