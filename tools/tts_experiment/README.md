# Vietnamese coach TTS experiment

This isolated, local development harness generates 12 Vietnamese workout cues
(three for each voice profile) once and reuses the resulting files. It does not
change the Flutter runtime, implement a server, or represent production secret
storage.

## Target client architecture

The intended product flow is strictly client-only:

1. Check the device-local audio cache.
2. On a cache miss, play a user-recorded coach file assigned locally to the
   selected cue or workout, when one exists and is readable.
3. Otherwise, use the OpenAI API key that the user supplied on that device
   to synthesize high-quality audio directly from the client, then save it only
   to the device-local cache.
4. If the user has no key or synthesis fails, use the device's built-in TTS.

User recordings remain on the device, are not uploaded by default, and require
neither a server nor an API key. A future local recording index should store the
cue identifier, optional workout identifier, optional profile, language, local
audio path, creation time, and metadata version. The product UX must request
microphone permission in context, let the user confirm the target and listen
back before assignment, and provide clear replace and delete actions. Missing
files or denied microphone permission must fall through safely to the remaining
voice options.

There is no AnhPT audio server, shared API key, audio subscription, server
cache, or shared cache in this design. A production client must store the
user-provided key in platform secure storage and must never hard-code, commit,
cache, or log it. Secure storage is intentionally not implemented by this
command-line experiment. Recording capture, assignment, and playback are also
outside this harness; it remains focused on comparing generated TTS samples.

## Run

Requires Python 3. No third-party Python packages are needed.

```powershell
python tools/tts_experiment/generate.py --dry-run
$env:OPENAI_API_KEY = "your-key-for-this-shell"
python tools/tts_experiment/generate.py
Remove-Item Env:OPENAI_API_KEY
```

The environment variable is only a temporary credential bridge for this local
developer tool. Do not place the key in `cues.json`, source files, command-line
arguments, or a committed `.env` file.
Generated MP3 files and their manifest are written under `output/`, which is
gitignored. Re-running the command skips files already in the cache. Use
`--force` only when deliberately regenerating the same keys.

The experiment uses `gpt-4o-mini-tts` because its `instructions` field can
control delivery style. Edit `cues.json` to compare voices, speeds, or profile
instructions. Keep `experiment_version` unchanged for equivalent synthesis
behavior and increment it whenever prompt/profile semantics change.

## Cache identity

The full SHA-256 cache key is computed from canonical JSON containing:

- normalized text (Unicode NFC, trimmed, whitespace collapsed),
- language,
- voice profile,
- voice,
- speed,
- TTS provider and model,
- experiment/profile version.

The manifest retains the full key and all input fields; filenames use the first
16 hexadecimal characters for readability. Profile instructions are versioned
by `experiment_version`, so changing instructions also requires a version bump.

## Listening review

Listen in profile groups and rate each cue for Vietnamese pronunciation,
naturalness, intelligibility during movement, fit to the intended energy, and
whether pauses make the cue too slow for its workout context. This is a
pre-integration experiment: accepted files can later inform the client-local
cache and fallback design, but are not currently bundled into the Flutter
assets.

Official endpoint reference: https://developers.openai.com/api/reference/resources/audio/methods/speech
