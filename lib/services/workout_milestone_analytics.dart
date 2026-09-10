import '../models/workout_session.dart';
import 'workout_consistency_analytics.dart';

enum WorkoutMilestoneId {
  firstWorkout,
  fiveWorkouts,
  sixtyMinutes,
  threeDayStreak,
  tenWorkouts,
  threeHundredMinutes,
  sevenDayStreak,
}

class WorkoutMilestone {
  final WorkoutMilestoneId id;
  final String title;
  final int current;
  final int target;
  final String unit;

  const WorkoutMilestone({
    required this.id,
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
  });

  bool get unlocked => current >= target;
  double get progress => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);

  String get progressLabel => '$current/$target $unit';
}

class WorkoutMilestoneSummary {
  final List<WorkoutMilestone> milestones;

  const WorkoutMilestoneSummary(this.milestones);

  List<WorkoutMilestone> get unlockedMilestones =>
      milestones.where((milestone) => milestone.unlocked).toList(growable: false);

  int get unlockedCount => unlockedMilestones.length;
  int get totalCount => milestones.length;
  bool get hasActivity => milestones.any((milestone) => milestone.current > 0);

  WorkoutMilestone? get nextMilestone {
    final locked = milestones.where((milestone) => !milestone.unlocked).toList();
    if (locked.isEmpty) return null;
    locked.sort((a, b) {
      final progress = b.progress.compareTo(a.progress);
      if (progress != 0) return progress;
      return milestones.indexOf(a).compareTo(milestones.indexOf(b));
    });
    return locked.first;
  }
}

class WorkoutMilestoneAnalytics {
  const WorkoutMilestoneAnalytics._();

  static WorkoutMilestoneSummary summarize(
    Iterable<WorkoutSession> sessions, {
    String? profileId,
    DateTime? now,
  }) {
    final completed = sessions
        .where((session) => session.completed)
        .where((session) => profileId == null || session.profileId == profileId)
        .toList(growable: false);
    final completedCount = completed.length;
    final activeMinutes = completed.fold<int>(
      0,
      (total, session) => total + session.activeDuration.inMinutes,
    );
    final consistency = WorkoutConsistencyAnalytics.summarize(
      completed,
      profileId: profileId,
      now: now,
    );
    final longestStreak = consistency.longestStreakDays;

    return WorkoutMilestoneSummary([
      WorkoutMilestone(
        id: WorkoutMilestoneId.firstWorkout,
        title: 'First workout',
        current: completedCount,
        target: 1,
        unit: 'workout',
      ),
      WorkoutMilestone(
        id: WorkoutMilestoneId.fiveWorkouts,
        title: '5 workouts',
        current: completedCount,
        target: 5,
        unit: 'workouts',
      ),
      WorkoutMilestone(
        id: WorkoutMilestoneId.sixtyMinutes,
        title: '60 minutes',
        current: activeMinutes,
        target: 60,
        unit: 'min',
      ),
      WorkoutMilestone(
        id: WorkoutMilestoneId.threeDayStreak,
        title: '3-day streak',
        current: longestStreak,
        target: 3,
        unit: 'days',
      ),
      WorkoutMilestone(
        id: WorkoutMilestoneId.tenWorkouts,
        title: '10 workouts',
        current: completedCount,
        target: 10,
        unit: 'workouts',
      ),
      WorkoutMilestone(
        id: WorkoutMilestoneId.threeHundredMinutes,
        title: '300 minutes',
        current: activeMinutes,
        target: 300,
        unit: 'min',
      ),
      WorkoutMilestone(
        id: WorkoutMilestoneId.sevenDayStreak,
        title: '7-day streak',
        current: longestStreak,
        target: 7,
        unit: 'days',
      ),
    ]);
  }
}
