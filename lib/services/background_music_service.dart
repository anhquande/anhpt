import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import '../models/background_music.dart';

class BackgroundMusicService {
  final AudioPlayer _player = AudioPlayer();
  late final AudioDuckingController _duckingController =
      AudioDuckingController(setVolume: _player.setVolume);
  bool _started = false;
  String? lastError;

  bool get started => _started;
  static double duckFactor(String mode) => switch (mode) {
        'off' => 1.0,
        'medium' => .6,
        'high' => .4,
        'very_high' => .2,
        _ => .82,
      };

  Future<bool> start(MusicTrack track, WorkoutMusicConfig config) async {
    lastError = null;
    if (!config.enabled || config.trackId == null) {
      lastError = 'Music is disabled or no track is selected.';
      return false;
    }
    if (!track.bundled && !await File(track.source).exists()) {
      lastError = 'The selected local track file is missing.';
      return false;
    }
    _duckingController.update(
      baseVolume: config.baseVolume,
      duckingMode: config.duckingMode,
      fade: false,
    );
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setVolume(_duckingController.targetVolume);
      final playing = _player.onPlayerStateChanged
          .firstWhere((state) => state == PlayerState.playing)
          .timeout(const Duration(seconds: 5));
      await _player.play(track.bundled
          ? AssetSource(track.source)
          : DeviceFileSource(track.source));
      await playing;
      _duckingController.syncCurrentVolume();
      _started = true;
      return true;
    } catch (error) {
      _started = false;
      lastError = error.toString();
      await _player.stop();
      return false;
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _started ? _player.resume() : Future.value();

  void setCoachActive(bool active) {
    if (!_started) return;
    _duckingController.setCoachActive(active);
  }

  void updateSettings(
      {required double baseVolume, required String duckingMode}) {
    _duckingController.update(baseVolume: baseVolume, duckingMode: duckingMode);
  }

  Future<void> stop() async {
    _duckingController.cancel();
    _started = false;
    await _player.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}

/// Shared ducking curve used by workout playback and the settings preview.
class AudioDuckingController {
  final Future<void> Function(double volume) setVolume;
  Timer? _fade;
  double _baseVolume;
  String _duckingMode;
  double _currentVolume;
  bool _coachActive = false;

  AudioDuckingController({
    required this.setVolume,
    double baseVolume = .35,
    String duckingMode = 'gentle',
  })  : _baseVolume = baseVolume.clamp(0.0, 1.0),
        _duckingMode = duckingMode,
        _currentVolume = baseVolume.clamp(0.0, 1.0);

  double get targetVolume =>
      _baseVolume *
      (_coachActive ? BackgroundMusicService.duckFactor(_duckingMode) : 1);

  void syncCurrentVolume() => _currentVolume = targetVolume;

  void update({
    required double baseVolume,
    required String duckingMode,
    bool fade = true,
  }) {
    _baseVolume = baseVolume.clamp(0.0, 1.0);
    _duckingMode = duckingMode;
    if (fade) {
      _fadeTo(targetVolume);
    } else {
      _currentVolume = targetVolume;
    }
  }

  void setCoachActive(bool active) {
    _coachActive = active;
    _fadeTo(targetVolume);
  }

  void _fadeTo(double target) {
    _fade?.cancel();
    const steps = 8;
    var step = 0;
    final start = _currentVolume;
    _fade = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      step++;
      _currentVolume = start + (target - start) * step / steps;
      unawaited(setVolume(_currentVolume));
      if (step >= steps) timer.cancel();
    });
  }

  void cancel() {
    _fade?.cancel();
    _fade = null;
    _coachActive = false;
  }
}
