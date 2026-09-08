enum WorkoutSessionStatus { completed, incomplete }

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
  });

  bool get completed => status == WorkoutSessionStatus.completed;

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
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? 'completed';
    final status = WorkoutSessionStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => WorkoutSessionStatus.incomplete,
    );
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
    );
  }
}
