# Workout History Note Search

Workout History uses one in-memory search query for both persisted workout-name snapshots and optional session notes.

## Matching

A non-empty query is trimmed and matched case-insensitively. A session matches when either `workoutName` or `note` contains the query as a substring. Sessions without notes remain valid and simply cannot match through the note field.

## Composition

Note search composes with the existing active-profile scope, status filter, period/custom date range, workout filter and sort order. No session persistence is reloaded or mutated when the query changes.

Because CSV export consumes the same filtered session list as the History UI, note-search results are reflected automatically in exported CSV rows.
