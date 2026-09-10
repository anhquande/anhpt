import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../screens/workout_history_screen.dart';
import '../services/local_store.dart';
import '../services/workout_consistency_analytics.dart';
import '../services/workout_session_analytics.dart';
import '../services/workout_session_history.dart';
import 'weekly_workout_feedback.dart';
import 'workout_consistency_card.dart';

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

  Future<(WeeklyWorkoutSummary, WorkoutConsistencySummary)> _load() async {
    final sessions = await WorkoutSessionHistory(store).load();
    return (
      WorkoutSessionAnalytics.weeklySummary(
        sessions,
        profileId: profileId,
      ),
      WorkoutConsistencyAnalytics.summarize(
        sessions,
        profileId: profileId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WorkoutSessionHistory.revision,
      builder: (context, _, __) =>
          FutureBuilder<(WeeklyWorkoutSummary, WorkoutConsistencySummary)>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              snapshot.hasError ||
              !snapshot.hasData) {
            // Home already has refresh feedback for catalog loading. Avoid a
            // second progress indicator for this tiny local-data read.
            return const SizedBox.shrink();
          }
          final (weekly, consistency) = snapshot.data!;
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
              WorkoutConsistencyCard(summary: consistency),
            ],
          );
        },
      ),
    );
  }
}
