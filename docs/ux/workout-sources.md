# Workout Sources

Workout Sources lets users manage public HTTPS workout catalogs.

## Source actions

Each source supports:

- Enable or disable the source.
- Edit the source name and catalog URL.
- Refresh the source catalog.
- Remove the source without deleting workouts that were already installed.

## Editing a source

Selecting **Edit** opens a dialog prefilled with the current source name and catalog URL.

- The name is required.
- The catalog URL must be a public HTTPS URL.
- Saving a name-only change preserves the existing cached catalog.
- Changing the catalog URL clears cached catalog data and refresh state for that source, then refreshes the source immediately when it is enabled.
- The source ID is preserved, so installed workout provenance remains linked to the edited source.
