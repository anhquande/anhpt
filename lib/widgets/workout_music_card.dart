import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../models/background_music.dart';
import '../models/workout.dart';
import '../screens/music_library_screen.dart';
import '../services/background_music_service.dart';
import 'audio_preview_player.dart';

class WorkoutMusicCard extends StatefulWidget {
  final AppController controller;
  final Workout workout;
  const WorkoutMusicCard(
      {super.key, required this.controller, required this.workout});
  @override
  WorkoutMusicCardState createState() => WorkoutMusicCardState();
}

class WorkoutMusicCardState extends State<WorkoutMusicCard> {
  final AudioPlayer _preview = AudioPlayer();
  final AudioPlayer _coachPreview = AudioPlayer();
  late final AudioDuckingController _ducking =
      AudioDuckingController(setVolume: _preview.setVolume);
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _coachCompleteSubscription;
  bool _testingDucking = false;
  bool _loadingDuckingTest = false;
  int _previewGeneration = 0;

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
    _coachCompleteSubscription = _coachPreview.onPlayerComplete.listen((_) {
      _finishDuckingTest();
    });
  }

  Future<bool> _play(MusicTrack track, double volume) async {
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
      _ducking.update(baseVolume: volume, duckingMode: 'gentle', fade: false);
      _ducking.syncCurrentVolume();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Track file is missing or cannot be played.')));
      }
      return false;
    }
  }

  Future<void> _stop() async {
    _previewGeneration++;
    _ducking.cancel();
    await _coachPreview.stop();
    await _preview.stop();
    if (mounted) {
      setState(() {
        _position = Duration.zero;
        _testingDucking = false;
        _loadingDuckingTest = false;
      });
    }
  }

  Future<void> stopPreview() => _stop();

  Future<void> _changeVolume(WorkoutMusicConfig config, double volume) async {
    _ducking.update(baseVolume: volume, duckingMode: config.duckingMode);
    await _save(config.copyWith(baseVolume: volume));
  }

  Future<void> _changeDucking(
      WorkoutMusicConfig config, String duckingMode) async {
    _ducking.update(baseVolume: config.baseVolume, duckingMode: duckingMode);
    await _save(config.copyWith(duckingMode: duckingMode));
  }

  Future<void> _testDucking(MusicTrack track, WorkoutMusicConfig config) async {
    if (_testingDucking || _loadingDuckingTest) {
      await _stopCoachPreview();
      return;
    }
    final generation = ++_previewGeneration;
    setState(() => _loadingDuckingTest = true);
    try {
      if (_playerState != PlayerState.playing) {
        if (_playerState == PlayerState.paused) {
          await _preview.resume();
        } else {
          if (!await _play(track, config.baseVolume)) {
            if (mounted) setState(() => _loadingDuckingTest = false);
            return;
          }
        }
      }
      if (generation != _previewGeneration) return;
      _ducking.update(
          baseVolume: config.baseVolume,
          duckingMode: config.duckingMode,
          fade: false);
      _ducking.syncCurrentVolume();
      await _coachPreview.stop();
      await _coachPreview.play(AssetSource('audio/coach_ducking_preview.wav'));
      if (generation != _previewGeneration) return;
      _ducking.setCoachActive(true);
      if (mounted) {
        setState(() {
          _testingDucking = true;
          _loadingDuckingTest = false;
        });
      }
    } catch (_) {
      _ducking.setCoachActive(false);
      if (mounted) {
        setState(() {
          _testingDucking = false;
          _loadingDuckingTest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ducking preview could not be played.')));
      }
    }
  }

  Future<void> _pause() async {
    await _stopCoachPreview();
    await _preview.pause();
  }

  Future<void> _toggleMusicPreview(
      MusicTrack track, WorkoutMusicConfig config) async {
    if (_playerState == PlayerState.playing) {
      await _pause();
    } else if (_playerState == PlayerState.paused) {
      await _preview.resume();
    } else {
      await _play(track, config.baseVolume);
    }
  }

  void _finishDuckingTest() {
    _ducking.setCoachActive(false);
    if (mounted) setState(() => _testingDucking = false);
  }

  Future<void> _stopCoachPreview() async {
    _previewGeneration++;
    await _coachPreview.stop();
    _finishDuckingTest();
    if (mounted) setState(() => _loadingDuckingTest = false);
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
                Expanded(
                  child: Text(
                    'Background music',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
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
                  isExpanded: true,
                  key: ValueKey(config.trackId),
                  initialValue: config.trackId,
                  decoration: const InputDecoration(labelText: 'Track'),
                  selectedItemBuilder: (context) => [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...widget.controller.musicTracks.map(
                          (track) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              track.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
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
              if (selected != null) ...[
                const SizedBox(height: 12),
                AudioPreviewPlayer(
                  title: selected.name,
                  state: _playerState,
                  position: _position,
                  duration: _duration,
                  onPlayPause: () => _toggleMusicPreview(selected, config),
                  onSeek: (value) =>
                      _preview.seek(Duration(milliseconds: value.round())),
                  onStop: _stop,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                  'Background music volume ${(config.baseVolume * 100).round()}%'),
              Slider(
                  value: config.baseVolume,
                  onChanged: (value) => _changeVolume(config, value)),
              const SizedBox(height: 12),
              _DuckingControls(
                config: config,
                selected: selected,
                loading: _loadingDuckingTest,
                testing: _testingDucking,
                onChanged: (value) => _changeDucking(config, value),
                onTest: selected == null
                    ? null
                    : () => _testDucking(selected, config),
              ),
            ])));
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel() ?? Future<void>.value());
    unawaited(_positionSubscription?.cancel() ?? Future<void>.value());
    unawaited(_durationSubscription?.cancel() ?? Future<void>.value());
    unawaited(_coachCompleteSubscription?.cancel() ?? Future<void>.value());
    _ducking.cancel();
    unawaited(_coachPreview.dispose());
    unawaited(_preview.dispose());
    super.dispose();
  }
}

class _DuckingControls extends StatelessWidget {
  final WorkoutMusicConfig config;
  final MusicTrack? selected;
  final bool loading;
  final bool testing;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTest;

  const _DuckingControls({
    required this.config,
    required this.selected,
    required this.loading,
    required this.testing,
    required this.onChanged,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final dropdown = DropdownButtonFormField<String>(
      isExpanded: true,
      key: ValueKey(config.duckingMode),
      initialValue: config.duckingMode,
      decoration: const InputDecoration(labelText: 'Coach ducking'),
      selectedItemBuilder: (context) => const [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Off', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Gentle (recommended)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Medium', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('High', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Very high', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
      items: const [
        DropdownMenuItem(value: 'off', child: Text('Off')),
        DropdownMenuItem(value: 'gentle', child: Text('Gentle (recommended)')),
        DropdownMenuItem(value: 'medium', child: Text('Medium')),
        DropdownMenuItem(value: 'high', child: Text('High')),
        DropdownMenuItem(value: 'very_high', child: Text('Very high')),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
    final testButton = selected == null
        ? null
        : SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: loading ? null : onTest,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(testing
                      ? Icons.stop_circle_outlined
                      : Icons.record_voice_over_outlined),
              label: Text(loading
                  ? 'Starting preview…'
                  : testing
                      ? 'Stop ducking test'
                      : 'Test ducking with coach voice'),
            ),
          );

    return LayoutBuilder(builder: (context, constraints) {
      if (testButton != null && constraints.maxWidth >= 560) {
        return Row(children: [
          Expanded(child: dropdown),
          const SizedBox(width: 12),
          Expanded(child: testButton),
        ]);
      }
      return Column(children: [
        dropdown,
        if (testButton != null) ...[
          const SizedBox(height: 12),
          testButton,
        ],
      ]);
    });
  }
}
