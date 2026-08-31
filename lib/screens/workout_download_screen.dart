import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/workout_bucket.dart';
import '../services/workout_bucket_service.dart';
import 'workout_detail_screen.dart';

enum _DownloadPhase { downloading, installing, ready, failed }

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
  _DownloadPhase _phase = _DownloadPhase.downloading;
  StreamSubscription<BucketPackageProgressEvent>? _progressSubscription;
  int _receivedBytes = 0;
  int? _totalBytes;
  String? _error;
  String? _installedWorkoutId;
  bool _userInteracted = false;
  bool _opening = false;
  late DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _progressSubscription = WorkoutBucketService.packageProgress.listen((event) {
      if (!mounted || event.entryId != widget.entry.id) return;
      setState(() {
        _receivedBytes = event.receivedBytes;
        _totalBytes = event.totalBytes ?? widget.entry.size;
      });
    });
    _install();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _install() async {
    final existingWorkoutIds =
        widget.controller.workouts.map((workout) => workout.id).toSet();
    if (mounted) {
      setState(() {
        _phase = _DownloadPhase.downloading;
        _receivedBytes = 0;
        _totalBytes = widget.entry.size;
        _error = null;
        _installedWorkoutId = null;
        _opening = false;
      });
    }

    try {
      final installFuture = widget.controller.installBucketEntry(
        widget.entry,
        resolution: widget.resolution,
      );

      // Once all bytes have arrived, the remaining work is package validation,
      // extraction, media import and persistence.
      while (mounted && _phase == _DownloadPhase.downloading) {
        final total = _totalBytes;
        if (total != null && total > 0 && _receivedBytes >= total) {
          setState(() => _phase = _DownloadPhase.installing);
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      final installed = await installFuture;
      if (!installed || !mounted) return;

      String? workoutId;
      for (final workout in widget.controller.workouts) {
        if (!existingWorkoutIds.contains(workout.id)) {
          workoutId = workout.id;
          break;
        }
      }
      workoutId ??= widget.controller.installedBucketWorkouts
          .where((item) =>
              item.sourceId == widget.entry.sourceId &&
              item.entryId == widget.entry.id)
          .map((item) => item.workoutId)
          .lastOrNull;

      if (workoutId == null) {
        throw StateError('Workout installed, but the local workout could not be found.');
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
        _DownloadPhase.downloading => 'Downloading workout…',
        _DownloadPhase.installing => 'Installing workout…',
        _DownloadPhase.ready => 'Workout ready',
        _DownloadPhase.failed => 'Download failed',
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _phase == _DownloadPhase.ready || _phase == _DownloadPhase.failed,
      child: Scaffold(
        appBar: AppBar(title: const Text('Workout download')),
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
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _thumbnailIcon(widget.entry.tags),
                  size: 68,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.entry.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (_recommended) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Recommended'),
                  ),
                ),
              ],
              if (widget.entry.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  widget.entry.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(icon: Icons.cloud_outlined, label: widget.sourceName),
                  _MetaChip(
                    icon: Icons.system_update_alt,
                    label: 'Version ${widget.entry.version}',
                  ),
                  if (widget.entry.author != null)
                    _MetaChip(
                      icon: Icons.person_outline,
                      label: widget.entry.author!,
                    ),
                  if (widget.entry.size != null)
                    _MetaChip(
                      icon: Icons.data_usage_outlined,
                      label: _formatBytes(widget.entry.size!),
                    ),
                ],
              ),
              if (widget.entry.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in widget.entry.tags)
                      if (tag.trim().toLowerCase() != 'recommended')
                        Chip(label: Text(tag)),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _phase == _DownloadPhase.ready
                                ? Icons.check_circle
                                : _phase == _DownloadPhase.failed
                                    ? Icons.error_outline
                                    : Icons.downloading,
                            color: _phase == _DownloadPhase.failed
                                ? colors.error
                                : colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _statusText,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_phase == _DownloadPhase.downloading &&
                              _progress != null)
                            Text('${(_progress! * 100).round()}%'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_phase == _DownloadPhase.downloading)
                        LinearProgressIndicator(value: _progress)
                      else if (_phase == _DownloadPhase.installing)
                        const LinearProgressIndicator()
                      else if (_phase == _DownloadPhase.ready)
                        LinearProgressIndicator(
                          value: 1,
                          color: colors.primary,
                        ),
                      if (_phase == _DownloadPhase.downloading) ...[
                        const SizedBox(height: 8),
                        Text(
                          _downloadSizeText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                      if (_phase == _DownloadPhase.failed && _error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: TextStyle(color: colors.error),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _install,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                      if (_phase == _DownloadPhase.ready && _userInteracted) ...[
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _openWorkout,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Open workout'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _recommended => widget.entry.tags
      .any((tag) => tag.trim().toLowerCase() == 'recommended');

  String get _downloadSizeText {
    final total = _totalBytes;
    if (total == null) return _formatBytes(_receivedBytes);
    return '${_formatBytes(_receivedBytes)} / ${_formatBytes(total)}';
  }

  IconData _thumbnailIcon(List<String> tags) {
    final values = tags.map((tag) => tag.toLowerCase()).toSet();
    if (values.any((tag) => tag.contains('karate') || tag.contains('martial'))) {
      return Icons.sports_martial_arts;
    }
    if (values.any((tag) => tag.contains('yoga') || tag.contains('mobility'))) {
      return Icons.self_improvement;
    }
    if (values.any((tag) => tag.contains('hiit') || tag.contains('cardio'))) {
      return Icons.bolt;
    }
    return Icons.fitness_center;
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

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
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      );
}
