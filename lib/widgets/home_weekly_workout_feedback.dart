import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../screens/workout_history_screen.dart';
import '../services/local_store.dart';
import '../services/weekly_workout_goal.dart';
import '../services/workout_consistency_analytics.dart';
import '../services/workout_milestone_analytics.dart';
import '../services/workout_personal_bests_analytics.dart';
import '../services/workout_session_analytics.dart';
import '../services/workout_session_history.dart';
import 'weekly_workout_feedback.dart';
import 'weekly_workout_goal_card.dart';
import 'workout_consistency_card.dart';
import 'workout_milestones_card.dart';
import 'workout_personal_bests_card.dart';

class HomeWeeklyWorkoutFeedback extends StatelessWidget {
  final LocalStore store;
  final String profileId;
  final AppController? controller;

  const HomeWeeklyWorkoutFeedback({
    super.key,
    required this.store,
    required this.profileId,
    this.controller,
  });

  Future<(
    WeeklyWorkoutSummary,
    WorkoutConsistencySummary,
    WorkoutPersonalBestsSummary,
    WorkoutMilestoneSummary,
    int
  )> _load() async {
    final sessions = await WorkoutSessionHistory(store).load();
    final goal = await const WeeklyWorkoutGoalStore().load(profileId);
    return (
      WorkoutSessionAnalytics.weeklySummary(
        sessions,
        profileId: profileId,
      ),
      WorkoutConsistencyAnalytics.summarize(
        sessions,
        profileId: profileId,
      ),
      WorkoutPersonalBestsAnalytics.summarize(
        sessions,
        profileId: profileId,
      ),
      WorkoutMilestoneAnalytics.summarize(
        sessions,
        profileId: profileId,
      ),
      goal,
    );
  }

  Future<void> _editGoal(BuildContext context, int currentGoal) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        var value = currentGoal;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Weekly workout goal'),
            content: DropdownButtonFormField<int>(
              key: const Key('weekly-workout-goal-picker'),
              initialValue: value,
              decoration: const InputDecoration(
                labelText: 'Workout days per week',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var day = 1; day <= 7; day++)
                  DropdownMenuItem(
                    value: day,
                    child: Text('$day ${day == 1 ? 'day' : 'days'}'),
                  ),
              ],
              onChanged: (next) {
                if (next != null) setState(() => value = next);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('weekly-workout-goal-save'),
                onPressed: () => Navigator.pop(context, value),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == currentGoal) return;
    await const WeeklyWorkoutGoalStore().save(profileId, selected);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WorkoutSessionHistory.revision,
      builder: (context, _, __) => ValueListenableBuilder<int>(
        valueListenable: WeeklyWorkoutGoalStore.revision,
        builder: (context, _, __) => FutureBuilder<(
          WeeklyWorkoutSummary,
          WorkoutConsistencySummary,
          WorkoutPersonalBestsSummary,
          WorkoutMilestoneSummary,
          int
        )>(
          future: _load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.hasError ||
                !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final (weekly, consistency, personalBests, milestones, goal) =
                snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WeeklyWorkoutFeedbackCard(
                  summary: weekly,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutHistoryScreen(
                        store: store,
                        profileId: profileId,
                        controller: controller,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                WeeklyWorkoutGoalCard(
                  completedDays: consistency.workoutDaysThisWeek,
                  goalDays: goal,
                  onEdit: () => _editGoal(context, goal),
                ),
                const SizedBox(height: 12),
                WorkoutConsistencyCard(summary: consistency),
                if (personalBests.hasRecords) ...[
                  const SizedBox(height: 12),
                  WorkoutPersonalBestsCard(summary: personalBests),
                ],
                if (milestones.hasActivity) ...[
                  const SizedBox(height: 12),
                  WorkoutMilestonesCard(summary: milestones),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
