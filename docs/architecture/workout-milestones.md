# Workout milestones

Workout milestones are derived analytics over completed workout history. They do not add persisted fields or manual achievement state.

## Milestones

The current milestone set is intentionally small and deterministic:

- First workout
- 5 completed workouts
- 10 completed workouts
- 60 active minutes
- 300 active minutes
- 3-day streak
- 7-day streak

Only completed sessions for the active local profile are considered. Count and duration milestones use completed sessions directly. Streak milestones reuse `WorkoutConsistencyAnalytics`, so multiple workouts on one day do not inflate a streak.

## Progress

Unlocked milestones are shown as compact badges. The next milestone is selected from locked milestones by highest progress ratio, with declaration order as the stable tie-breaker. Visual progress is capped at 100%.

## UI

Home shows an `Achievements` card only after the profile has workout activity. The card shows unlocked count, unlocked badges in a horizontal list, and progress toward the next milestone. It refreshes through the existing `WorkoutSessionHistory.revision` mechanism.

Release-ready source version: 0.29.0. A `feat:` PR therefore publishes the next minor release through the existing release workflow.
