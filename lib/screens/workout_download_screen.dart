import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/workout_bucket.dart';
import '../services/workout_bucket_service.dart';
import '../widgets/workout_artwork.dart';
import 'workout_detail_screen.dart';

enum _DownloadPhase { preview, downloading, installing, ready, failed }

class WorkoutDownloadScreen extends StatefulWidget {
  final AppController controller;
  final WorkoutBucketEntry entry;
  final String sourceName;
  final BucketInstallConflictResolution? resolution;
  final Duration minimumReadingTime;

  const WorkoutDownloadScreen({
    super.key,
    required this.controller,
    required this.entry,
    required this.sourceName,
    this.resolution,
    this.minimumReadingTime = const Duration(seconds: 2),
  });

  @override
  State<WorkoutDownloadScreen> createState() => _WorkoutDownloadScreenState();
}

class _WorkoutDownloadScreenState extends State<WorkoutDownloadScreen> {
  _DownloadPhase _phase = _DownloadPhase.preview;
  StreamSubscription<BucketPackageProgressEvent>? _progressSubscription;
  int _receivedBytes = 0;
  int? _totalBytes;
  String _artifact = 'workout';
  String? _error;
  String? _installedWorkoutId;
  bool _userInteracted = false;
  bool _opening = false;
  bool _showAllSteps = false;
  late DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _progressSubscription = WorkoutBucketService.packageProgress.listen((
      event,
    ) {
      if (!mounted || event.entryId != widget.entry.id) return;
      final total = event.totalBytes;
      setState(() {
        _artifact = event.artifact;
        _receivedBytes = event.receivedBytes;
        _totalBytes = total;
        final artifactComplete =
            total != null && total > 0 && event.receivedBytes >= total;
        if (event.artifact == 'assets' && artifactComplete) {
          _phase = _DownloadPhase.installing;
        } else {
          // Completing the small YAML file is not the end of the download.
          // The assets request starts next and must remain visible, especially
          // for workouts containing large video or audio files.
          _phase = _DownloadPhase.downloading;
        }
      });
    });
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _install() async {
    final existingWorkoutIds = widget.controller.workouts
        .map((workout) => workout.id)
        .toSet();
    if (mounted) {
      setState(() {
        _phase = _DownloadPhase.downloading;
        _artifact = 'workout';
        _receivedBytes = 0;
        _totalBytes = widget.entry.workoutSize;
        _error = null;
        _installedWorkoutId = null;
        _opening = false;
      });
    }

    try {
      final installed = await widget.controller.installBucketEntry(
        widget.entry,
        resolution: widget.resolution,
      );
      if (!installed || !mounted) return;

      String? workoutId;
      for (final workout in widget.controller.workouts) {
        if (!existingWorkoutIds.contains(workout.id)) {
          workoutId = workout.id;
          break;
        }
      }
      if (workoutId == null) {
        for (final item in widget.controller.installedBucketWorkouts.reversed) {
          if (item.sourceId == widget.entry.sourceId &&
              item.entryId == widget.entry.id) {
            workoutId = item.workoutId;
            break;
          }
        }
      }

      if (workoutId == null) {
        throw StateError(
          'Workout installed, but the local workout could not be found.',
        );
      }

      setState(() {
        _phase = _DownloadPhase.ready;
        _installedWorkoutId = workoutId;
      });

      final elapsed = DateTime.now().difference(_openedAt);
      final remaining = widget.minimumReadingTime - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      if (!mounted || _userInteracted) return;
      await _openWorkout();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _DownloadPhase.failed;
        _error = '$error';
      });
    }
  }

  Future<void> _openWorkout() async {
    final workoutId = _installedWorkoutId;
    if (!mounted || workoutId == null || _opening) return;
    setState(() => _opening = true);
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          controller: widget.controller,
          workoutId: workoutId,
        ),
      ),
    );
  }

  double? get _progress {
    final total = _totalBytes;
    if (total == null || total <= 0) return null;
    return (_receivedBytes / total).clamp(0.0, 1.0);
  }

  String get _statusText => switch (_phase) {
    _DownloadPhase.preview => 'Available to download',
    _DownloadPhase.downloading =>
      _artifact == 'assets'
          ? 'Downloading workout media…'
          : 'Downloading workout definition…',
    _DownloadPhase.installing => 'Installing workout…',
    _DownloadPhase.ready => 'Workout ready',
    _DownloadPhase.failed => 'Download failed',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop:
          _phase == _DownloadPhase.preview ||
          _phase == _DownloadPhase.ready ||
          _phase == _DownloadPhase.failed,
      child: Scaffold(
        appBar: AppBar(title: const Text('Workout details')),
        bottomNavigationBar: _DownloadActionBar(
          phase: _phase,
          progress: _progress,
          statusText: _statusText,
          sizeText: _formatBytes(widget.entry.assetsSize),
          error: _error,
          compatibilityError: widget.controller.bucketEntryCompatibilityError(
            widget.entry,
          ),
          onDownload: _install,
          onOpen: _openWorkout,
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification && !_userInteracted) {
              setState(() => _userInteracted = true);
            }
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 200,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      WorkoutArtwork(
                        tags: widget.entry.tags,
                        kind: WorkoutArtworkKind.feature,
                        bucketEntry: widget.entry,
                        bucketService: widget.controller.workoutBuckets,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xB3000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: Text(
                          widget.entry.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.entry.description.isNotEmpty) ...[
                Text(
                  widget.entry.description,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (widget.entry.durationSeconds case final seconds?)
                    _QuickFact(
                      icon: Icons.schedule,
                      label: _formatDuration(seconds),
                    ),
                  if (widget.entry.difficulty case final difficulty?)
                    _QuickFact(
                      icon: Icons.signal_cellular_alt,
                      label: difficulty,
                    ),
                  _QuickFact(
                    icon: Icons.fitness_center,
                    label: widget.entry.equipment.isEmpty
                        ? 'No equipment'
                        : widget.entry.equipment.join(', '),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _AuthorAndPopularity(entry: widget.entry),
              if (widget.entry.benefits.isNotEmpty) ...[
                const SizedBox(height: 28),
                const _SectionHeading('What you’ll get'),
                const SizedBox(height: 10),
                for (final benefit in widget.entry.benefits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 19,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: Text(benefit)),
                      ],
                    ),
                  ),
              ],
              if (widget.entry.stepPreview.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: _SectionHeading('Workout outline')),
                    if (widget.entry.stepCount case final count?)
                      Text(
                        '$count steps',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ...(_showAllSteps
                        ? widget.entry.stepPreview
                        : widget.entry.stepPreview.take(5))
                    .toList()
                    .asMap()
                    .entries
                    .map(
                      (item) =>
                          _OutlineStep(index: item.key + 1, step: item.value),
                    ),
                if (widget.entry.stepPreview.length > 5)
                  TextButton(
                    onPressed: () =>
                        setState(() => _showAllSteps = !_showAllSteps),
                    child: Text(
                      _showAllSteps ? 'Show less' : 'See the full workout',
                    ),
                  ),
              ],
              if (widget.entry.intensity != null ||
                  widget.entry.space != null) ...[
                const SizedBox(height: 24),
                const _SectionHeading('Good to know'),
                const SizedBox(height: 10),
                if (widget.entry.intensity case final intensity?)
                  _RequirementRow(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Intensity',
                    value: intensity,
                  ),
                if (widget.entry.space case final space?)
                  _RequirementRow(
                    icon: Icons.crop_free,
                    label: 'Space',
                    value: space,
                  ),
              ],
              if (widget.entry.tags.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final tag in widget.entry.tags.take(4))
                      Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Technical information',
                  icon: const Icon(Icons.info_outline, size: 20),
                  onPressed: () => _showTechnicalInformation(context),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final minutes = (seconds / 60).ceil();
    return '$minutes min';
  }

  Future<void> _showTechnicalInformation(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Workout information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source: ${widget.sourceName}'),
            Text('Version: ${widget.entry.version}'),
            Text('Media download: ${_formatBytes(widget.entry.assetsSize)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

class _QuickFact extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickFact({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _AuthorAndPopularity extends StatelessWidget {
  final WorkoutBucketEntry entry;

  const _AuthorAndPopularity({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final author = entry.author?.trim();
    return Row(
      children: [
        if (author != null && author.isNotEmpty) ...[
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.primaryContainer,
            child: Text(
              author.characters.first.toUpperCase(),
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (entry.authorVerified) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.verified, size: 17, color: colors.primary),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
        ],
        Icon(Icons.download_outlined, size: 17, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          entry.downloadCount == 0
              ? 'New'
              : '${_compactCount(entry.downloadCount)} downloads',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static String _compactCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;

  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _OutlineStep extends StatelessWidget {
  final int index;
  final WorkoutBucketStepPreview step;

  const _OutlineStep({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: colors.surfaceContainerHighest,
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              step.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (step.hasGuide)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.volume_up_outlined,
                size: 17,
                color: colors.onSurfaceVariant,
              ),
            ),
          if (step.hasMedia)
            Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Icon(
                Icons.play_circle_outline,
                size: 17,
                color: colors.onSurfaceVariant,
              ),
            ),
          if (step.durationSeconds > 0) ...[
            const SizedBox(width: 9),
            Text(
              _stepDuration(step.durationSeconds),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  static String _stepDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainder = seconds.remainder(60);
    return remainder == 0 ? '${minutes}m' : '${minutes}m ${remainder}s';
  }
}

class _RequirementRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RequirementRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 10),
        SizedBox(width: 78, child: Text(label)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _DownloadActionBar extends StatelessWidget {
  final _DownloadPhase phase;
  final double? progress;
  final String statusText;
  final String sizeText;
  final String? error;
  final String? compatibilityError;
  final VoidCallback onDownload;
  final VoidCallback onOpen;

  const _DownloadActionBar({
    required this.phase,
    required this.progress,
    required this.statusText,
    required this.sizeText,
    required this.error,
    required this.compatibilityError,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 12,
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (phase == _DownloadPhase.downloading ||
                  phase == _DownloadPhase.installing) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        statusText,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (progress != null) Text('${(progress! * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: phase == _DownloadPhase.downloading ? progress : null,
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: phase == _DownloadPhase.ready
                        ? onOpen
                        : compatibilityError == null
                        ? onDownload
                        : null,
                    icon: Icon(
                      phase == _DownloadPhase.failed
                          ? Icons.refresh
                          : phase == _DownloadPhase.ready
                          ? Icons.arrow_forward
                          : Icons.download,
                    ),
                    label: Text(
                      phase == _DownloadPhase.failed
                          ? 'Try again'
                          : phase == _DownloadPhase.ready
                          ? 'Open workout'
                          : 'Download workout · $sizeText',
                    ),
                  ),
                ),
              if (compatibilityError != null) ...[
                const SizedBox(height: 7),
                Text(
                  compatibilityError!,
                  style: TextStyle(color: colors.error),
                ),
              ] else if (phase == _DownloadPhase.failed && error != null) ...[
                const SizedBox(height: 7),
                Text(
                  error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.error),
                ),
              ] else if (phase == _DownloadPhase.preview) ...[
                const SizedBox(height: 6),
                Text(
                  'Available offline after download',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
