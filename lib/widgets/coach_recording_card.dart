import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../app/app_controller.dart';
import '../models/coach_recording.dart';
import '../models/workout.dart';
import '../services/coach_recording_service.dart';

class CoachRecordingCard extends StatefulWidget {
  final AppController controller;
  final Workout workout;
  final String scope;
  final String? stepKey;
  final String title;
  final String cueDescription;

  const CoachRecordingCard({
    super.key,
    required this.controller,
    required this.workout,
    required this.scope,
    required this.title,
    required this.cueDescription,
    this.stepKey,
  });

  @override
  State<CoachRecordingCard> createState() => _CoachRecordingCardState();
}

class _CoachRecordingCardState extends State<CoachRecordingCard> {
  final CoachRecordingService _recordingService = CoachRecordingService();
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _recording = false;
  bool _busy = false;
  String? _draftPath;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _playerPositionSubscription;
  StreamSubscription<Duration>? _playerDurationSubscription;
  Timer? _recordingTimer;
  double _audioLevel = 0;
  Duration _recordingElapsed = Duration.zero;
  PlayerState _previewState = PlayerState.stopped;
  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;
  String? _previewPath;
  String _status =
      'Windows does not show an app permission popup here. Desktop microphone access must be enabled in Windows Settings.';

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  CoachRecording? get _assigned => widget.controller.coachRecordingFor(
        workoutId: widget.workout.id,
        scope: widget.scope,
        stepKey: widget.stepKey,
      );

  @override
  void initState() {
    super.initState();
    _playerStateSubscription =
        _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _previewState = state;
          if (state == PlayerState.completed || state == PlayerState.stopped) {
            _previewPosition = Duration.zero;
          }
        });
      }
    });
    _playerPositionSubscription =
        _previewPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _previewPosition = position);
      }
    });
    _playerDurationSubscription =
        _previewPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _previewDuration = duration);
      }
    });
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      if (!await _recordingService.canAttemptRecording()) {
        if (mounted) {
          setState(() => _status =
              'Microphone permission is unavailable. Open Windows microphone settings, enable desktop app access, then try again.');
        }
        return;
      }
      if (_draftPath != null) {
        await _recordingService.deleteFile(_draftPath!);
      }
      await _recordingService.start(widget.workout.id);
      if (!await _recordingService.isRecording()) {
        throw StateError('Windows did not start microphone capture.');
      }
      if (mounted) {
        setState(() {
          _recording = true;
          _draftPath = null;
          _status =
              'Recording now. Speak the selected cue, then press Stop recording.';
        });
      }
      _startRecordingFeedback();
    } catch (error) {
      await _stopRecordingFeedback();
      if (mounted) {
        setState(() {
          _recording = false;
          _status =
              'Recording did not start. Enable Microphone access and “Let desktop apps access your microphone” in Windows Settings, check that an input device is connected, then retry. Details: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      final path = await _recordingService.stop();
      await _stopRecordingFeedback();
      if (mounted) {
        setState(() {
          _recording = false;
          _draftPath = path;
          _status = path == null
              ? 'No audio file was created. Check Windows microphone access and try again.'
              : 'Recording stopped. Listen to it before assigning it.';
        });
      }
      if (path == null) {
        _message('No recording was created.');
      }
    } catch (error) {
      await _stopRecordingFeedback();
      if (mounted) {
        setState(() => _status = 'Could not finish recording: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _startRecordingFeedback() {
    _recordingElapsed = Duration.zero;
    _audioLevel = 0;
    _amplitudeSubscription = _recordingService.amplitudeStream().listen(
      (amplitude) {
        if (!mounted) {
          return;
        }
        // dBFS is normally negative. Map -60 dB..0 dB into 0..1.
        final level = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
        setState(() => _audioLevel = level);
      },
      onError: (_) {
        if (mounted) {
          setState(() => _audioLevel = 0);
        }
      },
    );
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingElapsed += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _stopRecordingFeedback() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    if (mounted) {
      setState(() => _audioLevel = 0);
    }
  }

  Future<void> _preview(String path) async {
    if (!await _recordingService.exists(path)) {
      _message(
          'The recording file is missing. Record a replacement or delete the assignment.');
      return;
    }
    try {
      await _previewPlayer.stop();
      if (mounted) {
        setState(() {
          _previewPath = path;
          _previewPosition = Duration.zero;
          _previewDuration = Duration.zero;
        });
      }
      await _previewPlayer.play(DeviceFileSource(path));
    } catch (error) {
      _message('Could not play this recording: $error');
    }
  }

  Future<void> _stopPreview() async {
    await _previewPlayer.stop();
    if (mounted) {
      setState(() {
        _previewPath = null;
        _previewPosition = Duration.zero;
      });
    }
  }

  Future<void> _save() async {
    final path = _draftPath;
    if (path == null) {
      return;
    }
    final previous = _assigned;
    // Transfer ownership before awaiting persistence. Otherwise a fast modal
    // close can dispose this card and delete the newly assigned draft file.
    if (mounted) {
      setState(() {
        _draftPath = null;
        _status = 'Saving recording…';
      });
    }
    try {
      await _previewPlayer.stop();
      await widget.controller.assignCoachRecording(CoachRecording(
        workoutId: widget.workout.id,
        cue: widget.scope == 'description'
            ? 'workout_description'
            : 'step_voice',
        scope: widget.scope,
        stepKey: widget.stepKey,
        language: widget.workout.voice.language == 'vi' ? 'vi-VN' : 'en-US',
        audioPath: path,
        createdAt: DateTime.now(),
      ));
      if (previous != null && previous.audioPath != path) {
        await _recordingService.deleteFile(previous.audioPath);
      }
      if (mounted) {
        setState(() => _status = 'Recording saved and assigned to this cue.');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _draftPath = path;
          _status = 'Could not save recording: $error';
        });
      }
      return;
    }
    _message('Coach recording assigned to this cue.');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete coach recording?'),
        content: const Text(
            'The local audio file and its workout assignment will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final recording = await widget.controller.removeCoachRecording(
      workoutId: widget.workout.id,
      scope: widget.scope,
      stepKey: widget.stepKey,
    );
    if (recording != null) {
      await _recordingService.deleteFile(recording.audioPath);
    }
    if (mounted) {
      setState(() => _status = 'Recording deleted. Device voice will be used.');
    }
    _message('Coach recording deleted. Device voice will be used.');
  }

  Future<void> _discardDraft() async {
    final path = _draftPath;
    if (path == null) {
      return;
    }
    await _recordingService.deleteFile(path);
    if (mounted) {
      setState(() {
        _draftPath = null;
        _status = 'Draft recording discarded.';
      });
    }
  }

  Future<void> _openMicrophoneSettings() async {
    try {
      await _recordingService.openWindowsMicrophoneSettings();
      if (mounted) {
        setState(() => _status =
            'In Windows Settings, turn on Microphone access and “Let desktop apps access your microphone”, then return and press Record.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status =
            'Could not open Settings automatically. Open Windows Settings > Privacy & security > Microphone. Details: $error');
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final assigned = _assigned;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              '${widget.cueDescription} It stays on this device and is never uploaded.'),
          if (!_supported) ...[
            const SizedBox(height: 10),
            const Text('Recording MVP is currently available on Windows.'),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_status),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openMicrophoneSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open microphone settings'),
            ),
            const SizedBox(height: 8),
            if (_recording)
              _LiveRecordingIndicator(
                level: _audioLevel,
                elapsed: _recordingElapsed,
              ),
            if (_previewState == PlayerState.playing) ...[
              _PlaybackIndicator(
                position: _previewPosition,
                duration: _previewDuration,
                onStop: _stopPreview,
              ),
              const SizedBox(height: 8),
            ],
            if (_draftPath != null) ...[
              const Text('Review the new recording before assigning it.'),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: () => _preview(_draftPath!),
                    icon: Icon(_previewPath == _draftPath &&
                            _previewState == PlayerState.playing
                        ? Icons.graphic_eq
                        : Icons.play_arrow),
                    label: Text(_previewPath == _draftPath &&
                            _previewState == PlayerState.playing
                        ? 'Playing'
                        : 'Listen')),
                FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Use recording')),
                TextButton(
                    onPressed: _discardDraft, child: const Text('Discard')),
              ]),
            ],
            if (assigned != null && _draftPath == null) ...[
              Text('A recording is assigned to this ${widget.scope} cue.'),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: () => _preview(assigned.audioPath),
                    icon: Icon(_previewPath == assigned.audioPath &&
                            _previewState == PlayerState.playing
                        ? Icons.graphic_eq
                        : Icons.play_arrow),
                    label: Text(_previewPath == assigned.audioPath &&
                            _previewState == PlayerState.playing
                        ? 'Playing'
                        : 'Listen')),
                TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete')),
              ]),
            ],
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : (_recording ? _stop : _start),
              icon: Icon(_recording ? Icons.stop : Icons.mic),
              label: Text(_recording
                  ? 'Stop recording'
                  : assigned == null
                      ? 'Record'
                      : 'Record replacement'),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    final amplitudeSubscription = _amplitudeSubscription;
    if (amplitudeSubscription != null) {
      unawaited(amplitudeSubscription.cancel());
    }
    unawaited(_playerStateSubscription?.cancel() ?? Future<void>.value());
    unawaited(_playerPositionSubscription?.cancel() ?? Future<void>.value());
    unawaited(_playerDurationSubscription?.cancel() ?? Future<void>.value());
    if (_recording) {
      unawaited(_recordingService.stop());
    }
    if (_draftPath != null) {
      unawaited(_recordingService.deleteFile(_draftPath!));
    }
    unawaited(_previewPlayer.dispose());
    unawaited(_recordingService.dispose());
    super.dispose();
  }
}

class _PlaybackIndicator extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final VoidCallback onStop;

  const _PlaybackIndicator({
    required this.position,
    required this.duration,
    required this.onStop,
  });

  String _time(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds <= 0
        ? null
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Row(children: [
          Icon(Icons.graphic_eq, color: color),
          const SizedBox(width: 8),
          const Text('Playing preview',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${_time(position)} / ${_time(duration)}'),
          IconButton(
            tooltip: 'Stop preview',
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ]),
        LinearProgressIndicator(value: progress),
      ]),
    );
  }
}

class _LiveRecordingIndicator extends StatelessWidget {
  final double level;
  final Duration elapsed;

  const _LiveRecordingIndicator({required this.level, required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final color = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      label: 'Recording active, $minutes minutes $seconds seconds',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          border: Border.all(color: color.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.fiber_manual_record, color: color, size: 16),
          const SizedBox(width: 8),
          Text('$minutes:$seconds',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 34,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(18, (index) {
                  final shape = .45 + ((index * 7) % 11) / 20;
                  final height = 4 + 28 * (level * shape).clamp(.08, 1.0);
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 70),
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      height: height,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('REC', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
