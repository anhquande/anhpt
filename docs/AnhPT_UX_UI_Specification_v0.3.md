# AnhPT UX/UI Specification

**Version:** 0.3  
**Status:** UX baseline for current AnhPT screens and future UI changes.  
**Supersedes:** v0.2 while preserving its established decisions.

## 1. Product-wide UX principles

AnhPT is a workout application intended to remain usable while the user is moving, listening to guidance, and often standing away from the device. The UI therefore prioritizes clarity, large primary actions, stable layouts, and low interaction cost over information density.

- Frequent actions stay visible; infrequent and advanced actions move to contextual overflow menus.
- Avoid duplicate actions on the same screen.
- Prefer recognizable icons plus tooltips for compact secondary actions.
- Destructive actions are visually separated and require confirmation when data would be lost.
- Empty, loading, offline, error, disabled, and success states must be explicit.
- Windows and Android should use the same information architecture while adapting interaction details to pointer/keyboard versus touch.
- Responsive layouts may reflow or stack controls, but must not remove capabilities.
- Existing user data and workout playback must remain usable when optional media, camera, audio, or network resources fail.

## 2. Home / My Workouts

### Purpose

Home is the user's workout library and the fastest route to starting, finding, creating, or downloading a workout.

### Layout

Use a restrained `My Workouts` app bar. Settings remains the only global app-bar action. Do not add a greeting or redundant floating creation button.

The frequent actions `New workout` and `Browse workouts` remain directly visible. Less frequent `Import package` and `Import YAML` actions live in an adjacent overflow menu.

A local accent-insensitive search filters workout name, description, and tags.

Workouts are presented in counted lightweight sections. Favorites are separated from other workouts when useful. Cards prioritize:

1. workout title,
2. optional one-line description,
3. compact metadata,
4. provenance where relevant,
5. favorite control,
6. clear Play action.

Bucket-installed workouts show `From <source>`. Locally created workouts omit provenance. Renamed bucket workouts may additionally show `Originally “<name>”`.

### Quick filters and tags

Quick filters should remain a compact horizontal tool rather than becoming a second navigation bar. When many tags exist, only the configured quick tags are shown.

Tag ordering is user-manageable. The entry to `Manage Tags` belongs at the end of the Quick Filter bar and should use a recognizable filter/settings-style icon rather than an ambiguous generic three-dot button.

Inside Manage Tags, use one drag handle on the left side of each row. Do not place a second drag handle near the enable/disable toggle.

### Sorting

Sorting may include common library criteria such as name and download popularity where download statistics are available. `Top downloads` should be discoverable without overwhelming the normal personal-library view.

## 3. Browse Workouts / Catalog

`Browse Workouts` is a discovery surface, not a technical source-management screen.

Keep the search field pinned below the app bar. Search name, description, tags, author, and source with case- and Vietnamese-accent-insensitive matching after a short debounce.

Provide compact status/source filters, sorting, result count, direct Install/Update states, and Open after successful installation.

Use the Home visual system: standard app bar, same inset search field, counted section header, compact filter/sort icon menus, lightweight cards, one-line descriptions, muted metadata, and tonal actions. Tags are inline secondary metadata rather than large chips.

## 4. Workout Overview / Detail

Use one persistent top app bar. It contains the ellipsized workout title and an adjacent overflow menu. On wide layouts the primary `Start` action also appears in the app bar. On narrow/mobile layouts, `Start workout` remains in a persistent bottom action area for comfortable one-handed access.

The overflow menu contains Edit, Duplicate, Copy YAML, Edit YAML, and Export package. Do not repeat these actions in the scrolling content. `Delete workout` is separated as destructive and requires confirmation.

The Overview leads with feature artwork, source attribution when applicable, the workout name, and a compact description. Lightweight duration, effective-step-count, language, and voice-mode metadata follow the artwork. Tags remain visually secondary.

Use `Overview`, `Exercises · N`, and `Audio` tabs, with Overview selected initially. Overview provides a three-step execution preview and workout-level options; `View all N` opens Exercises. Exercises contains the complete nested step/repeat structure. Audio owns background-music controls. Preserve each tab's scroll position and disable horizontal swipe between tabs to avoid slider conflicts.

On wide layouts, the preview and workout options may share two columns. On narrow layouts they stack vertically. `After workout` and `Screen during workout` remain directly available but must not visually compete with the workout summary or preview.

Zero-duration steps in the Overview preview use the label `Instruction` instead of presenting an unexplained blank duration. Source origin is concise in the hero; original catalog name, stable catalog ID, and installed version remain available through `View source`.

Description collapses after three lines with More/Less. Tags are compact secondary chips. Duration, step count, language, and voice mode use lightweight icon/text metadata rather than chips.

## 5. Visual Workout Builder

The Visual Workout Builder is the default creation/editing experience. YAML remains an advanced editing and import/export mechanism.

### Step card

Each step supports name, duration, guide, voice timing, reorder, duplicate, delete, coach recording, and demonstration media.

The step name is the primary visual cue. Do not show a redundant leading timer icon when duration is already visible.

Recording and demonstration actions stay together in the right-side action area. When media is assigned, replace the empty Browse icon with a compact rounded thumbnail in the same position rather than adding a large preview below the step.

Use a single left-side drag/reorder affordance where drag-and-drop is available. Avoid placing drag controls adjacent to toggles or destructive controls.

### Repeat card

Repeat cards expose repeat count, Add Step, Add Repeat, reorder, duplicate, and delete. Nested repeats are supported, but hierarchy must remain visually obvious through indentation/grouping rather than excessive decoration.

### After-workout controls

`Shut down or exit when complete` belongs in an always-visible `After workout` card, not Voice settings. Forced Windows shutdown requires clear warning copy. Overview and Builder must stay synchronized through the workout model/YAML.

`Screen during workout` is also visible in both Overview and Builder. Enabling it writes the supported screen-off configuration; copy must state when behavior is Windows-only.

## 6. Workout Player

### Primary goal

The Player is the most focus-sensitive screen. During exercise, users should understand the current movement, remaining time, coach guidance, demonstration, camera view, and the next action without navigating menus.

### Stable session state

Core player controls and visual regions should not jump or disappear between steps. Step transitions must preserve layout geometry as much as possible.

The camera is session-scoped rather than step-scoped. Once enabled, keep the camera stream alive across step changes until the user explicitly disables it, leaves the workout, or the workout ends. Do not recreate the camera merely because the current step changes.

### Demonstration and camera layouts

Support the established layout choices, including:

- demonstration as the main view with camera as Picture-in-Picture,
- camera as the main view with demonstration as Picture-in-Picture,
- comparison-oriented layout where both are presented prominently.

Camera preview must preserve a sensible source aspect ratio such as 4:3 or 16:9. Never stretch the image to fill an arbitrary box; crop/letterbox appropriately while preserving proportions.

Use the same player layout for steps with and without demonstration media. If a step has no demonstration, render a neutral default/fallback visual in the demonstration region instead of removing that region and causing the interface to reflow.

Static images remain visible, GIFs animate, and videos loop muted. Demonstration video pauses/resumes with the session. Missing or unsupported demonstration media is non-blocking.

### Player states

| State | UX expectation |
|---|---|
| Start countdown | `READY` plus a prominent countdown. |
| Running | Current step, remaining time, progress, next step, and Pause. |
| Guide finishing after timer | Keep `00:00` and show a waiting state such as `FINISHING GUIDE`. |
| Paused | Clear `PAUSED` state and Resume action; media/camera layout remains stable. |
| Completed | Completion summary and safe exit path. |

Timer and protected announcement begin together. Advance only when both timer and protected announcement have completed. The visible timer remains authoritative for configured duration.

## 7. Health Dashboard

Health is part of the active user's profile rather than a separate global Settings category.

The dashboard should emphasize the current measurement and trends without duplicating entry points. `Current Weight` provides the primary logging action; do not also show a redundant floating Add Weight button.

Use an understandable measurement/log icon instead of an ambiguous text-only `Log` treatment where possible, with tooltip/label where needed for accessibility.

For measurement history, prefer a compact table-like presentation as the number of records grows. The table should resemble a readable lightweight spreadsheet: aligned date/time and value columns, consistent row height, clear sorting where supported, and responsive horizontal handling on narrow devices.

The Add/Edit Weight dialog supports both date/time picker interaction and direct text editing of the timestamp. Validation feedback should be local and should not discard entered values.

## 8. User Profile / Active User

Profile is the home for person-specific information, including health profile data. Avoid a second `Edit profile` entry inside Health.

Workout startup uses the current Active User automatically. Do not ask `Who is working out?` every time when an active user is already defined.

Switching the active user must be explicit and clearly indicate which user's health measurements and workout history are being displayed or recorded.

## 9. Settings

Settings contains application-level configuration, not content-discovery actions or duplicate profile navigation.

Examples of appropriate Settings destinations include Workout Sources, Music Library, microphone/platform access guidance, camera preferences, and other app-wide behavior.

Do not expose a redundant Health menu when Health is reachable through Profile. Do not put `Browse workouts` in Settings; discovery belongs on Home.

Group settings by user intent rather than technical subsystem. Prefer concise rows that open focused screens over long pages of switches.

## 10. Workout Sources / Buckets

Workout Sources is a technical management surface. Users can add a source by name and public HTTPS catalog URL, enable/disable it, refresh it, or remove it without deleting already installed workouts.

Network and validation states must be explicit: loading, cached/offline, empty catalog, invalid catalog, download failure, and checksum failure must never silently replace or delete existing local workouts.

Catalog installation/update behavior should preserve provenance and allow independent local variants. Renaming a local variant must not alter source identity.

## 11. Recording and audio controls

Use one consistent compact audio-player pattern for workout introduction recordings, step recordings, and previews: Play/Pause, Stop where needed, elapsed/total duration, and seek when duration is known.

Assigned step recordings use a compact Play/Pause control. Hover on pointer devices may reveal `Manage recording`; touch interaction must expose the same capability without requiring hover.

Recording surfaces show live amplitude, elapsed time, and `REC` only after capture has actually started. Permission explanations belong in Settings rather than permanently occupying recording dialogs.

Missing recordings or playback failures fall back to device TTS where applicable and must not block workout playback.

## 12. Music Library and workout music

Music Library supports mood filtering, preview, personal-track import, rename/mood editing, and deletion. Bundled tracks cannot be deleted.

Workout Detail uses a compact Background Music card with selection, enable toggle, preview, base volume, and ducking controls. Missing music must produce feedback but must not prevent workout start.

Sliders need sufficient width on touch and pointer devices. Related controls may use two columns on wide layouts and stack vertically on narrow layouts.

## 13. Dialogs and common interaction patterns

Dialogs should have one clear purpose. Avoid placing full settings screens inside modal dialogs.

- Primary action appears consistently and is clearly distinguishable from Cancel/Close.
- Destructive actions are separated from normal actions.
- Closing a dialog must stop temporary preview/recording playback owned by that dialog.
- Long forms should remain usable with the software keyboard open on Android.
- Validation appears near the invalid field and preserves entered data.
- Progress operations that can take noticeable time show progress and prevent accidental duplicate submission.

## 14. Loading, empty, error, and offline states

Every data-driven screen must intentionally define these states rather than showing an unexplained blank area.

An empty state should explain what is empty and expose the most relevant next action. Errors should say what failed and whether Retry is meaningful. Offline behavior should distinguish unavailable network content from already cached/local content.

Optional feature failure (camera, demonstration media, music, recording, TTS, bucket refresh) should degrade locally rather than taking down the entire workout experience.

## 15. Windows and Android responsive behavior

### Windows

- Support mouse hover, tooltips, keyboard focus, and comfortable desktop widths.
- Do not stretch content indefinitely across a wide window; use sensible maximum content widths where appropriate.
- Pointer-only affordances must have keyboard equivalents.
- Camera preview preserves source aspect ratio.

### Android

- Touch targets should be approximately 48 logical pixels where practical even when the visible icon/thumbnail is smaller.
- Do not rely on hover for essential functionality.
- Respect safe areas and software keyboard insets.
- Player controls should remain reachable one-handed where practical, but camera/demonstration content receives maximum useful space.

The information architecture and feature availability should remain recognizable across both platforms.

## 16. Accessibility

- Icon-only actions require semantic labels/tooltips.
- Do not communicate important state using color alone.
- Maintain readable contrast for text, disabled controls, metadata, and overlays on video/camera content.
- Dynamic workout states such as Paused, countdown, and completion should be understandable visually even when audio is unavailable.
- Text scaling should not clip primary actions or essential player information.

## 17. UX change checklist for future PRs

Before merging a UI change, verify:

- Is the action placed according to frequency and user intent?
- Does it duplicate an existing action?
- Does the screen remain stable when optional content is missing?
- Are loading, empty, disabled, error, and success states covered?
- Does the feature work with touch and pointer/keyboard interaction?
- Does Android reflow without clipping?
- Does Windows avoid stretched media or excessively wide content?
- Are destructive operations confirmed where necessary?
- Are icon-only controls understandable and accessible?
- Does the change preserve Active User, workout data, source provenance, and other persisted state?
- Does the Player avoid restarting session-scoped resources such as camera between steps?

This checklist should be used during implementation and PR review so UX decisions remain consistent as AnhPT grows.
