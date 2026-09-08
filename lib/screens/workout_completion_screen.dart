import 'dart:async';

import 'package:flutter/material.dart';

import '../models/workout_session.dart';
import '../services/health_store.dart';
import '../services/local_store.dart';
import '../services/workout_session_history.dart';
import '../widgets/common.dart';
import '../widgets/weekly_workout_feedback.dart';

class WorkoutCompletionScreen extends StatefulWidget {
  final String workoutName;
  final String? profileName;
  final Duration activeTime;
  final int completedSteps;
  final int totalSteps;
  final double progress;
  final int? estimatedCalories;
  final String? progressContext;
  final VoidCallback? onViewProgress;
  final VoidCallback? onDone;
  final bool persistSession;

  const WorkoutCompletionScreen({
    super.key,
    required this.workoutName,
    required this.activeTime,
    required this.completedSteps,
    required this.totalSteps,
    required this.progress,
    this.profileName,
    this.estimatedCalories,
    this.progressContext,
    this.onViewProgress,
    this.onDone,
    this.persistSession = true,
  });

  @override
  State<WorkoutCompletionScreen> createState() => _WorkoutCompletionScreenState();
}

class _WorkoutCompletionScreenState extends State<WorkoutCompletionScreen> {
  WeeklyWorkoutSummary? _weeklySummary;
  String? _resolvedProfileName;

  @override
  void initState() {
    super.initState();
    _resolvedProfileName = widget.profileName;
    if (widget.persistSession) {
      unawaited(_persistSessionAndLoadFeedback());
    }
  }

  Future<void> _persistSessionAndLoadFeedback() async {
    try {
      final store = LocalStore();
      final history = WorkoutSessionHistory(store);

      String? profileId;
      var profileName = widget.profileName;
      try {
        final profile = await HealthStore().activeLocalProfile();
        profileId = profile.id;
        profileName ??= profile.name;
      } catch (_) {
        // Workout history must still work if profile storage is unavailable.
      }

      var workoutId = 'snapshot:${widget.workoutName}';
      try {
        final workouts = await store.loadWorkouts();
        for (final workout in workouts) {
          if (workout.name == widget.workoutName) {
            workoutId = workout.id;
            break;
          }
        }
      } catch (_) {
        // The name snapshot is enough for weekly activity accounting.
      }

      await history.record(
        workoutId: workoutId,
        workoutName: widget.workoutName,
        profileId: profileId,
        profileName: profileName,
        activeDuration: widget.activeTime,
        completedSteps: widget.completedSteps,
        totalSteps: widget.totalSteps,
        status: WorkoutSessionStatus.completed,
      );

      final summary = await history.weeklySummary(profileId: profileId);
      if (!mounted) return;
      setState(() {
        _weeklySummary = summary;
        _resolvedProfileName = profileName;
      });
    } catch (error) {
      // Session persistence is useful feedback, but it must never make a
      // successfully completed workout look like a failure.
      debugPrint('Could not persist workout session: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (widget.progress.clamp(0.0, 1.0) * 100).round();
    final metrics = <_SummaryMetric>[
      _SummaryMetric(
        icon: Icons.timer_outlined,
        value: formatDuration(widget.activeTime),
        label: 'Active time',
      ),
      _SummaryMetric(
        icon: Icons.checklist_rounded,
        value: '${widget.completedSteps} / ${widget.totalSteps}',
        label: 'Steps completed',
      ),
      _SummaryMetric(
        icon: Icons.insights_outlined,
        value: '$percent%',
        label: 'Workout progress',
      ),
      if (widget.estimatedCalories != null && widget.estimatedCalories! > 0)
        _SummaryMetric(
          icon: Icons.local_fire_department_outlined,
          value: '~${widget.estimatedCalories} kcal',
          label: 'Estimated calories',
        ),
    ];

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 52,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 48,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Workout complete 🎉',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.workoutName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (_resolvedProfileName != null &&
                          _resolvedProfileName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _resolvedProfileName!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, metricConstraints) {
                          final twoColumns = metricConstraints.maxWidth >= 360;
                          final width = twoColumns
                              ? (metricConstraints.maxWidth - 12) / 2
                              : metricConstraints.maxWidth;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final metric in metrics)
                                SizedBox(
                                  width: width,
                                  child: _MetricCard(metric: metric),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.completedSteps >= widget.totalSteps
                            ? 'You finished every planned step. Nice work.'
                            : 'You completed ${widget.completedSteps} of ${widget.totalSteps} planned steps.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      if (_weeklySummary != null) ...[
                        const SizedBox(height: 16),
                        WeeklyWorkoutFeedbackCard(summary: _weeklySummary!),
                      ],
                      if (widget.progressContext != null &&
                          widget.progressContext!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.progressContext!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: widget.onDone ??
                            () => Navigator.of(context).popUntil((route) => route.isFirst),
                        child: const Text('Done'),
                      ),
                      if (widget.onViewProgress != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: widget.onViewProgress,
                          child: const Text('View progress'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
}

class _MetricCard extends StatelessWidget {
  final _SummaryMetric metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
