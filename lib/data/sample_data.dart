const sampleYaml = r"""version: 2

name: Sample Plank
description: Bài plank mẫu với hướng dẫn tiếng Việt

tags:
  - plank
  - core

start_countdown: 5s

voice:
  language: vi
  timing:
    elapsed_time: false
    interval: true
    interval_every: 10s
    final_countdown: true
    countdown_from: 5s
  announce_step_name: true
  announce_start: true
  announce_finish: true

feedback:
  sound: beep
  haptic: medium

audio:
  ducking: medium

steps:
  - name: Khởi động
    duration: 1m

  - repeat: 3
    steps:
      - name: Plank
        duration: 40s
      - name: Nghỉ
        duration: 20s
""";
