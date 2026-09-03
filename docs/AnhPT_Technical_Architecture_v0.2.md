# AnhPT Technical Architecture

**Version:** 0.2  
**Status:** Updated to match AnhPT v0.8.2.

## 1. Architecture Summary

AnhPT is a Flutter application with a model/parser layer, execution engine, voice/audio services, local persistence, and presentation screens. YAML is a serialization/import format. The Visual Builder edits a mutable draft model and serializes it back to YAML before validation and persistence.

## 2. Main Components

| Component | Responsibility |
|---|---|
| `Workout`, `WorkoutStep`, `RepeatGroup` | Immutable validated workout model. |
| `WorkoutDraft`, `StepDraft`, `RepeatDraft` | Mutable Builder-side editing model. |
| `WorkoutParser` | Parse/validate YAML and apply defaults including `duration=0s` and `countdown=true`. |
| `WorkoutSerializer` | Serialize Builder draft back to YAML and omit safe defaults for concise output. |
| `ExecutableStep`, `RepeatContext` | Flatten nested workout structure for runtime while retaining innermost repeat context. |
| `SessionEngine` | Own timing, pause/resume, step progression, and timer/announcement completion coordination. |
| `VoiceGuideController` | Build step announcements, repeat-round phrases, guide speech, timing speech, and notify the engine when protected announcement completes. |
| `AudioFeedbackService` | TTS, TTS completion callbacks, cue playback, language-specific phrases. |
| `LocalStore`, `WorkoutYamlFileStore`, `AppController` | Persist workouts/preferences, maintain local YAML files, and coordinate app state. |
| `Exercise` | Reusable movement metadata referenced optionally by a step. |
| `MediaAsset`, `MediaRepository` | Content-addressed shared media and physical-file resolution. |

### Shared exercise demonstration media

Exercise images, animated GIFs, and videos use a device-local, content-addressed Media
Library. `LocalMediaRepository` computes a SHA-256 identity for deduplication,
stores one physical file per unique hash, writes an atomic JSON index, and
resolves both internal IDs and readable relative paths to local URIs. Workout
YAML uses paths such as `media/plank-c0629816.gif`; the full hash remains an
internal integrity key and a backward-compatible reference format.

`WorkoutStep.exerciseId` is optional and points to a root `Exercise`. The
exercise owns reusable `demoMediaId`; step recordings remain contextual audio.
The Player dispatches by MediaAsset type: static image, animated image, or
muted/looped video. Media never becomes a `SessionEngine` completion condition.
Missing media degrades safely to an audio/timer-only workout.

Portable packages list referenced media in `manifest.json`, include available
files under `assets/`, and verify content hashes during import.

### Local workout YAML persistence

On platforms with application Documents storage, every saved workout is also
written atomically to `Documents/AnhPT/workouts/<workout-id>.yaml`. These files
are synchronized on startup and after create, edit, import, replace, or delete
operations. They contain the same portable YAML produced by the Builder,
including step `recording`, `exercise_id`, and exercise `demo_media` references.

The recording and demonstration binaries remain in application-managed shared
storage; YAML contains portable relative paths or content-addressed media IDs,
not absolute device paths. `LocalStore` continues to hold app metadata and a
backward-compatible cached workout representation. Web keeps that cache because
browsers do not expose a normal writable Documents directory.

## 3. Step Completion Model

For each executable step, two independent completion conditions are tracked:

1. `timerFinished`
2. `announcementFinished`

Both start at step activation. The engine may advance only when both are true.

```text
activateStep()
  -> startTimer()
  -> startProtectedAnnouncement()
  -> wait(timerFinished && announcementFinished)
  -> advanceStep()
```

### Important behavior

- If TTS takes longer than the configured duration, the timer reaches zero but the step remains active until TTS completes.
- If TTS finishes first, the engine waits for the timer.
- For `duration: 0s`, timer completion is immediate and only the announcement may remain pending.
- If there is no protected announcement content, announcement completion is immediate.

## 4. Repeat Context

`Workout.expand()` generates `ExecutableStep` instances. `RepeatContext` carries `index`, `total`, and `isFirstStepOfRound`. For nested repeats, runtime voice announcements intentionally use only the innermost repeat context.

## 5. Per-Step Voice Timing

`WorkoutStep.countdown` defaults to `true`. When false, all timing speech is disabled for that step, including continuous, interval, and final countdown speech. Step name, guide, cue sound, and visible timer still operate normally.

## 6. Concurrency / TTS Safety

- Protected step announcements use a completion-aware TTS path.
- A step transition must never interrupt a protected step name/guide announcement.
- Timing voice remains separate from protected step announcement semantics.
- Engine/listener callbacks must avoid re-entrant transitions.
- TTS failure must not deadlock the workout; failure is treated as announcement completion so execution can continue.

## 7. Client-Only Voice Sources and Local Cache Direction

The planned high-quality voice path is client-only. It must not depend on an
AnhPT audio server, shared API key, subscription audio service, server cache, or
shared cache.

For each utterance, the client should use this order:

1. Compute the versioned cache key and check the device-local audio cache.
2. On a cache miss, check whether the user has assigned a locally recorded
   coach-audio file to the selected cue or workout and play that file.
3. If there is no usable recording and the user has supplied their own OpenAI API key on that
   device, request high-quality speech directly from the client and store the
   successful result in the device-local cache.
4. If no user key is available or remote synthesis fails, fall back to the
   platform TTS already available on the device. Voice failure must still not
   stall workout progression.

User-recorded coach audio is local-only. Recording and playback do not require
an API key and recordings are not uploaded by default. YAML v2 stores the
workout-introduction recording in root `recording` and a step cue in that
step's `recording`. Values are scalar safe relative paths; recording language
is not stored. Each step has a globally unique effective ID derived from its
name when omitted. Builder-managed recorded steps receive an explicit stable ID
so reorder operations cannot retarget recordings. Repeat rounds share the
recording of their source step definition. Legacy local assignments are
migrated into YAML. Missing or unreadable recordings fall back without stalling.
Local recording files are named from a simplified cue name, with numeric
suffixes for collisions (`plank.m4a`, `plank-2.m4a`). Startup migration renames
older timestamp/ID-based files and rewrites their relative YAML references.

A recording flow must request microphone permission only when needed and
explain why it is needed. Before assigning a recording, the user must be able
to review its target cue/workout and listen to it. The user must also be able
to replace or delete an assignment and its local file. Destructive replacement
or deletion should be explicit, and permission denial must leave device TTS and
other voice paths usable.

The user's API key is device-local secret material. A future implementation
must store it with platform secure storage, never hard-code it, commit it,
include it in cache metadata, or write it to application logs. Cached audio and
cache indexes remain local to the user's device; no cross-user or cross-device
cache or recording storage is implied.

The cache identity should include normalized text, language, voice profile,
voice, speed, TTS provider/model, and a synthesis/profile version. Changing any
of these inputs produces a different cache entry.

## 8. Offline Background Music

Background music is client-only and uses a dedicated `AudioPlayer`, separate
from cue/coach audio so it never blocks timers or step transitions. YAML v2
`background_music` stores source, optional display name, enabled state, base
volume, and ducking mode (`off`, `gentle`, `medium`, `high`, or `very_high`).
Source is an `asset:` reference or an application-relative path.

The local music library contains immutable bundled entries and personal tracks
copied into application documents after user import. Library metadata and files
remain local, while the selected workout assignment is portable YAML.
Personal files retain a safe form of the browsed filename in `Documents/music`;
numeric suffixes resolve collisions. Generated and package-imported music names
are migrated there and all affected library/YAML references are updated.
Deleting a personal track clears every affected workout assignment before the
file is removed. Missing/unreadable files cause a safe no-music workout.

Music starts at workout start, loops, pauses/resumes with the session, and is
stopped/disposed on completion, early end, or screen disposal. Coach activity
drives a short volume fade: gentle uses about 82% of base volume, medium 60%,
high 40%, very high 20%, and off preserves base volume. Duck/restore calls are
fire-and-forget.

The Workout Detail ducking preview uses separate music and bundled coach-sample
players, but shares the runtime ducking controller and fade curve. It is started
only by a user action (including on Web), responds immediately to live base
volume or ducking-mode changes, and stops both players before workout playback
or when the card is disposed.

## Workout Buckets

`WorkoutBucketService` fetches only public HTTPS catalogs and split workout
artifacts, limits redirects and response sizes, keeps a last-good catalog, and
verifies each artifact's SHA-256 independently. A workout definition is a small
`.workout.yaml` file; audio, video, images, and the package manifest live in a
separate `.assets.zip`. Verified YAML downloads are cached in memory by URL and
checksum. Opening an uninstalled detail page parses this cached definition for a
read-only structure preview, and later installation reuses the bytes before
fetching media. Failed definition downloads are evicted so Retry performs a new
request. Import rejects unsafe, duplicate, overlong, over-count,
and oversized ZIP entries and stages extracted assets before exposing the final
managed directory. Sources and installed provenance use versioned
SharedPreferences records.

On Web, package import does not attempt to access an application Documents
directory. The workout definition is still installed, while package-local audio
and music remain unavailable and follow the existing safe TTS/no-music fallback.

Catalog search/filter/sort is client-side over the cached merged entry list, so
it remains responsive and available offline. Search normalization is
case-insensitive and removes Vietnamese diacritics; a short UI debounce avoids
re-filtering on every keystroke. Source configuration remains separate from the
Home-accessible browsing/install flow.

Dashboard refresh fetches only each enabled source's `bucket.json`. Catalog
entries are rendered directly from metadata and do not enter the persisted
workout list. Visible cards start independent, checksummed thumbnail downloads
after catalog parsing, so catalog retrieval is never blocked by image transfer.
Opening details starts the larger feature-image download. Missing or failed
artwork uses a bundled default selected only from the entry's first tag. The two
install artifact downloads, checksum verification, media
extraction, and workout persistence begin only from the Download action on the
catalog detail screen. Download progress treats completion of the YAML artifact
as an intermediate state and continues to show the subsequent assets transfer;
the UI enters its installation phase only after the assets artifact completes.
Nothing is committed unless both artifacts validate.

Installed-workout provenance is stored internally, independently of editable
workout YAML and display names. The durable identity is the bucket source plus
catalog workout ID; the source display name is captured at install time so it
remains readable if the source is later removed. The original catalog name is
also captured for user-facing rename context. Version, checksum, and package URL
remain internal update/security metadata rather than user-facing identity.
`installCopy` always creates a new local workout ID and its own provenance
record. Multiple provenance records may therefore reference the same source and
catalog workout ID without coupling edits between the local variants. Before a
bucket import enters the local workout list, its trimmed name is compared
case-insensitively and assigned the first available numeric suffix.

At startup, installed-workout provenance whose local workout no longer exists
is removed. Catalog install state also ignores such orphaned records, so a
Dashboard refresh can download the missing workout again.

Completion device actions remain UI/platform concerns and do not enter
`SessionEngine`. When an opted-in workout completes successfully, Windows
invokes `shutdown.exe /s /t 0 /f`; Android uses `SystemNavigator.pop`. Incomplete
sessions, Web, and iOS do not perform a device-exit action.

The optional `screen_off_after_start` duration is scheduled in the Player and
never enters `SessionEngine` state. On Windows, `DeviceActionService` invokes
`WM_SYSCOMMAND` / `SC_MONITORPOWER` through the `win32` package. The timer starts
as the Player opens and is cancelled when the Player is disposed or the session
reaches a terminal state. Unsupported targets leave the setting persisted but
perform no action.

The monitor command targets the current foreground window. It must never use
`HWND_BROADCAST`, because broadcasting a system command also reaches Windows
shell processes and can be misinterpreted as a machine power action on some
systems.

Catalog schema v2 contains `schemaVersion`, bucket `name`, and `workouts` entries
with stable `id`, display metadata, version, and required `workoutUrl`,
`workoutSha256`, `workoutSize`, `assetsUrl`, `assetsSha256`, and `assetsSize`.
Artwork uses `thumbnailUrl`/`thumbnailSha256`/`thumbnailSize` and
`featureImageUrl`/`featureImageSha256`/`featureImageSize`; each group is either
complete or absent.
Catalog discovery metadata also includes derived `durationSeconds`, expanded
`stepCount`, and a structural `stepPreview` generated from workout YAML. Author,
verification, difficulty, intensity, equipment, space, and benefits are curated
manifest fields. `downloadCount` is the only popularity signal currently shown;
the client must not label it as workout completions or infer a rating.
Schema v1 catalogs are rejected. The assets archive contains the manifest and
referenced media, but never workout YAML. Manual portable `.anhpt.zip`
import/export remains a separate local sharing format.
