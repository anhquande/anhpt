# AnhPT Product Description

**Version:** 0.3  
**Status:** Updated to match AnhPT v0.8.2 behavior and current implementation decisions.

## 1. Product Vision

AnhPT is a voice-guided workout timer designed for hands-free exercise. The user defines workouts visually or through YAML, starts a session, and follows spoken step names, guides, timing announcements, and repeat context without continuously looking at the screen.

## 2. Primary User Experience

- Create and edit workouts with a Visual Workout Builder; YAML remains available as an advanced/import-export format.
- Each workout is composed of steps and repeat groups, including nested repeats.
- Each step may include an optional spoken `guide`.
- At the start of each repeat round, the first inner step can be announced as, for example, `Plank lần thứ 1`.
- For nested repeats, only the innermost repeat is announced.
- Per-step voice timing can be disabled while keeping step name, guide, cue sound, and visible timer.
- Step duration may be omitted or set to `0s`, enabling instruction-only steps.
- At step start, the timer and step announcement run in parallel.
- The app advances only after both the timer has finished and the protected step announcement has finished.
- If the timer reaches zero while the guide is still speaking, the UI waits for the guide to complete before advancing.
- Pause/resume applies to the timed portion of a running step.
- On Windows, a user can record device-local coach audio for the workout
  description and for individual step cues, review it, replace it, or delete
  it. Recordings are not uploaded; an unavailable recording falls back to the
  corresponding device TTS text.
- A workout can use an offline background track selected from the local music
  library. Music loops independently, follows workout pause/resume/end, and can
  duck at gentle through very-high levels while coach audio is active.
- YAML v2 carries recording references and the selected background-music
  configuration. Audio files remain local and are referenced by safe relative
  paths; missing files fall back safely.
- A step may reference a reusable Exercise with a static image, animated GIF,
  or short muted/looping video. Identical media is stored once in a device-local
  content-addressed Media Library and portable packages carry referenced media.

## 3. Voice Behavior

| Feature | Behavior |
|---|---|
| Step announcement | Speak step name; append repeat round when applicable; append guide when present. |
| Continuous mode | Speak elapsed seconds continuously. |
| Interval mode | Speak remaining time at configured intervals. |
| Ending mode | Speak final countdown from the configured threshold. |
| Combined mode | Interval announcements plus ending countdown. |
| `countdown: false` | Disable all timing voice for that step only. |
| TTS overlap rule | Step name/guide must not be cut off by step transition; transition requires announcement completion. |

## 4. Platforms

Current implementation targets Flutter Web and Windows for development/testing. Android can be used for device testing. iPhone-native capabilities such as Live Activity, Lock Screen controls, background audio behavior, interruption handling, and Dynamic Island integration remain future work.

## 5. Workout Buckets marketplace (MVP)

Settings supports public Workout Bucket sources identified by user-supplied
HTTPS `bucket.json` URLs. Enabled sources can be refreshed, browsed, and used to
install checksum-verified portable packages. The last valid catalog remains
available offline. Updates require an explicit keep/copy/replace choice. Private
credentials and signatures are deferred; Web sources must support CORS.
