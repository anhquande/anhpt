import 'package:flutter/material.dart';

import '../models/workout_session.dart';
import '../services/local_store.dart';
import '../services/workout_session_history.dart';

class WorkoutHistoryScreen extends StatelessWidget {
  final LocalStore store;
  final String profileId;
  final String? profileName;

  const WorkoutHistoryScreen({
    super.key,
    required this.store,
    required this.profileId,
    this.profileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workout history',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: WorkoutSessionHistory.revision,
        builder: (context, _, __) => FutureBuilder<List<WorkoutSession>>(
          future: WorkoutSessionHistory(store).load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const _HistoryMessage(
                icon: Icons.error_outline,
                title: 'Could not load workout history',
                message: 'Your workout data was not changed.',
              );
            }

            final sessions = (snapshot.data ?? const <WorkoutSession>[])
                .where((session) => session.profileId == profileId)
                .toList()
              ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

            if (sessions.isEmpty) {
              return _HistoryMessage(
                icon: Icons.history_toggle_off_outlined,
                title: 'No workout history yet',
                message: profileName == null || profileName!.trim().isEmpty
                    ? 'Workout sessions for this profile will appear here.'
                    : 'Workout sessions for ${profileName!.trim()} will appear here.',
              );
            }

            final groups = _groupByDay(sessions);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    if (profileName != null && profileName!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          profileName!.trim(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    for (final entry in groups.entries) ...[
                      _DayHeading(day: entry.key),
                      const SizedBox(height: 8),
                      for (final session in entry.value) ...[
                        _HistorySessionTile(session: session),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Map<DateTime, List<WorkoutSession>> _groupByDay(
    List<WorkoutSession> sessions,
  ) {
    final groups = <DateTime, List<WorkoutSession>>{};
    for (final session in sessions) {
      final day = DateUtils.dateOnly(session.endedAt);
      groups.putIfAbsent(day, () => <WorkoutSession>[]).add(session);
    }
    return groups;
  }
}

class _DayHeading extends StatelessWidget {
  final DateTime day;

  const _DayHeading({required this.day});

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final label = DateUtils.isSameDay(day, today)
        ? 'Today'
        : DateUtils.isSameDay(day, yesterday)
            ? 'Yesterday'
            : MaterialLocalizations.of(context).formatMediumDate(day);

    return Text(
      label,
      key: ValueKey('workout-history-day-${day.toIso8601String()}'),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _HistorySessionTile extends StatelessWidget {
  final WorkoutSession session;

  const _HistorySessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(session.endedAt),
    );
    final duration = _formatDuration(session.activeDuration);
    final steps = session.totalSteps <= 0
        ? '${session.completedSteps} steps'
        : '${session.completedSteps}/${session.totalSteps} steps';
    final incomplete = session.status == WorkoutSessionStatus.incomplete;

    return Container(
      key: ValueKey('workout-history-session-${session.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: incomplete
                  ? scheme.surfaceContainerHighest
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              incomplete ? Icons.pause_circle_outline : Icons.check,
              color: incomplete
                  ? scheme.onSurfaceVariant
                  : scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.workoutName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$time • $duration • $steps',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (incomplete) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Incomplete',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration <= Duration.zero) return '0 min';
    if (duration.inMinutes == 0) return '<1 min';
    return '${duration.inMinutes} min';
  }
}

class _HistoryMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
