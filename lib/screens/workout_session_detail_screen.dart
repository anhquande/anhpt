import 'package:flutter/material.dart';

import '../models/workout_session.dart';

class WorkoutSessionDetailScreen extends StatelessWidget {
  final WorkoutSession session;

  const WorkoutSessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final incomplete = session.status == WorkoutSessionStatus.incomplete;
    final progress = session.totalSteps <= 0
        ? 0.0
        : (session.completedSteps / session.totalSteps).clamp(0.0, 1.0);
    final progressPercent = (progress * 100).round();
    final date = localizations.formatMediumDate(session.endedAt);
    final startedAt = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(session.startedAt),
    );
    final endedAt = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(session.endedAt),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Session details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text(
                session.workoutName,
                key: const Key('session-detail-workout-name'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                date,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              Container(
                key: const Key('session-detail-status-card'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: incomplete
                      ? scheme.surfaceContainerLow
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: incomplete ? scheme.outlineVariant : scheme.primary,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          incomplete
                              ? Icons.pause_circle_outline
                              : Icons.check_circle_outline,
                          color: incomplete
                              ? scheme.onSurfaceVariant
                              : scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          incomplete ? 'Incomplete session' : 'Workout completed',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              key: const Key('session-detail-progress'),
                              value: progress,
                              minHeight: 9,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '$progressPercent%',
                          key: const Key('session-detail-progress-percent'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    if (incomplete) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Progress reflects the steps recorded before this session ended.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _DetailCard(
                children: [
                  _DetailRow(
                    icon: Icons.timer_outlined,
                    label: 'Active time',
                    value: _formatDuration(session.activeDuration),
                  ),
                  _DetailRow(
                    icon: Icons.format_list_numbered,
                    label: 'Steps',
                    value: session.totalSteps <= 0
                        ? '${session.completedSteps}'
                        : '${session.completedSteps} / ${session.totalSteps}',
                  ),
                  _DetailRow(
                    icon: Icons.play_arrow_outlined,
                    label: 'Started',
                    value: startedAt,
                  ),
                  _DetailRow(
                    icon: Icons.flag_outlined,
                    label: 'Ended',
                    value: endedAt,
                  ),
                  if (session.profileName != null &&
                      session.profileName!.trim().isNotEmpty)
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Profile',
                      value: session.profileName!.trim(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration <= Duration.zero) return '0 min';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) {
      if (duration.inMinutes == 0) return '<1 min';
      return '${duration.inMinutes} min';
    }
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes} min';
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 21, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
