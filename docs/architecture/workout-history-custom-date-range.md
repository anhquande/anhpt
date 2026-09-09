# Workout History Custom Date Range

Issue: #105

Workout History supports a `Custom range` period alongside the existing all-time, week, month and year presets.

## Semantics

- The selected start and end dates are inclusive local calendar dates.
- Filtering uses `WorkoutSession.endedAt`.
- A selected range is normalized to local midnight at the start date and local midnight immediately after the end date.
- Custom range filtering composes with status, workout, search and sort filters.
- Filtering remains in memory after history is loaded; changing dates does not reload or mutate persistence.
- Weekly, monthly and yearly progress cards continue to use the full active-profile history and are not constrained by the custom range.

## UI behavior

- Selecting `Custom range` opens a Material date-range picker.
- Cancelling the picker leaves the current period filter unchanged.
- After selection, the chosen dates are shown below the filter row and can be edited.
- `Clear filters` removes the custom dates and restores `All time`.

## Persistence

The custom range is transient UI state and is not stored between app launches.
