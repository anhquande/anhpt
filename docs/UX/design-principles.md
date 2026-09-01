# UX Design Principles

## 1. Design for movement

AnhPT is often used while the user is exercising and not looking continuously at the screen. Interfaces must therefore favor large, stable, immediately understandable controls over dense configuration.

Primary workout actions should be visible without opening menus. Secondary and advanced actions can move to overflow menus.

## 2. Stable beats dynamic

Avoid layouts that jump when step content changes. During playback, preserve the same major visual regions across steps even when optional media is missing.

Do not restart session-scoped resources such as camera simply because a step changes.

## 3. One action, one place

Do not duplicate the same action in the app bar, body, floating action button, and overflow menu. Choose the location based on frequency and importance.

Examples:

- `Start` belongs visibly in Workout Overview.
- `New workout` and `Browse workouts` belong visibly on Home.
- YAML editing belongs in advanced actions.
- Health editing belongs to Profile/Health, not duplicated in Settings.

## 4. Progressive disclosure

Keep the main experience simple. Show advanced detail only when the user asks for it.

Examples include recording management, source metadata, YAML editing, media replacement, and technical settings.

## 5. Graceful degradation

Optional subsystems must fail locally. A missing demonstration, camera failure, unavailable music file, failed TTS, or bucket refresh error must not break the rest of the workout.

Prefer a fallback state over removing layout regions.

## 6. Protect user data

Destructive operations require clear intent. Preserve local workouts, provenance, health measurements, recordings, and user selections whenever a recoverable subsystem fails.

## 7. Consistency across Windows and Android

The same feature should have the same meaning and information hierarchy on both platforms. Interaction details may adapt to mouse/keyboard versus touch.

## 8. Prefer clarity over cleverness

Icons must be understandable. Ambiguous controls such as generic ellipsis buttons should not be used where a more specific icon communicates purpose better.

Tooltips and semantic labels are required for compact icon-only actions.

## 9. Visual hierarchy

Use emphasis in this order:

1. Current workout/session state.
2. Primary action.
3. Current step/content.
4. Supporting metadata.
5. Advanced or destructive actions.

Technical metadata must not visually compete with the workout itself.

## 10. UX decisions are product decisions

If implementation requires changing an established interaction described in the canonical UX/UI specification, update documentation as part of the same PR rather than allowing the code and UX specification to diverge.
