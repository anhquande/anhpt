# Smart workout insights

Smart workout insights are deterministic, local recommendations derived from existing workout history and the active profile's weekly workout goal. They do not call an AI service and do not persist new workout data.

## Insight types

The first version includes:

- weekly goal progress
- consistency/streak encouragement
- recovery suggestion after a sustained streak
- inactivity prompt after several days without a completed workout
- current-week vs previous-week active-time trend

Only completed sessions for the selected profile contribute to workout activity. Incomplete sessions and other profiles are ignored.

## Priority and limits

Insights have explicit priorities. Inactivity and recovery are prioritized above weekly-goal and trend messages. At most three insights are returned, with deterministic ordering and no duplicate insight type.

The recovery message is a general training suggestion, not a medical recommendation.

## UI

Home shows a compact `Insights` card between Weekly Goal and Consistency when insights are available. The existing `WorkoutSessionHistory.revision` and `WeeklyWorkoutGoalStore.revision` signals refresh the card automatically.

No WorkoutSession schema, persistence, History search/filter/sort, or CSV export behavior is changed.
