import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../app/workout_camera_preference.dart';
import '../core/session_engine.dart';
import '../services/audio_feedback_service.dart';
import '../services/background_music_service.dart';
import '../services/device_action_service.dart';
import '../services/voice_guide_controller.dart';
import '../widgets/common.dart';
import '../models/background_music.dart';
import '../models/workout.dart';
import '../widgets/demonstration_media.dart';
import '../widgets/workout_camera_comparison.dart';

enum CompletionDeviceAction { shutdownWindows, exitAndroid }

CompletionDeviceAction? completionDeviceActionFor(
  TargetPlatform platform, {
  required bool isWeb,
}) {
  if (isWeb) return null;
  return switch (platform) {
    TargetPlatform.windows => CompletionDeviceAction.shutdownWindows,
    TargetPlatform.android => CompletionDeviceAction.exitAndroid,
    _ => null,
  };
}

class WorkoutPlayerScreen extends StatefulWidget {
  final AppController controller;
  final String workoutId;
  final String? profileId;
  final String? profileName;

  const WorkoutPlayerScreen({
    super.key,
    required this.controller,
    required this.workoutId,
    this.profileId,
    this.profileName,
  });

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  late final SessionEngine engine;
  late final AudioFeedbackService audio;
  late final BackgroundMusicService music;
  late final VoiceGuideController voiceGuide;
  final DeviceActionService deviceActions = DeviceActionService();
  Timer? _screenOffTimer;

  bool summaryShown = false;
  bool audioReady = false;
  bool voiceMuted = false;
  double voiceVolume = 1.0;
  String? musicNotice;
  String musicStatus = 'Music off';
  SessionStatus? _musicStatus;
  bool _disposed = false;
  bool _cameraEnabled = false;
  bool _demonstrationEnabled = true;
  WorkoutCameraLayout _cameraLayout = WorkoutCameraLayout.pictureInPicture;
  String? _cameraNotice;

  bool get _cameraSupported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  @override
  void initState() {
    super.initState();
    final workout = widget.controller.byId(widget.workoutId)!;
    engine = SessionEngine(workout);
    music = BackgroundMusicService();
    audio = AudioFeedbackService(onCoachAudioChanged: music.setCoachActive);
    voiceGuide = VoiceGuideController(
      workout: workout,
      engine: engine,
      audio: audio,
      descriptionRecordingPath: workout.recording == null
          ? null
          : widget.controller.resolveAudioSource(workout.recording!),
      stepRecordingPaths: {
        for (final executable in workout.expand())
          if (executable.step.recording != null)
            executable.step.id: widget.controller
                .resolveAudioSource(executable.step.recording!),
      },
    );
    engine.addListener(_changed);
    _scheduleScreenOff();
    unawaited(_initializeCameraPreference());
    _initializeAndStart();
  }

  Future<void> _initializeCameraPreference() async {
    await WorkoutCameraPreference.instance.initialize();
    if (!mounted || _disposed) return;
    setState(() {
      _cameraEnabled =
          _cameraSupported && WorkoutCameraPreference.instance.autoStart;
      _demonstrationEnabled =
          WorkoutCameraPreference.instance.demonstrationEnabled;
      _cameraLayout = WorkoutCameraPreference.instance.layout;
    });
  }

  void _toggleCamera() {
    if (!_cameraSupported) return;
    setState(() {
      _cameraEnabled = !_cameraEnabled;
      if (!_cameraEnabled) _cameraNotice = null;
    });
  }

  Future<void> _toggleDemonstration() async {
    final enabled = !_demonstrationEnabled;
    setState(() => _demonstrationEnabled = enabled);
    await WorkoutCameraPreference.instance.setDemonstrationEnabled(enabled);
  }

  Future<void> _setCameraLayout(WorkoutCameraLayout layout) async {
    setState(() => _cameraLayout = layout);
    await WorkoutCameraPreference.instance.setLayout(layout);
  }

  void _cameraErrorChanged(String? error) {
    if (!mounted || _cameraNotice == error) return;
    _cameraNotice = error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error Workout continues without camera.')),
      );
    }
  }

  void _scheduleScreenOff() {
    final delay = engine.workout.screenOffAfterStart;
    if (delay == null) return;
    _screenOffTimer = Timer(delay, () {
      if (!_disposed) unawaited(deviceActions.turnOffDisplay());
    });
  }

  Future<void> _initializeAndStart() async {
    final yamlMusic = engine.workout.backgroundMusic;
    final config = yamlMusic == null
        ? widget.controller.musicConfigFor(engine.workout.id)
        : WorkoutMusicConfig(
            workoutId: engine.workout.id,
            trackId: 'yaml',
            enabled: yamlMusic.enabled,
            baseVolume: yamlMusic.volume,
            duckingMode: yamlMusic.ducking,
          );
    final libraryTrack = widget.controller.musicTrackById(config.trackId);
    final track = yamlMusic == null
        ? libraryTrack
        : MusicTrack(
            id: 'yaml',
            name: yamlMusic.name ?? 'Background music',
            mood: '',
            source: yamlMusic.source.startsWith('asset:')
                ? yamlMusic.source.substring(6)
                : widget.controller.resolveAudioSource(yamlMusic.source),
            bundled: yamlMusic.source.startsWith('asset:'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          );
    if (config.enabled && config.trackId != null) {
      if (track == null || !await music.start(track, config)) {
        musicNotice =
            'Background music failed: ${track == null ? 'selected track is not in the library' : music.lastError ?? 'unknown playback error'}. Workout continues without music.';
        musicStatus = 'Music failed';
      } else {
        musicStatus = 'Playing: ${track.name}';
      }
    } else {
      musicStatus = config.trackId == null
          ? 'Music off: no track selected'
          : 'Music off: disabled';
    }
    if (_disposed) return;
    try {
      await voiceGuide.initialize();
      if (_disposed) return;
      audioReady = true;
      voiceVolume = audio.voiceVolume;
    } catch (e) {
      debugPrint('Audio initialization failed: $e');
    }
    if (_disposed) return;
    engine.start();
    _musicStatus = engine.status;
    if (musicNotice != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(musicNotice!)));
        }
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleVoice() async {
    final muted = !voiceMuted;
    setState(() => voiceMuted = muted);
    await voiceGuide.setMuted(muted);
    if (mounted) setState(() {});
  }

  Future<void> _setVoiceVolume(double value) async {
    setState(() => voiceVolume = value);
    await audio.setVoiceVolume(value);
  }

  void _changed() {
    final status = engine.status;
    if (_musicStatus != status) {
      if (status == SessionStatus.paused) {
        unawaited(music.pause());
        unawaited(voiceGuide.cancelCurrentWork(replayCurrentStep: true));
      }
      if (_musicStatus == SessionStatus.paused &&
          status == SessionStatus.running) {
        unawaited(music.resume());
      }
      if (status == SessionStatus.completed ||
          status == SessionStatus.incomplete) {
        _screenOffTimer?.cancel();
        unawaited(music.stop());
        unawaited(voiceGuide.cancelCurrentWork());
      }
      _musicStatus = status;
    }
    unawaited(voiceGuide.onEngineChanged());
    if (!mounted) return;
    setState(() {});

    if (!summaryShown &&
        (engine.status == SessionStatus.completed ||
            engine.status == SessionStatus.incomplete)) {
      summaryShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _summary());
    }
  }

  Future<void> _summary() async {
    final complete = engine.status == SessionStatus.completed;
    if (complete && engine.workout.completionAction == 'shutdown_or_exit') {
      final action =
          completionDeviceActionFor(defaultTargetPlatform, isWeb: kIsWeb);
      if (action != null) {
        await _performCompletionDeviceAction(action);
        return;
      }
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(complete ? 'Workout Complete 🎉' : 'Workout Incomplete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(engine.workout.name),
            if (widget.profileName != null) ...[
              const SizedBox(height: 6),
              Text('Profile: ${widget.profileName}'),
            ],
            const SizedBox(height: 10),
            Text('Active time: ${formatDuration(engine.activeElapsed)}'),
            Text('Progress: ${(engine.progress * 100).round()}%'),
            const SizedBox(height: 8),
            Text(
              audioReady
                  ? 'Voice guide: ${engine.workout.voice.language.toUpperCase()}'
                  : 'Voice guide unavailable on this device.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _performCompletionDeviceAction(
    CompletionDeviceAction action,
  ) async {
    if (action == CompletionDeviceAction.shutdownWindows) {
      try {
        await Process.start('shutdown.exe', [
          '/s',
          '/t',
          '0',
          '/f',
          '/d',
          'p:0:0',
          '/c',
          'AnhPT workout completed',
        ]);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start Windows shutdown: $error')),
          );
        }
      }
      return;
    }
    await SystemNavigator.pop();
  }

  Future<void> _end() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End workout?'),
        content: const Text('The workout will be marked as incomplete.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Workout'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (ok == true) engine.endEarly();
  }

  @override
  Widget build(BuildContext context) {
    final preparing = engine.status == SessionStatus.preparing;
    final paused = engine.status == SessionStatus.paused;
    final waitingForGuide = engine.waitingForAnnouncement;
    final canPause =
        engine.status == SessionStatus.running && !engine.timerFinished;
    final cs = Theme.of(context).colorScheme;
    Exercise? exercise;
    final exerciseId = preparing ? null : engine.currentStep.exerciseId;
    if (exerciseId != null) {
      for (final candidate in engine.workout.exercises) {
        if (candidate.id == exerciseId) {
          exercise = candidate;
          break;
        }
      }
    }
    final hasDemo = !preparing && exercise?.demoMediaId != null;
    final demonstration = hasDemo && _demonstrationEnabled
        ? DemonstrationMedia(
            key: ValueKey(exercise!.demoMediaId),
            mediaId: exercise.demoMediaId!,
            paused: paused,
            resolveAsset: () =>
                widget.controller.mediaAsset(exercise!.demoMediaId!),
            resolveUri: () =>
                widget.controller.resolveMediaUri(exercise!.demoMediaId!),
          )
        : null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'AnhPT',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  if (widget.profileName != null) ...[
                    Chip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(widget.profileName!),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    tooltip: _demonstrationEnabled
                        ? 'Hide demonstration video'
                        : 'Show demonstration video',
                    onPressed: _toggleDemonstration,
                    icon: Icon(
                      _demonstrationEnabled
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  if (_cameraSupported)
                    IconButton(
                      tooltip: _cameraEnabled
                          ? 'Turn workout camera off'
                          : 'Turn workout camera on',
                      onPressed: _toggleCamera,
                      icon: Icon(
                        _cameraEnabled
                            ? Icons.videocam
                            : Icons.videocam_outlined,
                      ),
                    ),
                  if (_cameraEnabled && hasDemo && _demonstrationEnabled)
                    PopupMenuButton<WorkoutCameraLayout>(
                      tooltip: 'Camera layout',
                      initialValue: _cameraLayout,
                      onSelected: _setCameraLayout,
                      icon: const Icon(Icons.view_quilt_outlined),
                      itemBuilder: (_) => [
                        for (final layout in WorkoutCameraLayout.values)
                          PopupMenuItem(
                            value: layout,
                            child: Row(
                              children: [
                                if (layout == _cameraLayout) ...[
                                  const Icon(Icons.check, size: 18),
                                  const SizedBox(width: 8),
                                ],
                                Text(layout.label),
                              ],
                            ),
                          ),
                      ],
                    ),
                  IconButton(
                    tooltip: voiceMuted ? 'Turn voice on' : 'Mute voice',
                    onPressed: audioReady ? _toggleVoice : null,
                    icon: Icon(
                      audioReady && !voiceMuted
                          ? Icons.volume_up
                          : Icons.volume_off,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'End workout',
                    onPressed: _end,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Chip(
                avatar: Icon(
                  music.started ? Icons.music_note : Icons.music_off,
                  size: 16,
                ),
                label: Text(musicStatus),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Row(
                  children: [
                    Icon(
                      voiceMuted || voiceVolume == 0
                          ? Icons.volume_off
                          : voiceVolume < 0.5
                              ? Icons.volume_down
                              : Icons.volume_up,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: voiceVolume,
                        onChanged: audioReady ? _setVoiceVolume : null,
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${(voiceVolume * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (waitingForGuide) const Chip(label: Text('FINISHING GUIDE')),
              if (paused) const Chip(label: Text('PAUSED')),
              const SizedBox(height: 16),
              Text(
                preparing ? 'READY' : engine.currentStep.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (_cameraEnabled || demonstration != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 240,
                  child: WorkoutCameraComparison(
                    cameraEnabled: _cameraEnabled,
                    demonstrationEnabled: _demonstrationEnabled,
                    layout: _cameraLayout,
                    demonstration: demonstration,
                    onCameraErrorChanged: _cameraErrorChanged,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FittedBox(
                child: Text(
                  formatDuration(engine.remaining),
                  style: TextStyle(
                    fontSize: 104,
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                    height: .95,
                  ),
                ),
              ),
              if (!preparing) ...[
                const SizedBox(height: 16),
                Text(
                  'Step ${engine.stepIndex + 1} / ${engine.totalEffectiveSteps}',
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: engine.progress,
                  minHeight: 10,
                ),
                const SizedBox(height: 14),
                Text(
                  engine.nextStep == null
                      ? 'Next: Finish'
                      : 'Next: ${engine.nextStep!.name}',
                ),
                const SizedBox(height: 28),
                if (waitingForGuide)
                  const Text('Timer finished. Waiting for the voice guide.')
                else if (paused || canPause)
                  SizedBox(
                    width: 240,
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: paused ? engine.resume : engine.pause,
                      icon: Icon(
                        paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      ),
                      label: Text(paused ? 'RESUME' : 'PAUSE'),
                    ),
                  ),
              ],
              const Spacer(),
              Text(
                voiceMuted
                    ? 'Voice muted • volume ${(voiceVolume * 100).round()}%'
                    : 'Voice volume ${(voiceVolume * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _screenOffTimer?.cancel();
    engine.removeListener(_changed);
    engine.dispose();
    voiceGuide.dispose();
    unawaited(audio.dispose());
    unawaited(music.dispose());
    super.dispose();
  }
}
