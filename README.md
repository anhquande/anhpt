# AnhPT Integrated MVP v0.6

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
