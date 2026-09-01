# Interaction Patterns

## Actions

Use visible actions for frequent tasks and overflow menus for infrequent or advanced tasks. Avoid duplicate actions on the same screen.

Primary actions use clear verbs such as `Start`, `Install`, `Save`, or `Resume`. Destructive actions such as Delete should be visually separated from normal actions and require confirmation when data loss is possible.

## Icon buttons

Icon-only buttons are appropriate for compact secondary actions when the icon is widely recognizable. They require semantic labels and tooltips. Avoid ambiguous icons where a more specific alternative exists.

Examples:

- microphone for recording,
- media/add-photo icon for demonstration media,
- favorite/star for favorites,
- drag handle only where dragging actually works.

Do not place drag handles next to toggles or destructive actions where accidental activation becomes likely.

## Lists and cards

Cards should communicate hierarchy rather than become containers for every action. Keep title and primary state prominent; metadata should remain visually quiet.

For large record sets such as health measurements, prefer aligned table-like rows instead of independent cards.

## Forms

Validation appears near the affected field and must preserve user-entered values. Required fields should be identifiable before submission.

On Android, forms must remain usable when the software keyboard is open. On Windows, support keyboard focus and tab navigation.

## Dialogs

Dialogs should perform one focused task. Avoid embedding full settings experiences in a modal.

A dialog should normally contain:

- a clear title,
- concise supporting text only when necessary,
- content or form controls,
- one clear primary action,
- Cancel/Close,
- destructive action separated when relevant.

Closing a media or recording dialog must stop temporary playback/recording owned by that dialog.

## Reordering

Use one clear drag handle, preferably at the left edge of the row/card. If drag-and-drop is not available on a platform, provide an accessible alternative such as move up/down controls.

Reordering must preserve identity and associated data such as step IDs and recordings.

## Toggles

Use toggles only for binary persistent settings. The label should describe the state being enabled, not the action of tapping the switch.

Avoid placing unrelated action icons immediately adjacent to toggles.

## Search, filters, and sorting

Search should update predictably and preserve current filters. Filters and sorting should not reset the user's query without explicit intent.

Quick filters are for frequent choices; full management belongs in a separate focused surface.

## Media previews

Use compact thumbnails in lists/builders and larger previews only after explicit user interaction. Missing media should render a fallback rather than collapsing the layout.

Video must preserve aspect ratio and should not be stretched.

## Audio previews

Use one consistent preview pattern with Play/Pause, Stop where relevant, elapsed/total time, and seeking when duration is known. Starting a new preview should stop the previous one to avoid overlapping audio.
