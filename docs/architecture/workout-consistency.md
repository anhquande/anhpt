# Workout consistency insights

Workout consistency is derived from persisted workout sessions and does not add new storage fields.

## Rules

- Only completed sessions count.
- Analytics are scoped to the active profile.
- Multiple completed sessions on the same local calendar day count as one workout day.
- The current streak continues when the latest workout day is today or yesterday; otherwise it is zero.
- The longest streak is the longest run of consecutive local calendar workout days.
- Weekly and monthly counts represent distinct workout days, not session count.

## UI

Home shows a compact `Consistency` card below the existing weekly workout feedback. It displays current streak, best streak, distinct workout days this week, and distinct workout days this month. The card is recomputed whenever `WorkoutSessionHistory.revision` changes.

The existing Workout History filters, search, custom date range, sorting, CSV export, and progress analytics remain unchanged.
