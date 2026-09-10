import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/services/workout_insights_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  required String id,
  required String profileId,
  required DateTime endedAt,
  Duration duration = const Duration(minutes: 20),
  bool completed = true,
}) =>
    WorkoutSession(
      id: id,
      workoutId: 'workout-$id',
      workoutName: 'Workout $id',
      profileId: profileId,
      profileName: profileId,
      startedAt: endedAt.subtract(duration),
      endedAt: endedAt,
      activeDuration: duration,
      completedSteps: completed ? 3 : 1,
      totalSteps: 3,
      status: completed
          ? WorkoutSessionStatus.completed
          : WorkoutSessionStatus.incomplete,
    );

void main() {
  test('empty history is safe', () {
    final insights = WorkoutInsightsAnalytics.summarize(
      const [],
      profileId: 'me',
      weeklyGoalDays: 3,
      now: DateTime(2026, 9, 10),
    );
    expect(insights, isEmpty);
  });

  test('one remaining goal day gets high-priority insight', () {
    final now = DateTime(2026, 9, 10, 12);
    final insights = WorkoutInsightsAnalytics.summarize(
      [
        _session(id: 'a', profileId: 'me', endedAt: DateTime(2026, 9, 8, 10)),
        _session(id: 'b', profileId: 'me', endedAt: DateTime(2026, 9, 10, 10)),
      ],
      profileId: 'me',
      weeklyGoalDays: 3,
      now: now,
    );
    expect(insights.any((item) => item.title == 'One day to go'), isTrue);
  });

  test('three-day streak suggests recovery and caps output at three', () {
    final insights = WorkoutInsightsAnalytics.summarize(
      [
        _session(id: 'a', profileId: 'me', endedAt: DateTime(2026, 9, 8, 10)),
        _session(id: 'b', profileId: 'me', endedAt: DateTime(2026, 9, 9, 10)),
        _session(id: 'c', profileId: 'me', endedAt: DateTime(2026, 9, 10, 10)),
      ],
      profileId: 'me',
      weeklyGoalDays: 5,
      now: DateTime(2026, 9, 10, 12),
    );
    expect(insights.first.type, WorkoutInsightType.recovery);
    expect(insights.length, lessThanOrEqualTo(3));
  });

  test('four inactive days outrank lower priority insights', () {
    final insights = WorkoutInsightsAnalytics.summarize(
      [
        _session(id: 'old', profileId: 'me', endedAt: DateTime(2026, 9, 6, 10)),
      ],
      profileId: 'me',
      weeklyGoalDays: 3,
      now: DateTime(2026, 9, 10, 12),
    );
    expect(insights.first.type, WorkoutInsightType.inactivity);
  });

  test('other profiles and incomplete sessions do not affect insights', () {
    final insights = WorkoutInsightsAnalytics.summarize(
      [
        _session(id: 'me', profileId: 'me', endedAt: DateTime(2026, 9, 10, 10)),
        _session(id: 'other', profileId: 'other', endedAt: DateTime(2026, 9, 9, 10)),
        _session(
          id: 'incomplete',
          profileId: 'me',
          endedAt: DateTime(2026, 9, 9, 10),
          completed: false,
        ),
      ],
      profileId: 'me',
      weeklyGoalDays: 2,
      now: DateTime(2026, 9, 10, 12),
    );
    expect(insights.any((item) => item.type == WorkoutInsightType.recovery), isFalse);
    expect(insights.any((item) => item.title == 'One day to go'), isTrue);
  });
}
