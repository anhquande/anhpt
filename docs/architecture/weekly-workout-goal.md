# Weekly workout goal

Weekly workout goals are lightweight profile preferences and do not change the `WorkoutSession` schema.

## Storage

`WeeklyWorkoutGoalStore` persists one integer goal per local profile in SharedPreferences using `anhpt.weeklyWorkoutGoal.<profileId>`. Valid values are 1 through 7. Missing or invalid values fall back to 3 days per week.

## Progress semantics

Progress uses the active profile's distinct completed workout days for the current local Monday-Sunday week. It reuses `WorkoutConsistencyAnalytics`, so multiple completed sessions on the same day count once and incomplete sessions do not count. Displayed progress may exceed the target count (for example 5/3), while the visual progress indicator is capped at 100%.

## UI

Home shows a Weekly goal card alongside the existing weekly feedback and consistency insights. The goal can be edited directly from the card. Saving increments `WeeklyWorkoutGoalStore.revision`, which refreshes the card without mutating workout history.
