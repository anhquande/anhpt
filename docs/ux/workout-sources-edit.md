# Edit Workout Source

The Workout Sources screen provides an **Edit** action for each configured source.

The edit dialog allows changing:

- Source name
- Catalog URL

Validation requires a non-empty name and a public HTTPS catalog URL.

When only the name changes, the cached catalog remains valid. When the URL changes, the previous cached catalog, refresh timestamp, and previous source error are cleared. If the source is enabled, the app immediately refreshes the source from the new URL.

The source ID is preserved so workouts already installed from that source remain associated with the source after editing.
