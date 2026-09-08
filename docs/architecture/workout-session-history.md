# Workout Session History and Weekly Feedback

## Purpose

AnhPT needs a real session history before it can give factual progress feedback. `Workout.lastUsedAt` is not workout history: it stores only the most recent use of a workout and cannot answer how many sessions were completed in a week.

Issue #68 introduces a small local session history as the source of truth for weekly activity feedback.

## Stored session

Each `WorkoutSession` stores a snapshot of:

- session id;
- workout id and workout name;
- optional local profile id and profile name;
- start and end timestamp;
- active workout duration;
- completed and total resolved steps;
- status: `completed` or `incomplete`.

The v1 persistence key is `anhpt.workoutSessions.v1` in `SharedPreferences`.

The store is tolerant of one malformed record: valid sessions remain available instead of losing the whole history.

## Completion recording

The current MVP records a session when the normal Workout Completed screen is opened. It attempts to associate the active local profile automatically; Health measurements or Health profile configuration are not required.

The workout name is stored as a snapshot so history remains readable if a workout is renamed or removed. The current workout id is resolved from local workouts when possible.

Session persistence failure must never turn a successfully completed workout into an error state.

## Weekly calculation

A week runs from Monday 00:00 local time through the following Monday 00:00.

Weekly feedback counts only sessions whose status is `completed`:

- completed workout count;
- sum of active workout duration;
- previous-week count and duration when available.

Incomplete sessions are deliberately excluded from weekly totals.

When a profile id is supplied, only that profile's sessions are included. Without a profile filter, analytics can aggregate all local sessions.

## UX

The first UI surface is Workout Completed. After persistence finishes, a lightweight `This week` card shows the updated count and active minutes, for example:

> 3 workouts • 47 min

If the previous week has activity, the card can also show factual context such as:

> Last week: 2 workouts • 31 min

For zero activity, wording stays neutral and instructional. No streaks, badges, penalties, or pressure language are introduced.

## Future extensions

The session model is intended to support later additions without inferring data from `lastUsedAt`:

- Home/dashboard weekly summary;
- workout history screen;
- calorie estimates backed by real profile/session inputs;
- monthly and yearly activity analytics;
- Health/progress integration;
- explicit incomplete-session history if the product needs it.

If history grows beyond the scale appropriate for `SharedPreferences`, persistence can migrate to a local database while keeping `WorkoutSession` as the domain model.
