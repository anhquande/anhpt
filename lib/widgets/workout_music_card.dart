import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../models/background_music.dart';
import '../models/workout.dart';
import '../screens/music_library_screen.dart';

class WorkoutMusicCard extends StatefulWidget {
  final AppController controller;
  final Workout workout;
  const WorkoutMusicCard(
      {super.key, required this.controller, required this.workout});
  @override
  State<WorkoutMusicCard> createState() => _WorkoutMusicCardState();
}

class _WorkoutMusicCardState extends State<WorkoutMusicCard> {
  final AudioPlayer _preview = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  Future<void> _save(WorkoutMusicConfig config) =>
      widget.controller.setWorkoutMusic(config);

  @override
  void initState() {
    super.initState();
    _stateSubscription = _preview.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _positionSubscription = _preview.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _durationSubscription = _preview.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
  }

  Future<void> _play(MusicTrack track, double volume) async {
    try {
      await _preview.stop();
      setState(() {
        _position = Duration.zero;
        _duration = Duration.zero;
      });
      await _preview.play(
        track.bundled
            ? AssetSource(track.source)
            : DeviceFileSource(track.source),
        volume: volume,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Track file is missing or cannot be played.')));
      }
    }
  }

  Future<void> _stop() async {
    await _preview.stop();
    if (mounted) setState(() => _position = Duration.zero);
  }

  Future<void> _changeVolume(WorkoutMusicConfig config, double volume) async {
    await _preview.setVolume(volume);
    await _save(config.copyWith(baseVolume: volume));
  }

  String _time(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.controller.musicConfigFor(widget.workout.id);
    final selected = widget.controller.musicTrackById(config.trackId);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Background music',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MusicLibraryScreen(
                                controller: widget.controller))),
                    child: const Text('Library'))
              ]),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enabled'),
                  value: config.enabled && config.trackId != null,
                  onChanged: config.trackId == null
                      ? null
                      : (value) => _save(config.copyWith(enabled: value))),
              DropdownButtonFormField<String?>(
                  key: ValueKey(config.trackId),
                  initialValue: config.trackId,
                  decoration: const InputDecoration(labelText: 'Track'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('No music')),
                    ...widget.controller.musicTracks.map((track) =>
                        DropdownMenuItem(
                            value: track.id, child: Text(track.name)))
                  ],
                  onChanged: (id) async {
                    await _stop();
                    await _save(config.copyWith(
                        trackId: id,
                        clearTrack: id == null,
                        enabled: id != null));
                  }),
              const SizedBox(height: 10),
              Text('Volume ${(config.baseVolume * 100).round()}%'),
              Slider(
                  value: config.baseVolume,
                  onChanged: (value) => _changeVolume(config, value)),
              DropdownButtonFormField<String>(
                  key: ValueKey(config.duckingMode),
                  initialValue: config.duckingMode,
                  decoration: const InputDecoration(labelText: 'Coach ducking'),
                  items: const [
                    DropdownMenuItem(value: 'off', child: Text('Off')),
                    DropdownMenuItem(
                        value: 'gentle', child: Text('Gentle (recommended)')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium'))
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _save(config.copyWith(duckingMode: value));
                    }
                  }),
              if (selected != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    Row(children: [
                      const Icon(Icons.graphic_eq),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(selected.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      Text('${_time(_position)} / ${_time(_duration)}'),
                    ]),
                    Slider(
                      value: _duration.inMilliseconds <= 0
                          ? 0
                          : _position.inMilliseconds
                              .clamp(0, _duration.inMilliseconds)
                              .toDouble(),
                      max: _duration.inMilliseconds <= 0
                          ? 1
                          : _duration.inMilliseconds.toDouble(),
                      onChanged: _duration.inMilliseconds <= 0
                          ? null
                          : (value) => _preview
                              .seek(Duration(milliseconds: value.round())),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton.filledTonal(
                        tooltip: _playerState == PlayerState.playing
                            ? 'Pause'
                            : 'Play / resume',
                        onPressed: _playerState == PlayerState.playing
                            ? _preview.pause
                            : _playerState == PlayerState.paused
                                ? _preview.resume
                                : () => _play(selected, config.baseVolume),
                        icon: Icon(_playerState == PlayerState.playing
                            ? Icons.pause
                            : Icons.play_arrow),
                      ),
                      const SizedBox(width: 12),
                      IconButton.outlined(
                        tooltip: 'Stop',
                        onPressed: _stop,
                        icon: const Icon(Icons.stop),
                      ),
                    ]),
                  ]),
                ),
              ]
            ])));
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel() ?? Future<void>.value());
    unawaited(_positionSubscription?.cancel() ?? Future<void>.value());
    unawaited(_durationSubscription?.cancel() ?? Future<void>.value());
    unawaited(_preview.dispose());
    super.dispose();
  }
}
