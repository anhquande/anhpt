# Workout Completion Summary

## Purpose

Completing a workout is a transition from active training back to the rest of AnhPT. The completion experience should provide a calm sense of accomplishment and summarize only information the app can support with real session data.

## Completed workout flow

A normally completed workout leaves the live Player and opens a dedicated completion screen. Replacing the Player releases camera, media, timer, music and Voice Coach resources before the user reviews the result.

The summary shows:

- workout name;
- active workout time;
- resolved runtime steps completed and total steps;
- completion percentage;
- active profile name when available.

The primary action is `Done`.

## Optional metrics

Metrics must only be shown when backed by persisted or computed data.

- Estimated calories may be shown as `~X kcal` with the label `Estimated calories` only when a real estimate is supplied.
- Weekly/progress context may be shown only when workout-session history exists and can support the statement.
- `View progress` is shown only when there is a meaningful progress destination.

The completion screen must not invent calorie estimates or weekly workout counts just to fill space.

## Incomplete workouts

Ending a workout early remains a separate incomplete state. It does not use celebratory completion wording.

## Layout

- Keep the page calm and lightweight; no confetti animation or aggressive gamification.
- Use a centered maximum content width on large displays.
- Allow the content to scroll on small phones.
- Metric cards wrap from two columns to one column when width is constrained.
- `Done` remains an obvious primary action.

## Future integration

When AnhPT persists workout-session health summaries, the existing optional completion fields can receive estimated calories and weekly progress context without changing the core completion layout.
