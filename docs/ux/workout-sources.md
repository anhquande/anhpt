# Workout Sources

Workout Sources lets users manage public HTTPS workout catalogs.

## Source actions

Each source supports:

- Enable or disable the source.
- Edit the source name and catalog URL.
- Copy the catalog URL to the system clipboard for quick sharing.
- Refresh the source catalog.
- Remove the source without deleting workouts that were already installed.

## Editing a source

Selecting **Edit** opens a dialog prefilled with the current source name and catalog URL.

- The name is required.
- The catalog URL must be a public HTTPS URL.
- Saving a name-only change preserves the existing cached catalog.
- Changing the catalog URL clears cached catalog data and refresh state for that source, then refreshes the source immediately when it is enabled.
- The source ID is preserved, so installed workout provenance remains linked to the edited source.

## Sharing a source

Selecting **Copy URL** copies the catalog URL to the system clipboard and shows a confirmation message. The copied URL can then be pasted into chat, email, or another AnhPT installation.

## Shortcut from workout search

When a workout search returns no matches, the empty-result state shows **Manage workout sources**. Selecting it opens Workout Sources directly so the user can quickly add, enable, edit, refresh, or inspect workout catalogs without navigating through Settings first.
