# Workout personal bests

Personal bests are derived analytics over persisted workout sessions. They do not add fields to `WorkoutSession` and do not write new history data.

## Scope

`WorkoutPersonalBestsAnalytics` considers completed sessions for the selected local profile and derives:

- longest workout by active duration
- highest completed step count
- highest estimated calories when calories are available
- most-completed workout and its completion count

Incomplete sessions and sessions from other profiles are ignored.

## Tie-breaking

Sessions are evaluated newest first. Equal record values keep the most recent completed session. For most-completed workout ties, the workout whose latest completion is more recent wins. This keeps results deterministic.

## UI

Home shows a compact `Personal bests` card below the existing weekly goal and consistency insights when at least one completed workout exists. Missing calorie data hides the calorie row instead of presenting a misleading zero.

The card is refreshed through the existing `WorkoutSessionHistory.revision` listener. Existing Workout History search, filter, sort and CSV export semantics are unchanged.
