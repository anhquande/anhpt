import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../app/workout_camera_preference.dart';
import '../core/session_engine.dart';
import '../models/background_music.dart';
import '../models/workout.dart';
import '../services/audio_feedback_service.dart';
import '../services/background_music_service.dart';
import '../services/device_action_service.dart';
import '../services/voice_guide_controller.dart';
import '../widgets/common.dart';
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
  static const _swipeThreshold = 64.0;

  late final SessionEngine engine;
  late final AudioFeedbackService audio;
  late final BackgroundMusicService music;
  late final VoiceGuideController voiceGuide;
  final DeviceActionService deviceActions = DeviceActionService();
  Timer? _screenOffTimer;
  Timer? _centerFeedbackTimer;

  bool summaryShown = false;
  bool audioReady = false;
  bool soundMuted = false;
  String? musicNotice;
  SessionStatus? _musicStatus;
  bool _disposed = false;
  bool _cameraEnabled = false;
  bool _demonstrationEnabled = true;
  WorkoutCameraLayout _cameraLayout = WorkoutCameraLayout.pictureInPicture;
  String? _cameraNotice;
  double _dragDistance = 0;
  IconData? _centerFeedbackIcon;

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

  Future<void> _setCameraLayout(WorkoutCameraLayout layout) async {
    setState(() {
      _cameraLayout = layout;
      _demonstrationEnabled = true;
    });
    await WorkoutCameraPreference.instance.setDemonstrationEnabled(true);
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
      }
    }
    if (_disposed) return;
    try {
      await voiceGuide.initialize();
      if (_disposed) return;
      audioReady = true;
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

  Future<void> _toggleSound() async {
    final muted = !soundMuted;
    setState(() => soundMuted = muted);
    music.setMuted(muted);
    await voiceGuide.setMuted(muted);
    if (mounted) setState(() {});
  }

  void _showCenterFeedback(IconData icon) {
    _centerFeedbackTimer?.cancel();
    setState(() => _centerFeedbackIcon = icon);
    _centerFeedbackTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _centerFeedbackIcon = null);
    });
  }

  void _togglePauseFromMedia() {
    if (engine.status == SessionStatus.paused) {
      engine.resume();
      _showCenterFeedback(Icons.play_arrow_rounded);
      return;
    }
    if (engine.status == SessionStatus.running && !engine.timerFinished) {
      engine.pause();
      _showCenterFeedback(Icons.pause_rounded);
    }
  }

  Future<void> _navigateStep(bool next) async {
    if (engine.status == SessionStatus.preparing ||
        engine.status == SessionStatus.completed ||
        engine.status == SessionStatus.incomplete) {
      return;
    }
    if (next && !engine.canGoNext) return;
    if (!next && !engine.canGoPrevious) return;

    await voiceGuide.cancelCurrentWork();
    if (_disposed) return;
    final changed = next ? engine.goToNextStep() : engine.goToPreviousStep();
    if (changed && mounted) {
      HapticFeedback.selectionClick();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _togglePauseFromMedia();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      unawaited(_navigateStep(true));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      unawaited(_navigateStep(false));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
        music.setMuted(soundMuted);
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

  Exercise? _exerciseForStep(WorkoutStep? step) {
    final exerciseId = step?.exerciseId;
    if (exerciseId == null) return null;
    for (final exercise in engine.workout.exercises) {
      if (exercise.id == exerciseId) return exercise;
    }
    return null;
  }

  Widget? _demonstrationForExercise(Exercise? exercise, {required bool paused}) {
    if (!_demonstrationEnabled || exercise?.demoMediaId == null) return null;
    return DemonstrationMedia(
      key: ValueKey('${exercise!.demoMediaId}-${paused ? 'preview' : 'main'}'),
      mediaId: exercise.demoMediaId!,
      paused: paused,
      resolveAsset: () => widget.controller.mediaAsset(exercise.demoMediaId!),
      resolveUri: () => widget.controller.resolveMediaUri(exercise.demoMediaId!),
    );
  }

  Widget _buildProgress(ColorScheme cs) {
    final progress = engine.progress.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: 12,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
                Positioned(
                  left: math.max(0, (constraints.maxWidth - 10) * progress),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Text(
                formatDuration(engine.workoutPositionElapsed),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                formatDuration(engine.workout.totalDuration),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _layoutPreview(
    WorkoutCameraLayout layout,
    ColorScheme cs, {
    double width = 68,
    double height = 44,
  }) {
    final demoColor = cs.primaryContainer;
    final cameraColor = cs.tertiaryContainer;
    final border = Border.all(color: cs.outlineVariant);

    Widget tile(Color color, {BorderRadius? radius}) => Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius ?? BorderRadius.circular(4),
            border: border,
          ),
        );

    Widget preview;
    switch (layout) {
      case WorkoutCameraLayout.split:
        preview = Row(
          children: [
            Expanded(child: tile(demoColor)),
            const SizedBox(width: 3),
            Expanded(child: tile(cameraColor)),
          ],
        );
      case WorkoutCameraLayout.pictureInPicture:
        preview = Stack(
          children: [
            Positioned.fill(child: tile(demoColor)),
            Positioned(
              right: 4,
              bottom: 4,
              width: width * .34,
              height: height * .40,
              child: tile(cameraColor),
            ),
          ],
        );
      case WorkoutCameraLayout.cameraPictureInPicture:
        preview = Stack(
          children: [
            Positioned.fill(child: tile(cameraColor)),
            Positioned(
              right: 4,
              bottom: 4,
              width: width * .34,
              height: height * .40,
              child: tile(demoColor),
            ),
          ],
        );
      case WorkoutCameraLayout.overlay:
        preview = Stack(
          children: [
            Positioned.fill(child: tile(demoColor)),
            Positioned(
              left: width * .18,
              top: height * .14,
              right: width * .18,
              bottom: height * .14,
              child: tile(cameraColor),
            ),
          ],
        );
    }

    return Semantics(
      label: '${layout.label} layout preview',
      child: SizedBox(width: width, height: height, child: preview),
    );
  }

  Widget _buildLayoutMenuItem(
    WorkoutCameraLayout layout,
    ColorScheme cs,
  ) {
    final selected = layout == _cameraLayout;
    return SizedBox(
      width: 250,
      child: Row(
        children: [
          _layoutPreview(layout, cs),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              layout.label,
              maxLines: 2,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (selected) Icon(Icons.check_circle, color: cs.primary, size: 20),
        ],
      ),
    );
  }

  Widget _buildTopControls({
    required bool hasDemo,
    required ColorScheme cs,
  }) {
    return Row(
      children: [
        IconButton(
          tooltip: 'End workout',
          onPressed: _end,
          icon: const Icon(Icons.close),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            engine.status == SessionStatus.preparing
                ? engine.workout.name
                : engine.currentStep.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        IconButton(
          tooltip: soundMuted ? 'Turn sound on' : 'Mute sound',
          onPressed: audioReady || music.started ? _toggleSound : null,
          icon: Icon(soundMuted ? Icons.volume_off : Icons.volume_up),
        ),
        if (_cameraSupported)
          IconButton(
            tooltip: _cameraEnabled ? 'Turn camera off' : 'Turn camera on',
            onPressed: _toggleCamera,
            icon: Icon(
              _cameraEnabled ? Icons.videocam : Icons.videocam_outlined,
            ),
          ),
        if (_cameraSupported)
          PopupMenuButton<WorkoutCameraLayout>(
            tooltip: 'Change video layout',
            initialValue: _cameraLayout,
            onSelected: _setCameraLayout,
            icon: const Icon(Icons.grid_view_rounded),
            itemBuilder: (_) => [
              for (final layout in WorkoutCameraLayout.values)
                PopupMenuItem(
                  value: layout,
                  height: 66,
                  child: _buildLayoutMenuItem(layout, cs),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildNextStepPreview(ColorScheme cs) {
    final next = engine.nextStep;
    if (next == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('Finish', style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      );
    }

    final nextExercise = _exerciseForStep(next);
    final preview = _demonstrationForExercise(nextExercise, paused: true);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => unawaited(_navigateStep(true)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 76,
                height: 52,
                color: cs.surfaceContainerHighest,
                child: preview == null
                    ? Icon(Icons.fitness_center, color: cs.onSurfaceVariant)
                    : FittedBox(fit: BoxFit.cover, child: preview),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    next.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDuration(next.duration),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_up_rounded),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preparing = engine.status == SessionStatus.preparing;
    final paused = engine.status == SessionStatus.paused;
    final waitingForGuide = engine.waitingForAnnouncement;
    final cs = Theme.of(context).colorScheme;
    final exercise = preparing ? null : _exerciseForStep(engine.currentStep);
    final hasDemo = !preparing && exercise?.demoMediaId != null;
    final demonstration =
        hasDemo ? _demonstrationForExercise(exercise, paused: paused) : null;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isLandscape ? 12 : 16,
              6,
              isLandscape ? 12 : 16,
              8,
            ),
            child: Column(
              children: [
                _buildProgress(cs),
                const SizedBox(height: 2),
                _buildTopControls(hasDemo: hasDemo, cs: cs),
                const SizedBox(height: 4),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: paused
                        ? 'Workout paused. Activate to resume.'
                        : 'Workout running. Activate to pause.',
                    onTap: _togglePauseFromMedia,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePauseFromMedia,
                      onVerticalDragStart: (_) => _dragDistance = 0,
                      onVerticalDragUpdate: (details) {
                        _dragDistance += details.delta.dy;
                      },
                      onVerticalDragEnd: (_) {
                        final distance = _dragDistance;
                        _dragDistance = 0;
                        if (distance <= -_swipeThreshold) {
                          unawaited(_navigateStep(true));
                        } else if (distance >= _swipeThreshold) {
                          unawaited(_navigateStep(false));
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              color: cs.surfaceContainerLowest,
                              child: WorkoutCameraComparison(
                                cameraEnabled: _cameraEnabled,
                                demonstrationEnabled: _demonstrationEnabled,
                                layout: _cameraLayout,
                                demonstration: demonstration,
                                onCameraErrorChanged: _cameraErrorChanged,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: cs.surface.withValues(alpha: .78),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    waitingForGuide
                                        ? 'FINISHING GUIDE'
                                        : preparing
                                            ? 'READY ${formatDuration(engine.remaining)}'
                                            : paused
                                                ? 'PAUSED · ${formatDuration(engine.remaining)}'
                                                : formatDuration(engine.remaining),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!preparing)
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 12,
                              child: Text(
                                engine.currentStep.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      shadows: const [
                                        Shadow(blurRadius: 8),
                                      ],
                                    ),
                              ),
                            ),
                          if (_centerFeedbackIcon != null)
                            Center(
                              child: AnimatedOpacity(
                                opacity: _centerFeedbackIcon == null ? 0 : 1,
                                duration: const Duration(milliseconds: 120),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: cs.surface.withValues(alpha: .72),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Icon(
                                      _centerFeedbackIcon,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!preparing) ...[
                  const SizedBox(height: 7),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.outlineVariant,
                  ),
                  _buildNextStepPreview(cs),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _screenOffTimer?.cancel();
    _centerFeedbackTimer?.cancel();
    engine.removeListener(_changed);
    engine.dispose();
    voiceGuide.dispose();
    unawaited(audio.dispose());
    unawaited(music.dispose());
    super.dispose();
  }
}
