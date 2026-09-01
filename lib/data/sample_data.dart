const sampleYaml = r"""version: 2

name: AnhPT Feature Demo
description: A short interactive workout that demonstrates voice guidance, camera comparison, video layouts, pause/resume, progress and repeat steps.

tags:
  - demo
  - beginner
  - full-body
  - camera
  - tutorial

start_countdown: 3s

voice:
  language: en
  mode: combined
  announce_every: 10s
  countdown_from: 3s
  announce_step_name: true
  announce_start: true
  announce_finish: true

feedback:
  sound: beep
  haptic: medium

audio:
  ducking: medium

video:
  auto_enable: true
  layout: picture_in_picture
  camera: front

steps:
  - name: Welcome
    id: welcome
    duration: 15s
    countdown: false
    guide: >
      Welcome to the AnhPT feature demo. Your front camera is enabled automatically so you can compare yourself with the demonstration.

  - name: Squat
    id: squat
    duration: 30s
    guide: >
      Do easy squats at your own pace. Try the grid button now and switch between the available video layouts.

  - name: Rest
    id: rest
    duration: 15s
    countdown: false
    guide: >
      Take a short rest. Tap the demonstration area once to pause, then tap it again to resume.

  - name: High Plank
    id: high-plank
    duration: 30s
    guide: >
      Hold a comfortable high plank. Compare your body line with the demonstration and try another camera layout if you want.

  - repeat: 2
    steps:
      - name: Squat Repeat
        id: squat-repeat
        duration: 20s
        guide: >
          Finish with easy squats. This repeated step demonstrates repeat handling and workout progress.
""";
