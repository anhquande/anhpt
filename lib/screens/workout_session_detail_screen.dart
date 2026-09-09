import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/workout_session.dart';
import '../services/local_store.dart';
import '../services/workout_session_history.dart';
import 'workout_player_screen.dart';

class WorkoutSessionDetailScreen extends StatefulWidget {
  final WorkoutSession session;
  final AppController? controller;

  const WorkoutSessionDetailScreen({
    super.key,
    required this.session,
    this.controller,
  });

  @override
  State<WorkoutSessionDetailScreen> createState() =>
      _WorkoutSessionDetailScreenState();
}

class _WorkoutSessionDetailScreenState extends State<WorkoutSessionDetailScreen> {
  late WorkoutSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  @override
  void didUpdateWidget(covariant WorkoutSessionDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id) {
      _session = widget.session;
    }
  }

  Future<void> _editNote() async {
    var draftNote = _session.note ?? '';
    final result = await showDialog<_NoteEditResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session note'),
        content: TextFormField(
          key: const Key('session-detail-note-editor'),
          initialValue: draftNote,
          onChanged: (value) => draftNote = value,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'How did this workout feel?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('session-detail-save-note'),
            onPressed: () => Navigator.of(context).pop(
              _NoteEditResult(draftNote),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;

    try {
      final updated = await WorkoutSessionHistory(LocalStore()).updateNote(
        sessionId: _session.id,
        note: result.note,
      );
      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This session could not be found.')),
        );
        return;
      }
      setState(() => _session = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the session note.')),
      );
    }
  }

  Future<void> _editMetrics() async {
    var caloriesText = _session.estimatedCalories?.toString() ?? '';
    var effort = _session.effort;
    String? validationError;

    final result = await showDialog<_MetricsEditResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Workout metrics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('session-detail-calories-editor'),
                initialValue: caloriesText,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  caloriesText = value;
                  if (validationError != null) {
                    setDialogState(() => validationError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Calories',
                  suffixText: 'kcal',
                  errorText: validationError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<WorkoutSessionEffort?>(
                key: const Key('session-detail-effort-editor'),
                initialValue: effort,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Effort',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Not set')),
                  DropdownMenuItem(
                    value: WorkoutSessionEffort.easy,
                    child: Text('Easy'),
                  ),
                  DropdownMenuItem(
                    value: WorkoutSessionEffort.moderate,
                    child: Text('Moderate'),
                  ),
                  DropdownMenuItem(
                    value: WorkoutSessionEffort.hard,
                    child: Text('Hard'),
                  ),
                ],
                onChanged: (value) => effort = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('session-detail-save-metrics'),
              onPressed: () {
                final trimmed = caloriesText.trim();
                final parsed = trimmed.isEmpty ? null : int.tryParse(trimmed);
                if (trimmed.isNotEmpty && (parsed == null || parsed < 0)) {
                  setDialogState(
                    () => validationError = 'Enter a non-negative whole number.',
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _MetricsEditResult(parsed, effort),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    try {
      final updated = await WorkoutSessionHistory(LocalStore()).updateMetrics(
        sessionId: _session.id,
        estimatedCalories: result.estimatedCalories,
        effort: result.effort,
      );
      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This session could not be found.')),
        );
        return;
      }
      setState(() => _session = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save workout metrics.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
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
    final canRepeat = widget.controller?.byId(session.workoutId) != null;

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
              const SizedBox(height: 20),
              _MetricsCard(session: session, onEdit: _editMetrics),
              const SizedBox(height: 20),
              _NoteCard(note: session.note, onEdit: _editNote),
              if (canRepeat) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('session-detail-repeat-workout'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WorkoutPlayerScreen(
                        controller: widget.controller!,
                        workoutId: session.workoutId,
                        profileId: session.profileId,
                        profileName: session.profileName,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.replay),
                  label: const Text('Repeat workout'),
                ),
              ],
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
    if (minutes == 0) return '$hours' 'h';
    return '$hours' 'h $minutes min';
  }
}

class _MetricsEditResult {
  final int? estimatedCalories;
  final WorkoutSessionEffort? effort;

  const _MetricsEditResult(this.estimatedCalories, this.effort);
}

class _NoteEditResult {
  final String note;

  const _NoteEditResult(this.note);
}

class _MetricsCard extends StatelessWidget {
  final WorkoutSession session;
  final VoidCallback onEdit;

  const _MetricsCard({required this.session, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final calories = session.estimatedCalories;
    final effort = session.effort;
    final hasMetrics = calories != null || effort != null;
    return Container(
      key: const Key('session-detail-metrics'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Workout metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                key: const Key('session-detail-edit-metrics'),
                tooltip: hasMetrics ? 'Edit metrics' : 'Add metrics',
                onPressed: onEdit,
                icon: Icon(hasMetrics ? Icons.edit_outlined : Icons.add),
              ),
            ],
          ),
          if (!hasMetrics)
            Text(
              'Add calories and how hard this workout felt.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            )
          else ...[
            if (calories != null)
              _MetricLine(
                key: const Key('session-detail-calories'),
                label: 'Calories',
                value: '$calories kcal',
              ),
            if (effort != null)
              _MetricLine(
                key: const Key('session-detail-effort'),
                label: 'Effort',
                value: switch (effort) {
                  WorkoutSessionEffort.easy => 'Easy',
                  WorkoutSessionEffort.moderate => 'Moderate',
                  WorkoutSessionEffort.hard => 'Hard',
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetricLine({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String? note;
  final VoidCallback onEdit;

  const _NoteCard({required this.note, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasNote = note != null && note!.trim().isNotEmpty;
    return Container(
      key: const Key('session-detail-notes'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_outlined, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                key: const Key('session-detail-edit-note'),
                tooltip: hasNote ? 'Edit note' : 'Add note',
                onPressed: onEdit,
                icon: Icon(hasNote ? Icons.edit_outlined : Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasNote ? note!.trim() : 'Add a note about how this workout felt.',
            key: const Key('session-detail-note'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: hasNote ? null : scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
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
