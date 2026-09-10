import '../models/workout_session.dart';
import 'workout_consistency_analytics.dart';
import 'workout_session_analytics.dart';

enum WorkoutInsightType { goal, consistency, recovery, inactivity, trend }

class WorkoutInsight {
  final WorkoutInsightType type;
  final String title;
  final String message;
  final int priority;

  const WorkoutInsight({
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
  });
}

class WorkoutInsightsAnalytics {
  const WorkoutInsightsAnalytics._();

  static List<WorkoutInsight> summarize(
    Iterable<WorkoutSession> sessions, {
    required String profileId,
    required int weeklyGoalDays,
    DateTime? now,
    int maxInsights = 3,
  }) {
    final reference = (now ?? DateTime.now()).toLocal();
    final profileSessions = sessions
        .where((session) => session.profileId == profileId && session.completed)
        .toList();
    if (profileSessions.isEmpty) return const [];

    final consistency = WorkoutConsistencyAnalytics.summarize(
      profileSessions,
      profileId: profileId,
      now: reference,
    );
    final weekly = WorkoutSessionAnalytics.weeklySummary(
      profileSessions,
      profileId: profileId,
      now: reference,
    );

    final insights = <WorkoutInsight>[];
    final remainingGoalDays = weeklyGoalDays - consistency.workoutDaysThisWeek;
    if (remainingGoalDays <= 0) {
      insights.add(const WorkoutInsight(
        type: WorkoutInsightType.goal,
        title: 'Weekly goal reached',
        message: 'You reached your workout-day goal for this week.',
        priority: 80,
      ));
    } else if (remainingGoalDays == 1) {
      insights.add(const WorkoutInsight(
        type: WorkoutInsightType.goal,
        title: 'One day to go',
        message: 'One more workout day will complete your weekly goal.',
        priority: 95,
      ));
    } else {
      insights.add(WorkoutInsight(
        type: WorkoutInsightType.goal,
        title: 'Weekly goal progress',
        message: '$remainingGoalDays workout days remain to reach your weekly goal.',
        priority: 55,
      ));
    }

    if (consistency.currentStreakDays >= 3) {
      insights.add(WorkoutInsight(
        type: WorkoutInsightType.recovery,
        title: 'Strong streak',
        message: 'You have trained ${consistency.currentStreakDays} days in a row. Consider a lighter session or recovery day.',
        priority: 100,
      ));
    } else if (consistency.currentStreakDays >= 2) {
      insights.add(WorkoutInsight(
        type: WorkoutInsightType.consistency,
        title: 'Keep the streak going',
        message: 'You are on a ${consistency.currentStreakDays}-day workout streak.',
        priority: 70,
      ));
    }

    profileSessions.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final lastWorkoutDay = _dateOnly(profileSessions.first.endedAt.toLocal());
    final today = _dateOnly(reference);
    final daysInactive = today.difference(lastWorkoutDay).inDays;
    if (daysInactive >= 4) {
      insights.add(WorkoutInsight(
        type: WorkoutInsightType.inactivity,
        title: 'Time to get moving',
        message: 'Your last completed workout was $daysInactive days ago. A short session can restart your rhythm.',
        priority: 110,
      ));
    }

    if (weekly.hasPreviousActivity && weekly.hasActivity) {
      final currentMinutes = weekly.activeDuration.inMinutes;
      final previousMinutes = weekly.previousActiveDuration.inMinutes;
      if (previousMinutes > 0) {
        final change = ((currentMinutes - previousMinutes) / previousMinutes * 100).round();
        if (change.abs() >= 10) {
          insights.add(WorkoutInsight(
            type: WorkoutInsightType.trend,
            title: change > 0 ? 'Training time is up' : 'Training time is down',
            message: change > 0
                ? 'Your active workout time is $change% higher than last week.'
                : 'Your active workout time is ${change.abs()}% lower than last week.',
            priority: 60,
          ));
        }
      }
    }

    insights.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) return priority;
      return a.type.index.compareTo(b.type.index);
    });

    final selected = <WorkoutInsight>[];
    final seenTypes = <WorkoutInsightType>{};
    for (final insight in insights) {
      if (!seenTypes.add(insight.type)) continue;
      selected.add(insight);
      if (selected.length >= maxInsights) break;
    }
    return List.unmodifiable(selected);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
