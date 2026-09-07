# First-run onboarding

## Goal

AnhPT onboarding introduces the product experience without creating a fake workout record.

The tutorial communicates four ideas:

1. **Watch** — follow the exercise demonstration.
2. **Listen** — use Voice Coach guidance without watching the screen constantly.
3. **Compare** — use Mirror Mode to compare the live camera with the demonstration.
4. **Train** — continue into the real AnhPT Feature Demo workout.

## Product boundary

The onboarding tutorial is application UI, not a workout.

It must not:
- appear in the Workouts list;
- appear in Recents or workout History;
- add calories, workout counts, duration, or Health statistics.

The existing **AnhPT Feature Demo** remains a normal workout. Starting it from onboarding uses the same workout detail/player flow as starting it from Home.

## First run

Fresh installations show onboarding before Home.

Users can:
- move through the four onboarding pages;
- skip the tutorial;
- finish without starting the demo;
- start the Demo Workout from the final page.

Completion or skip is persisted.

## Existing installations

Older Alpha installations may not have the onboarding preference key. If existing AnhPT application data is detected, the installation is migrated as already onboarded so an update does not unexpectedly interrupt the user with first-run UI.

## Replay

Settings exposes **Replay AnhPT tutorial**. Replaying does not modify workout history. The final page can return to Home and launch the real Demo Workout.
