import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/workout_session.dart';
import '../services/local_store.dart';
import '../services/workout_history_filter.dart';
import '../services/workout_session_analytics.dart';
import '../services/workout_session_history.dart';
import '../widgets/monthly_workout_progress.dart';
import '../widgets/yearly_workout_progress.dart';
import 'workout_session_detail_screen.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  final LocalStore store;
  final String profileId;
  final String? profileName;
  final AppController? controller;

  const WorkoutHistoryScreen({
    super.key,
    required this.store,
    required this.profileId,
    this.profileName,
    this.controller,
  });

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  WorkoutHistoryStatusFilter _status = WorkoutHistoryStatusFilter.all;
  WorkoutHistoryPeriodFilter _period = WorkoutHistoryPeriodFilter.allTime;
  String? _workoutId;
  final ScrollController _scrollController = ScrollController();

  WorkoutHistoryFilter get _filter => WorkoutHistoryFilter(
        status: _status,
        period: _period,
        workoutId: _workoutId,
      );

  void _clearFilters() {
    setState(() {
      _status = WorkoutHistoryStatusFilter.all;
      _period = WorkoutHistoryPeriodFilter.allTime;
      _workoutId = null;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
          future: WorkoutSessionHistory(widget.store).load(),
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
                .where((session) => session.profileId == widget.profileId)
                .toList()
              ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

            if (sessions.isEmpty) {
              return _HistoryMessage(
                icon: Icons.history_toggle_off,
                title: 'No workout history yet',
                message: widget.profileName == null ||
                        widget.profileName!.trim().isEmpty
                    ? 'Workout sessions for this profile will appear here.'
                    : 'Workout sessions for ${widget.profileName!.trim()} will appear here.',
              );
            }

            final monthlySummary = WorkoutSessionAnalytics.monthlySummary(
              sessions,
              profileId: widget.profileId,
            );
            final yearlySummary = WorkoutSessionAnalytics.yearlySummary(
              sessions,
              profileId: widget.profileId,
            );
            final workouts = _workoutChoices(sessions);
            if (_workoutId != null &&
                !workouts.any((entry) => entry.$1 == _workoutId)) {
              _workoutId = null;
            }
            final filteredSessions = _filter.apply(sessions);
            final groups = _groupByDay(filteredSessions);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  controller: _scrollController,
                  key: const PageStorageKey('workout-history-list'),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    if (widget.profileName != null &&
                        widget.profileName!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          widget.profileName!.trim(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    MonthlyWorkoutProgressCard(summary: monthlySummary),
                    const SizedBox(height: 16),
                    YearlyWorkoutProgressCard(summary: yearlySummary),
                    const SizedBox(height: 20),
                    _HistoryFilters(
                      status: _status,
                      period: _period,
                      workoutId: _workoutId,
                      workouts: workouts,
                      resultCount: filteredSessions.length,
                      showClear: !_filter.isDefault,
                      onStatusChanged: (value) => setState(() => _status = value),
                      onPeriodChanged: (value) => setState(() => _period = value),
                      onWorkoutChanged: (value) =>
                          setState(() => _workoutId = value),
                      onClear: _clearFilters,
                    ),
                    const SizedBox(height: 20),
                    if (filteredSessions.isEmpty)
                      const _FilteredEmptyState()
                    else
                      for (final entry in groups.entries) ...[
                        _DayHeading(day: entry.key),
                        const SizedBox(height: 8),
                        for (final session in entry.value) ...[
                          _HistorySessionTile(
                            session: session,
                            controller: widget.controller,
                          ),
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

  static List<(String, String)> _workoutChoices(List<WorkoutSession> sessions) {
    final names = <String, String>{};
    for (final session in sessions) {
      names.putIfAbsent(session.workoutId, () => session.workoutName);
    }
    final entries = names.entries.map((entry) => (entry.key, entry.value)).toList();
    entries.sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
    return entries;
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

class _HistoryFilters extends StatelessWidget {
  final WorkoutHistoryStatusFilter status;
  final WorkoutHistoryPeriodFilter period;
  final String? workoutId;
  final List<(String, String)> workouts;
  final int resultCount;
  final bool showClear;
  final ValueChanged<WorkoutHistoryStatusFilter> onStatusChanged;
  final ValueChanged<WorkoutHistoryPeriodFilter> onPeriodChanged;
  final ValueChanged<String?> onWorkoutChanged;
  final VoidCallback onClear;

  const _HistoryFilters({
    required this.status,
    required this.period,
    required this.workoutId,
    required this.workouts,
    required this.resultCount,
    required this.showClear,
    required this.onStatusChanged,
    required this.onPeriodChanged,
    required this.onWorkoutChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('workout-history-filters'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: 'All',
                value: WorkoutHistoryStatusFilter.all,
                selected: status == WorkoutHistoryStatusFilter.all,
                onSelected: onStatusChanged,
              ),
              _StatusChip(
                label: 'Completed',
                value: WorkoutHistoryStatusFilter.completed,
                selected: status == WorkoutHistoryStatusFilter.completed,
                onSelected: onStatusChanged,
              ),
              _StatusChip(
                label: 'Incomplete',
                value: WorkoutHistoryStatusFilter.incomplete,
                selected: status == WorkoutHistoryStatusFilter.incomplete,
                onSelected: onStatusChanged,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<WorkoutHistoryPeriodFilter>(
                  key: const Key('workout-history-period-filter'),
                  initialValue: period,
                  decoration: const InputDecoration(
                    labelText: 'Period',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: WorkoutHistoryPeriodFilter.allTime,
                      child: Text('All time'),
                    ),
                    DropdownMenuItem(
                      value: WorkoutHistoryPeriodFilter.thisWeek,
                      child: Text('This week'),
                    ),
                    DropdownMenuItem(
                      value: WorkoutHistoryPeriodFilter.thisMonth,
                      child: Text('This month'),
                    ),
                    DropdownMenuItem(
                      value: WorkoutHistoryPeriodFilter.thisYear,
                      child: Text('This year'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onPeriodChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  key: const Key('workout-history-workout-filter'),
                  initialValue: workoutId,
                  decoration: const InputDecoration(
                    labelText: 'Workout',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All workouts'),
                    ),
                    for (final workout in workouts)
                      DropdownMenuItem<String?>(
                        value: workout.$1,
                        child: Text(
                          workout.$2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onWorkoutChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$resultCount ${resultCount == 1 ? 'session' : 'sessions'}',
                key: const Key('workout-history-result-count'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              if (showClear)
                TextButton.icon(
                  key: const Key('workout-history-clear-filters'),
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final WorkoutHistoryStatusFilter value;
  final bool selected;
  final ValueChanged<WorkoutHistoryStatusFilter> onSelected;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      key: ValueKey('workout-history-status-${value.name}'),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 38,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text(
            'No sessions match these filters.',
            key: Key('workout-history-filter-empty'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
  final AppController? controller;

  const _HistorySessionTile({required this.session, this.controller});

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('workout-history-session-${session.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorkoutSessionDetailScreen(
              session: session,
              controller: controller,
            ),
          ),
        ),
        child: Ink(
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
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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
