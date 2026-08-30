# AnhPT Integrated MVP v0.6.0

Adds real Text-to-Speech and cue sounds for Web and Windows.

## Voice behavior

- Announces workout start
- Announces each step name
- continuous: counts elapsed seconds upward
- interval: speaks remaining time at configured interval
- ending: counts down final seconds
- combined: interval + final countdown
- speaks Pause / Resume
- announces completion
- drops/cancels obsolete speech at step changes

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

## Offline background music (Windows MVP)

Open **Settings > Offline Music Library** to preview bundled tracks or import
personal audio. Personal files are copied into the app documents directory and
can be renamed, tagged by mood, or deleted. Open a workout to select a track,
set volume, and choose Off/Gentle/Medium coach ducking. Music loops and follows
workout pause/resume/end. Everything stays local; there is no upload or stream.

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

## Still pending for iPhone-native completion

- native AVSpeechSynthesizer bridge
- true background audio while locked
- system audio interruption / phone calls
- haptic bridge
- audio ducking of Spotify/Apple Music
- Live Activity / Dynamic Island
- Lock Screen Pause/Resume
