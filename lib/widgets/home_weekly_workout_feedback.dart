import 'package:flutter/material.dart';

import '../screens/workout_history_screen.dart';
import '../services/local_store.dart';
import '../services/workout_session_analytics.dart';
import '../services/workout_session_history.dart';
import 'weekly_workout_feedback.dart';

class HomeWeeklyWorkoutFeedback extends StatelessWidget {
  final LocalStore store;
  final String profileId;

  const HomeWeeklyWorkoutFeedback({
    super.key,
    required this.store,
    required this.profileId,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WorkoutSessionHistory.revision,
      builder: (context, _, __) => FutureBuilder<WeeklyWorkoutSummary>(
        future: WorkoutSessionHistory(store).weeklySummary(
          profileId: profileId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              snapshot.hasError ||
              !snapshot.hasData) {
            // Home already has refresh feedback for catalog loading. Avoid a
            // second progress indicator for this tiny local-data read.
            return const SizedBox.shrink();
          }
          return WeeklyWorkoutFeedbackCard(
            summary: snapshot.data!,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkoutHistoryScreen(
                  store: store,
                  profileId: profileId,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
