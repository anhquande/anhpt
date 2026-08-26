import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import '../models/background_music.dart';

class BackgroundMusicService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _fade;
  double _baseVolume = .35;
  String _ducking = 'gentle';
  double _currentVolume = 0;
  bool _started = false;
  String? lastError;

  bool get started => _started;
  static double duckFactor(String mode) =>
      switch (mode) { 'off' => 1.0, 'medium' => .6, _ => .82 };

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
    _baseVolume = config.baseVolume.clamp(0.0, 1.0);
    _ducking = config.duckingMode;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setVolume(_baseVolume);
      final playing = _player.onPlayerStateChanged
          .firstWhere((state) => state == PlayerState.playing)
          .timeout(const Duration(seconds: 5));
      await _player.play(track.bundled
          ? AssetSource(track.source)
          : DeviceFileSource(track.source));
      await playing;
      _currentVolume = _baseVolume;
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
    final factor = duckFactor(_ducking);
    _fadeTo(active ? _baseVolume * factor : _baseVolume);
  }

  void _fadeTo(double target) {
    _fade?.cancel();
    const steps = 8;
    var step = 0;
    final start = _currentVolume;
    _fade = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      step++;
      _currentVolume = start + (target - start) * step / steps;
      unawaited(_player.setVolume(_currentVolume));
      if (step >= steps) timer.cancel();
    });
  }

  Future<void> stop() async {
    _fade?.cancel();
    _started = false;
    await _player.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
