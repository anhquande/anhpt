# Workout Session History and Progress Feedback

## Purpose

AnhPT needs a real session history before it can give factual progress feedback. `Workout.lastUsedAt` is not workout history: it stores only the most recent use of a workout and cannot answer how many sessions were completed in a week, month, or year.

Issue #68 introduced a small local session history as the source of truth for weekly activity feedback. Issue #75 exposes the same source of truth on Home. Issue #77 adds Workout History, #79 and #83 add monthly/yearly context, #86 adds Session Details, #88 adds Repeat workout, #95 adds lightweight History filters, #97 makes the workout player lifecycle the owner of terminal session persistence, and #99 adds search and sorting as the list grows.

## Stored session

Each `WorkoutSession` stores a snapshot of:

- session id;
- workout id and workout name;
- optional local profile id and profile name;
- start and end timestamp;
- active workout duration;
- completed and total resolved steps;
- status: `completed` or `incomplete`.

The v1 persistence key is `anhpt.workoutSessions.v1` in `SharedPreferences`. Filtering, searching and sorting never write to this store.

## Player lifecycle persistence

`WorkoutPlayerScreen` owns terminal session persistence because it is the surface that knows the exact running workout, profile context and terminal state.

- a normal terminal `completed` state records one completed session;
- an explicit early end records one `incomplete` session;
- the installed `workoutId` is used directly instead of resolving a workout again from its display name;
- the player start timestamp and terminal timestamp are stored separately from active workout duration;
- the recorder is exactly-once, so repeated terminal listener notifications cannot duplicate a session;
- terminal persistence is awaited before completion navigation or `shutdown_or_exit` device actions;
- persistence failure is logged but does not turn a completed workout into a failed-workout UX.

`WorkoutCompletionScreen` is presentation-only. It may read the already-persisted history to show weekly feedback, but it does not create or mutate sessions.

## Progress calculations

Weekly, monthly and yearly summaries count only completed sessions and use local calendar boundaries. Profile filtering is applied before totals are presented. Monthly/yearly comparisons are informational only; AnhPT does not infer targets, streaks, success/failure, or motivational pressure.

## UI surfaces

All UI surfaces consume the same persisted history; none keeps a separate session counter.

### Workout Completed

After player persistence, a lightweight `This week` card reads the updated count and active minutes. Opening this screen does not write another session.

### Home

Home shows the same `This week` card for the active local profile. `WorkoutSessionHistory.revision` is a notification signal only; persisted sessions remain the source of truth. The local read does not add another loading spinner to Home. The weekly card opens Workout History for the same profile.

### Workout History

Workout History is a read-only session browser.

- monthly and yearly progress cards remain based on the full selected-profile history;
- each row opens Session Details;
- incomplete sessions remain visible but are excluded from completed-workout totals;
- filters can narrow visible rows by status (`All`, `Completed`, `Incomplete`), local period (`This week`, `This month`, `This year`, `All time`) and persisted workout id;
- search matches the stored workout-name snapshot case-insensitively;
- sort options are `Newest first`, `Oldest first`, `Longest duration` and `Shortest duration`;
- search, sort and all existing filters operate only on the already-loaded selected-profile sessions and never reload or mutate persistence;
- a matching-session count reflects the final searched/filtered result set;
- `Clear filters` clears search and restores all filter defaults plus `Newest first`;
- a zero-result state keeps all controls visible so the user can recover immediately;
- changing search, sort or filters keeps the History list mounted so scroll position is not reset by a storage reload.

Period boundaries are local-time calendar boundaries: Monday-to-Monday for week, first-day-to-first-day for month, and January-1-to-January-1 for year.

### Session Details

Session Details receives an existing `WorkoutSession` and shows only persisted values: workout name, local date/times, active duration, steps, completion status, derived progress percentage, and optional profile name. Incomplete wording stays neutral and zero-total-step sessions safely show 0%.

When the historical `workoutId` still resolves to an installed workout, `Repeat workout` opens the existing `WorkoutPlayerScreen` with the recorded profile context. It does not clone or mutate the historical session. If the workout was removed, the history snapshot stays readable and the action is hidden.

## Future extensions

Possible later extensions include custom date ranges, calorie/Health metrics backed by real stored inputs, session notes, history edit/delete rules, CSV export, and richer charts if user feedback justifies them.

If history grows beyond the scale appropriate for `SharedPreferences`, persistence can migrate to a local database while keeping `WorkoutSession` as the domain model.
