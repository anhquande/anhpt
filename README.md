# AnhPT 0.8.2

AnhPT is a Flutter voice-guided personal workout trainer with structured YAML workouts, local coach recordings, background music, demonstration media, downloadable workout buckets, local health profiles, and automated Android releases.

## Voice behavior

- Announces workout start and optional description.
- Announces each step name and guide.
- Uses a local coach recording when available and falls back to TTS.
- Supports independent elapsed-time announcements.
- Supports independent periodic remaining-time announcements.
- Supports an independent final countdown.
- Announces Pause / Resume.
- Announces workout completion.
- Cancels obsolete speech when session state changes.

Current voice timing is configured with independent YAML flags under `voice.timing`; there is no combined timing mode.

## Sound

- beep / bell / click / none
- played at step transitions and completion

## Try local coach recording (Windows MVP)

If the Windows runner is not present in a fresh checkout, create it once with
`flutter create --platforms=windows .`. Then run `flutter pub get` and
`flutter run -d windows`.

Open a workout, find **Your coach recording**, and select **Record**. Allow
microphone access in Windows Settings, speak the selected cue, then
select **Stop recording**. Use **Listen** to review it and **Use recording** to
assign it. The card near the top replaces the spoken workout description. Each
step row has a compact microphone button that opens the same recorder for that
step's name/guide cue. **Record replacement** and **Delete** replace or remove
the scoped local file. If a file is unavailable or cannot be played, AnhPT
safely falls back to the corresponding device TTS text.

Recordings stay under the app's local documents directory and are never
uploaded. Windows microphone access must also be enabled under **Settings >
Privacy & security > Microphone > Let desktop apps access your microphone**.
The Windows implementation of the `record` plugin does not display its own
permission popup; its permission check reports that capture may be attempted.
Use the in-app **Open microphone settings** button when recording does not
start, and make sure both **Microphone access** and **Let desktop apps access
your microphone** are enabled and an input device is selected.

## Offline background music

Open **Settings > Offline Music Library** to preview bundled tracks or import
personal audio. Personal files are copied into the app documents directory and
can be renamed, tagged by mood, or deleted. Open a workout to select a track,
set volume, and choose a coach ducking level. Music loops and follows workout
pause/resume/end. Everything stays local; there is no upload or stream.

## Run

```powershell
flutter clean
flutter pub get
flutter run -d chrome
```

or:

```powershell
flutter run -d windows
```

For Web, click Start Workout normally. Browsers often require a user gesture before
speech/audio is permitted; the Start button provides that interaction.

## Architecture and code documentation

The documentation under [`docs/architecture/`](docs/architecture/README.md) is maintained as a map of the current implementation.

Start with:

- [`Codebase Overview`](docs/architecture/codebase-overview.md) — source structure, state ownership, screens and dependencies.
- [`Workout Domain Model`](docs/architecture/workout-domain.md) — workout tree, repeats, voice config, exercises/media and YAML parsing.
- [`Workout Runtime`](docs/architecture/workout-runtime.md) — `SessionEngine`, voice/audio coordination and session state.
- [`Storage, Audio and Media`](docs/architecture/storage-and-media.md) — persistence, files and migrations.
- [`Bucket Catalogs and Packages`](docs/architecture/catalog-and-packages.md) — remote catalogs, install/update provenance and packages.
- [`Health and Local Profiles`](docs/architecture/health-and-profiles.md) — profile-scoped health data and migration.
- [`CI and Release Automation`](docs/architecture/ci-and-release.md) — verification, APK releases and documentation rendering.

C4/PlantUML diagrams and their generated SVG previews are also available in the architecture directory. UI/navigation documentation lives under [`docs/ux/`](docs/ux/README.md).

## Still pending for iPhone-native completion

- native AVSpeechSynthesizer bridge
- true background audio while locked
- system audio interruption / phone calls
- haptic bridge
- audio ducking of Spotify/Apple Music
- Live Activity / Dynamic Island
- Lock Screen Pause/Resume

---

# Project Management

## Repository language

English is the standard language for development and project-management content in this repository.

Use English for:

- Issues and issue templates
- Pull requests
- Commit messages
- Branch names
- GitHub Projects
- Labels
- Source-code comments
- Test descriptions
- README and technical documentation
- Configuration and schema field names

The AnhPT application itself may support multiple user-facing languages. Localized UI strings and workout content may use supported application languages.

## GitHub Projects

AnhPT uses three GitHub Projects with different responsibilities.

### Roadmap

Use **Roadmap** for medium- and long-term product planning, major features, architecture changes, and release goals.

Recommended lifecycle:

`Ideas -> Research -> Planned -> Ready -> In Progress -> Testing -> Released`

Use `Dropped` when an item is intentionally abandoned.

### Sprint Board

Use **Sprint Board** for active implementation work and short-term planning.

Recommended lifecycle:

`Backlog -> Ready -> In Progress -> Review -> Testing -> Done`

Use `Blocked` whenever work cannot continue because of a dependency or unresolved problem.

### Bug Tracking

Use **Bug Tracking** for defects and regressions.

Recommended lifecycle:

`New -> Needs Reproduction -> Confirmed -> Investigating -> Ready to Fix -> Fixing -> Ready to Verify -> Verified -> Closed`

Use `Won't Fix` for confirmed problems that will intentionally remain unresolved.

Severity describes impact. Priority describes how soon the issue should be addressed.

## Labels

Use labels consistently across issues and pull requests.

### Type

| Label | Purpose |
| --- | --- |
| `bug` | Defect or regression |
| `feature` | New user-facing capability |
| `enhancement` | Improvement to existing behavior |
| `refactor` | Internal restructuring without intended behavior change |
| `documentation` | Documentation work |

### Priority

| Label | Purpose |
| --- | --- |
| `priority: high` | Important or urgent work |
| `priority: medium` | Normal planned work |
| `priority: low` | Nice-to-have or non-urgent work |

### Area

| Label | Purpose |
| --- | --- |
| `frontend` | UI and client-side behavior |
| `backend` | Data, services, repositories, persistence, or server-side concerns |

Project fields may use more specific product areas such as UI, Workout, Voice / Audio, Health, Catalog, Storage, CI / Release, and Documentation.

## Issue Templates

Create new issues using one of the repository Issue Forms:

- **Bug Report** for defects and regressions
- **Feature Request** for new capabilities and product improvements
- **Task** for refactoring, maintenance, documentation, testing, research, CI, and other technical work

Every issue should describe the problem or objective, define its scope, and include verifiable acceptance criteria whenever applicable.

## Development Workflow

### 1. Create an issue

Create an issue before implementation when the work is significant enough to track independently.

Use a concise conventional title where applicable:

- `feat: add ...`
- `fix: correct ...`
- `refactor: simplify ...`
- `docs: document ...`

### 2. Classify the issue

Apply the appropriate type, priority, and area labels. Add the issue to the relevant GitHub Project.

### 3. Move work to Ready

Before implementation, the issue should have enough context and acceptance criteria to avoid major ambiguity.

### 4. Create a branch

Use short descriptive branch names:

- `feat/<short-description>`
- `fix/<short-description>`
- `refactor/<short-description>`
- `docs/<short-description>`

### 5. Implement and verify

Keep the change focused on the issue scope. Before opening or merging a pull request, run the relevant checks, normally:

```powershell
flutter analyze
flutter test
```

### 6. Open a pull request

Use conventional PR titles such as:

- `feat: ...`
- `fix: ...`
- `refactor: ...`
- `docs: ...`

Reference the issue in the PR body when appropriate:

```text
Closes #123
```

Move the related Sprint Board item to `Review` while the pull request is under review.

### 7. Merge and test

After CI and review succeed, merge the pull request. Move the item to `Testing` when post-merge verification is still required.

### 8. Complete the work

Move the item to `Done`, `Released`, `Verified`, or `Closed` according to the project workflow only after the applicable verification is complete.

## Definition of Ready

An issue is ready for implementation when:

- The problem or objective is clear.
- Scope is sufficiently defined.
- Acceptance criteria are testable where applicable.
- Important dependencies are known.
- Major unresolved product or technical questions are addressed.

## Definition of Done

Work is done when:

- The implementation or documentation is complete.
- Relevant tests or verification steps pass.
- `flutter analyze` and `flutter test` pass when applicable.
- Documentation is updated when behavior or developer workflow changes.
- The pull request is merged.
- Post-merge verification is complete when required.

## Recommended lifecycle

`Idea -> Issue -> Labels -> Project -> Ready -> Branch -> Implementation -> Pull Request -> CI / Review -> Merge -> Testing -> Release -> Done`
