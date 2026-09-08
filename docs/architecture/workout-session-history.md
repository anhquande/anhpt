# Workout Session History and Progress Feedback

## Purpose

AnhPT needs a real session history before it can give factual progress feedback. `Workout.lastUsedAt` is not workout history: it stores only the most recent use of a workout and cannot answer how many sessions were completed in a week, month, or year.

Issue #68 introduced a small local session history as the source of truth for weekly activity feedback. Issue #75 exposes the same source of truth on Home so progress remains visible after the completion screen is closed. Issue #77 adds a read-only Workout History screen so users can inspect the sessions behind those summaries. Issue #79 adds monthly progress to that same History surface. Issue #83 extends the same analytics layer with yearly totals and month-by-month context.

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

## Monthly calculation

A month uses local calendar boundaries: day 1 at 00:00 through the first day of the next month at 00:00.

Monthly progress uses the same rules as weekly feedback:

- completed workout count;
- sum of active workout duration;
- previous-month count and duration when available;
- incomplete sessions are excluded;
- profile filtering is applied before totals are presented.

The comparison is informational only. AnhPT does not infer targets, streaks, success/failure, or motivational pressure from month-over-month changes.

## Yearly calculation

A year uses local calendar boundaries from January 1 at 00:00 through January 1 of the next year.

Yearly progress is calculated from the same persisted sessions and the same profile filter:

- completed workout count and total active duration for the current year;
- previous-year count and duration only when previous-year activity exists;
- twelve current-year monthly buckets containing completed workout count and active duration;
- incomplete sessions are excluded from yearly totals and monthly buckets.

The month-by-month breakdown is factual context only. Zero-activity months are shown neutrally and do not imply failure or a missed target.

When a profile id is supplied, only that profile's sessions are included. Without a profile filter, analytics can aggregate all local sessions.

## UI surfaces

All UI surfaces consume the same persisted history; none keeps a separate session counter.

### Workout Completed

After persistence finishes, a lightweight `This week` card shows the updated count and active minutes, for example:

> 3 workouts • 47 min

If the previous week has activity, the card can also show factual context such as:

> Last week: 2 workouts • 31 min

### Home

Home shows the same `This week` card above workout search for the active local profile. It reads from `WorkoutSessionHistory`; it does not derive activity from workout cards or `lastUsedAt`.

`WorkoutSessionHistory.revision` is a lightweight change signal only. Persisted session data remains the source of truth. After `record()` saves a session, the revision changes and Home reloads its weekly summary immediately. Changing the active profile rebuilds the Home card with that profile id.

The local history read does not add another loading spinner to Home. While the small local read is pending, the weekly card simply stays hidden.

The Home weekly card is navigable and opens Workout History for the same active profile.

### Workout History

Workout History is a read-only session browser in the first version.

- a monthly progress card appears above session groups;
- a yearly overview card appears below monthly progress;
- the yearly card shows current-year totals, optional previous-year context, and twelve compact monthly buckets;
- sessions are filtered to the selected local profile;
- sessions are sorted by `endedAt`, newest first;
- sessions are grouped by local calendar day;
- each row shows workout name, local completion time, active duration, and completed/total steps;
- incomplete sessions remain visible but are labeled neutrally and are excluded from weekly/monthly/yearly completed-workout totals;
- the screen listens to the same lightweight history revision signal, so newly persisted sessions can appear without restarting the app.

The first version intentionally does not provide edit or delete actions. Those actions would need explicit product rules for history integrity and analytics recalculation.

For zero activity, wording stays neutral and instructional. No streaks, badges, penalties, or pressure language are introduced.

## Future extensions

The session model can support later additions without inferring data from `lastUsedAt`:

- session detail view;
- calorie estimates backed by real profile/session inputs;
- Health/progress integration;
- explicit incomplete-session recording earlier in the player lifecycle;
- history edit/delete rules if the product needs them;
- richer charts if real user feedback shows the compact summaries are insufficient.

If history grows beyond the scale appropriate for `SharedPreferences`, persistence can migrate to a local database while keeping `WorkoutSession` as the domain model.
