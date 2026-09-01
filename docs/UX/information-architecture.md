# Information Architecture

## Goal

Each feature should live where users naturally expect to find it. This document defines screen ownership so AnhPT does not accumulate duplicate navigation paths.

## Primary navigation ownership

### Home / My Workouts

Owns personal workout discovery and frequent workout actions:

- search local workouts,
- quick filters and tags,
- favorites,
- start workout,
- new workout,
- browse downloadable workouts,
- import package/YAML through overflow.

Home is not the place for technical source configuration.

### Browse Workouts

Owns catalog discovery:

- search,
- filter/sort,
- install/update,
- open installed workout.

It should not expose low-level source configuration unless the user explicitly navigates to source management.

### Workout Overview

Owns one workout's summary and pre-start configuration:

- Start,
- description/tags/metadata,
- structure,
- introduction audio,
- music,
- after-workout behavior,
- screen behavior,
- advanced workout actions.

### Visual Builder

Owns workout content editing. YAML remains an advanced alternative, not the default creation path.

### Workout Player

Owns active-session controls only. Avoid pulling configuration-heavy actions into the Player. Session-critical controls such as pause/resume, camera layout, and visibility toggles may remain accessible.

### Profile / Active User

Owns person-specific information:

- active user selection,
- personal profile,
- health profile,
- measurements/history.

Do not duplicate Health or Edit Profile in Settings.

### Settings

Owns app-wide configuration and technical management:

- workout sources,
- music library,
- microphone/platform access guidance,
- camera defaults/preferences,
- other application-level behavior.

Settings should not become a second navigation hub for features already reachable from Home or Profile.

## Navigation rules

- Frequent top-level journeys should require the fewest taps/clicks.
- A feature should have one obvious primary entry point.
- Deep links or secondary shortcuts may exist, but they should not create competing information architectures.
- Back navigation should return to the user's previous context rather than resetting to Home unnecessarily.
- Modal dialogs are for focused tasks, not multi-screen navigation.

## Screen ownership test

Before adding a new feature, ask:

1. Is it about a specific workout, a user, or the whole app?
2. Is it a frequent action or advanced configuration?
3. Is there already another place that owns this responsibility?
4. Would placing it here create duplicate navigation?

If ownership is unclear, document the decision before implementing it.
