enum WorkoutSessionStatus { completed, incomplete }

enum WorkoutSessionEffort { easy, moderate, hard }

class WorkoutSession {
  final String id;
  final String workoutId;
  final String workoutName;
  final String? profileId;
  final String? profileName;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration activeDuration;
  final int completedSteps;
  final int totalSteps;
  final WorkoutSessionStatus status;
  final String? note;
  final int? estimatedCalories;
  final WorkoutSessionEffort? effort;

  const WorkoutSession({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    this.profileId,
    this.profileName,
    required this.startedAt,
    required this.endedAt,
    required this.activeDuration,
    required this.completedSteps,
    required this.totalSteps,
    required this.status,
    this.note,
    this.estimatedCalories,
    this.effort,
  });

  bool get completed => status == WorkoutSessionStatus.completed;

  WorkoutSession copyWithNote(String? value) {
    final normalized = value?.trim();
    return copyWithMetrics(
      note: normalized == null || normalized.isEmpty ? null : normalized,
      replaceNote: true,
    );
  }

  WorkoutSession copyWithMetrics({
    int? estimatedCalories,
    WorkoutSessionEffort? effort,
    bool replaceCalories = false,
    bool replaceEffort = false,
    String? note,
    bool replaceNote = false,
  }) {
    final calories = replaceCalories ? estimatedCalories : this.estimatedCalories;
    if (calories != null && calories < 0) {
      throw ArgumentError.value(calories, 'estimatedCalories', 'must be non-negative');
    }
    return WorkoutSession(
      id: id,
      workoutId: workoutId,
      workoutName: workoutName,
      profileId: profileId,
      profileName: profileName,
      startedAt: startedAt,
      endedAt: endedAt,
      activeDuration: activeDuration,
      completedSteps: completedSteps,
      totalSteps: totalSteps,
      status: status,
      note: replaceNote ? note : this.note,
      estimatedCalories: calories,
      effort: replaceEffort ? effort : this.effort,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workoutId': workoutId,
        'workoutName': workoutName,
        if (profileId != null) 'profileId': profileId,
        if (profileName != null) 'profileName': profileName,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'activeDurationMs': activeDuration.inMilliseconds,
        'completedSteps': completedSteps,
        'totalSteps': totalSteps,
        'status': status.name,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
        if (estimatedCalories != null) 'estimatedCalories': estimatedCalories,
        if (effort != null) 'effort': effort!.name,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? 'completed';
    final status = WorkoutSessionStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => WorkoutSessionStatus.incomplete,
    );
    final effortName = json['effort'] as String?;
    final effort = effortName == null
        ? null
        : WorkoutSessionEffort.values.cast<WorkoutSessionEffort?>().firstWhere(
              (value) => value?.name == effortName,
              orElse: () => null,
            );
    final rawNote = (json['note'] as String?)?.trim();
    final rawCalories = (json['estimatedCalories'] as num?)?.round();
    return WorkoutSession(
      id: json['id'] as String,
      workoutId: json['workoutId'] as String,
      workoutName: json['workoutName'] as String,
      profileId: json['profileId'] as String?,
      profileName: json['profileName'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
      endedAt: DateTime.parse(json['endedAt'] as String).toLocal(),
      activeDuration: Duration(
        milliseconds: (json['activeDurationMs'] as num?)?.round() ?? 0,
      ),
      completedSteps: (json['completedSteps'] as num?)?.round() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.round() ?? 0,
      status: status,
      note: rawNote == null || rawNote.isEmpty ? null : rawNote,
      estimatedCalories:
          rawCalories == null || rawCalories < 0 ? null : rawCalories,
      effort: effort,
    );
  }
}
