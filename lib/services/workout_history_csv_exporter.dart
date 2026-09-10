import '../models/workout_session.dart';

class WorkoutHistoryCsvExporter {
  static const headers = <String>[
    'session_id',
    'workout_id',
    'workout_name',
    'profile_id',
    'profile_name',
    'started_at',
    'ended_at',
    'status',
    'active_duration_seconds',
    'completed_steps',
    'total_steps',
    'estimated_calories',
    'effort',
    'note',
  ];

  const WorkoutHistoryCsvExporter();

  String encode(Iterable<WorkoutSession> sessions) {
    final lines = <String>[
      headers.map(_escape).join(','),
      for (final session in sessions)
        <String>[
          session.id,
          session.workoutId,
          session.workoutName,
          session.profileId ?? '',
          session.profileName ?? '',
          session.startedAt.toLocal().toIso8601String(),
          session.endedAt.toLocal().toIso8601String(),
          session.status.name,
          session.activeDuration.inSeconds.toString(),
          session.completedSteps.toString(),
          session.totalSteps.toString(),
          session.estimatedCalories?.toString() ?? '',
          session.effort?.name ?? '',
          session.note ?? '',
        ].map(_escape).join(','),
    ];
    return '${lines.join('\r\n')}\r\n';
  }

  String fileName({String? profileName, DateTime? now}) {
    final date = (now ?? DateTime.now()).toLocal();
    final datePart = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final profilePart = _safeFilePart(profileName ?? 'profile');
    return 'anhpt-workout-history-$profilePart-$datePart.csv';
  }

  static String _escape(String value) {
    if (!value.contains(',') &&
        !value.contains('"') &&
        !value.contains('\n') &&
        !value.contains('\r')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  static String _safeFilePart(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final trimmed = normalized.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed.isEmpty ? 'profile' : trimmed;
  }
}
