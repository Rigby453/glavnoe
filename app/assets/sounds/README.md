# Sounds

Short in-app sound effects.

## task_done.mp3 — TODO (drop file here)

Completion sound played when a task is marked done (swipe-right or tap checkbox).

- **Expected file:** `assets/sounds/task_done.mp3`
- **Recommended:** a short (~0.3–0.8 s), light, pleasant "ding"/"pop". Keep it quiet
  and non-annoying — it fires on every completion.
- **Format:** MP3 (or update the path in
  `lib/services/sound/completion_sound_service.dart`).

Until this file is added, the app gracefully falls back to the system click sound
(`SystemSound.play(SystemSoundType.click)`). As soon as `task_done.mp3` exists here
(it is already registered in `pubspec.yaml`), it will play automatically — no code
changes needed.
