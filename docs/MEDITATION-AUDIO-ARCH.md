# Meditation Audio & Media — Architecture

> Status: **proposed** (reviewed by user in the morning).
> Scope: narration voices (TTS), ambient/white-noise, and future video for the meditation
> feature (`app/lib/features/health/meditation_screen.dart`).
> This document is an architecture proposal + ADR. It recommends; it does not survey.

---

## ADR-054: Meditation media — pre-generated premium TTS, hosted on object storage + CDN, discovered via a manifest endpoint

**Date:** 2026-06-25

**Status:** proposed

### Context

The meditation player today (`meditation_screen.dart`) is **text-only**: five built-in sessions
(plus user-made ones) are lists of `_Step{ textKey, seconds }`. Each step shows a localized
instruction and counts down an arc timer; there is **no audio at all**. The user wants:

1. **Beautiful narration voices** ("красивые голоса") reading the steps aloud (TTS).
2. **Quiet ambient / white-noise** under the session (rain, brown noise, etc.).
3. **Video** eventually (unspecified — clarified below).

…and explicitly asked **where to store all this media and how to implement it**.

Constraints from the repo that shape the decision:

- **Platforms:** Flutter iOS + Android + **Web** (CLAUDE.md, ADR-001). Web must degrade gracefully.
- **Localization is law:** ADR-043 ships **12 languages**; the anti-regression gate in
  `app/CLAUDE.md` forbids hardcoded English and requires every user-facing string in all active
  languages. Audio narration is "user-facing content" → it must scale to ~11–12 languages, not 1.
- **RU geo-block:** Gemini (and several US AI APIs) **do not answer from RU IPs** (MEMORY,
  CLAUDE.md). Any **runtime** call to a US TTS API from a user's RU phone is at risk of being
  blocked. The backend itself runs on **Render, region `frankfurt`** (render.yaml) — outside RU —
  but Render free tier has an **ephemeral disk and sleeps**, so it is a bad place to *store* media.
- **No storage today:** backend has **no** `@fastify/static`, no S3/R2, no object storage, no
  upload route (verified). Media is greenfield.
- **Existing deps:** `audioplayers ^6.0.0` (short SFX) and `video_player ^2.9.0` are already in
  `pubspec.yaml`. There is **no** `flutter_tts`, `just_audio`, or `audio_session` yet.
- **Offline-first** is a core value (ADR-003): media must be cacheable on device, not require a
  live connection every session.

### Decision (summary — details in sections 1–6)

1. **Narration:** **build-time / content-time pre-generation** with a premium neural TTS provider.
   We generate the audio **once, on a dev/CI machine outside RU**, and ship the resulting files.
   We do **not** call a TTS API at runtime from the client. On-device `flutter_tts` is the
   **free fallback / Phase-1 baseline** only.
2. **Storage & delivery:** **object storage + CDN** — recommend **Cloudflare R2** (S3-compatible,
   **zero egress fees**) fronted by Cloudflare CDN. **Not** bundled Flutter assets (bloats the app
   for 12 languages) and **not** the Render backend (ephemeral, sleeps, not a CDN).
3. **Discovery:** the client learns URLs from a **manifest endpoint** on the existing backend
   (`GET /api/v1/media/manifest`), not from hardcoded URLs — so we can re-version media without
   shipping an app update.
4. **Ambient:** a small **curated, licensed** royalty-free loop library on the same R2 bucket, with
   a **synthesized brown/white-noise generator on-device as the licensing-free MVP baseline**.
5. **Playback:** migrate meditation playback to **`just_audio` + `audio_session`** for gapless
   looping, two-track mixing (narration + ambient) at independent volumes, and lock-screen/background
   playback. (`audioplayers` stays for one-shot SFX.)
6. **Video:** **deferred.** Ship an animated gradient / Kai placeholder first; when real video lands
   it streams (HLS) from the same R2+CDN, never bundled.

### Consequences

- **Cost is near-zero and one-time.** Pre-generating ~12 languages of the 5 built-in scripts is a
  one-off spend of **tens of dollars** (section 1), not a per-user runtime cost. Re-generation only
  happens when a script changes.
- **The RU geo-block disappears for narration** — generation happens off RU IPs at build time; the
  phone only *downloads a static file from a CDN*, which is not geo-blocked.
- **App size stays small** — audio lives on the CDN and is downloaded/cached on demand, so adding
  languages does not grow the `.ipa`/`.apk`/web bundle.
- **A new external dependency** (an R2/S3 account + a CDN) and **a build-time generation pipeline**
  (a script that calls the TTS provider) must be created and owned. Both are listed under
  "Decisions needed from user".
- **New Flutter deps** (`just_audio`, `audio_session`, `flutter_tts`) and a new `AudioService`
  abstraction; the stepped player gains audio without changing its step/timer model.
- **User-made custom sessions** (raw text, created at runtime) cannot be pre-generated → they use the
  **on-device `flutter_tts` fallback** (no hosted audio). This is an acceptable, explicit tier split.

> **DECISIONS NEEDED FROM USER** are collected at the **bottom** of this document.

---

## 1. Narration (TTS) — "beautiful voices"

### Options

| Option | Quality | Cost model | RU geo-block | Multi-language | Verdict |
|---|---|---|---|---|---|
| **(a) Pre-generate at build/content time**, host files | **Best** (premium neural voices) | **per-character, one-time** at generation | **Sidestepped** — generate off RU IPs, phone only downloads a static file | Generate once per language; cost ≈ linear in chars × langs, still tiny | **RECOMMENDED (primary)** |
| (b) On-device `flutter_tts` at runtime | Robotic, varies by OS/voice | **Free** | None (fully local) | Depends on installed OS voices; RU/CJK coverage uneven | **Fallback / Phase-1 baseline** |
| (c) Backend-proxied runtime TTS | Best | per-character, **per play**, every user every session | Backend is in Frankfurt (ok to call provider), but adds latency, infra, recurring cost; needs offline cache anyway | Same as (a) but paid forever | Rejected — recurring cost for no quality gain over (a) |

### Recommendation: **(a) build-time pre-generation, premium provider, host the result.**

Meditation scripts are **fixed content**, not user input — the five built-in sessions' step texts
live in the l10n dictionary and rarely change. That makes (c)'s "generate on every play" pure waste:
you would pay, repeatedly and per-user, to synthesize the *same* sentence millions of times. Generate
each step **once per language**, store the `.m4a`, and every play afterwards is a free CDN download.

**Why this also kills the geo-block:** generation runs on a **dev laptop or CI runner outside RU**
(GitHub Actions, the Frankfurt backend, or the developer's machine via VPN). The RU user's device
never touches a TTS API — it only fetches a static audio file from a CDN, which is not subject to the
Gemini-style RU IP block. **Call this out explicitly to the user: build-time generation converts a
runtime geo-risk into a one-time, off-RU build step.**

### Cost model (per-character, one-time)

A meditation step is short (~1–3 sentences). Estimate **~2,500 characters per session** across its
steps; **5 built-in sessions ≈ 12,500 chars per language**; **× ~11 languages ≈ ~140k characters**
total. Indicative provider pricing (verify live before committing — see decisions list):

| Provider | ~Price | One-time cost for ~140k chars | Notes |
|---|---|---|---|
| **ElevenLabs** | premium tiers, roughly **$0.15–0.30 / 1k chars** | **~$20–40 one-time** | **Best "красивые" quality**; strong multilingual model; the obvious pick for the *hero* voices (EN/RU) |
| **Azure Neural TTS** | **~$16 / 1M chars** (~$0.016/1k) | **~$2–3 one-time** | Excellent quality, **huge language/voice catalog**, cheapest at scale → best for the **long tail of 11 langs** |
| **Google Cloud TTS** (Neural2/WaveNet) | **~$16 / 1M chars** | **~$2–3 one-time** | Comparable to Azure; broad languages |
| **OpenAI TTS** (`tts-1-hd`) | **~$15 / 1M chars** | **~$2 one-time** | Very natural, dead-simple API, **fewer distinct voices / language tuning** than Azure |

The headline point: **even the most expensive option is a one-time ~$40**, because we pay per
character generated, not per play. This is a rounding error against the product budget.

### Premium ("красивые голоса") tier vs free fallback

- **Premium tier (hosted, pre-generated):** the curated, beautiful neural voice per language,
  downloaded from the CDN. Used for **built-in sessions**. This is the differentiator the user wants.
- **Free fallback (`flutter_tts`, on-device):** robotic OS voice, no download, works offline with
  zero cost. Used for **(i)** Phase-1 before hosted audio exists, **(ii)** **user-created custom
  sessions** (raw runtime text that was never pre-generated), and **(iii)** any language/session whose
  hosted file is missing or undownloaded. The player must handle both transparently behind one
  `AudioService` (section 5).

> Opinionated default to propose to the user: **ElevenLabs for the two hero languages (EN + RU)** —
> where "beautiful" matters most and the audience is concentrated — and **Azure Neural TTS for the
> remaining ~9 languages** where cost/voice-catalog/coverage win. Single provider is simpler; mixed is
> cheaper-with-better-flagship. This is a **user decision** (see bottom).

### Input needed from the user (narration)

- Which provider(s) for which languages, and the **budget ceiling** (likely <$50 one-time).
- The **API key** for the chosen provider(s) (used only at build time, on a non-RU machine; **never**
  shipped in the client or committed — same rule as ADR-006 for AI keys).
- Voice selection per language (gender/tone), and whether narration is **per-step files** (recommended,
  maps to the stepped player) or one continuous track with timestamps.

---

## 2. Ambient / white noise

### Sourcing — licensing is not optional

**Do not grab random audio files.** "Royalty-free" ≠ "public domain"; most clips carry attribution or
no-resale terms that a commercial product (this is a paid app, CLAUDE.md) cannot ignore. Acceptable
sources, in order of safety:

- **CC0 / public-domain** loops (e.g. Freesound filtered to CC0, Pixabay's license) — usable
  commercially, no attribution required. **Preferred** for a paid product.
- **Paid royalty-free libraries** (e.g. Epidemic Sound, Artlist) — clean commercial license, costs a
  subscription; overkill for a handful of loops.
- **Synthesized noise** (see below) — **zero licensing risk**, generated by us.

Whatever is chosen, **record the license** (source URL + license text) next to the asset.

### Bundle vs stream

Ambient loops are **few and reused across every session** (one rain loop serves all sessions in all
languages). That is the opposite of narration (many, per-language). So:

- **Bundle the 1–3 core ambient loops** in the app (small, always available offline, instant start).
- **Stream/download the rest** (a larger "ambient library" — forest, ocean, café, fireplace) from R2
  on demand, cached locally. Keep each loop short (30–60 s), seamless, AAC/Opus, mono ~96 kbps.

### Looping / gapless playback

A naive loop clicks at the seam. Solutions: (a) author/trim loops to **zero-crossing seam points**, or
(b) use a player with sample-accurate looping. `just_audio`'s `LoopMode.one` + a properly trimmed loop
gives gapless playback; for absolute seamlessness, `ConcatenatingAudioSource` with a `LoopMode` works
too. (`audioplayers` `ReleaseMode.loop` is good enough for Phase 1.)

### Mixing narration + ambient at independent volumes

Two **separate** player instances:

- **Narration player** — plays the (hosted or `flutter_tts`) step voice; volume e.g. 1.0.
- **Ambient player** — loops the chosen background; volume e.g. **0.2–0.35** (quiet, per the request).

Configure **`audio_session`** with a category that **allows mixing** and **ducks/lowers ambient while
narration speaks** (optional nicety). Two independent `setVolume()` controls → two UI sliders
("Voice" / "Ambient"), persisted in `shared_preferences`.

### Recommendation + MVP fallback

- **MVP baseline (licensing-free):** **synthesize brown/white noise on-device** — generate a short PCM
  buffer of brown noise (integrated white noise — gentler than pure white) once and loop it. No file,
  no license, works offline, infinite. This guarantees an ambient option ships even before any licensed
  library exists.
- **Phase 2:** add a **curated CC0/Pixabay loop library** on R2 (rain, ocean, forest, fireplace),
  downloaded on demand and cached. Bundle the single most-used loop (e.g. rain) in-app for offline.

### Input needed from the user (ambient)

- Approve **CC0/synthesized** as the licensing approach (vs paying for a library).
- Which 3–6 ambient tracks to curate first.

---

## 3. Video

### What "video" means here — clarify with the user

Two very different products hide under "video":

- **(A) Looping background visuals** during a session (slow gradients, drifting clouds, candle flame) —
  ambience, muted, decorative. **Low value-to-cost**; a Flutter shader/animation can fake most of it.
- **(B) Guided video** (an instructor / animated scene you watch) — a different feature, large files,
  needs its own production. **High cost.**

Assume the user means (A) ambience first. Either way:

### App-size impact

Bundling video is a **non-starter**: even a 30 s 1080p clip is several MB; multiplied across
sessions/themes it bloats the app well past store-friendly sizes. Video, when it exists, **streams**.

### Recommendation: **defer heavy video; ship a lightweight placeholder first.**

- **Now:** an **animated gradient / Rive / shader background** (we already have a motion system —
  `docs/ANIMATIONS.md` — and the Kai mascot, ADR-032). Cheap, on-brand, theme-aware, zero bytes added,
  respects `MediaQuery.disableAnimations`. This satisfies "moving background" without any media.
- **Later (Phase 3):** real video **streamed via HLS** from R2 + CDN using the existing
  `video_player ^2.9.0` package. Key scheme `/media/video/{name}/{quality}.m3u8`. Never bundled.
  Decide (A) vs (B) before investing — (B) needs a content-production plan, not just storage.

---

## 4. Storage & delivery decision (the core of the question)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Bundled Flutter assets** | Dead simple; offline; instant | **Bloats app size**; **terrible for ~12-language audio** (every language ships to every user); re-versioning needs an app update | **No** for narration; OK only for 1 tiny ambient loop |
| **Backend static files** (Render) | Reuses existing server | Render free tier = **ephemeral disk + sleeps**; **not a CDN** (slow, single-region Frankfurt); competes with API for the free instance | **No** |
| **Object storage + CDN** (R2 / S3+CloudFront) | Built for static media; **global CDN**; cheap; decoupled from the app and the API; re-version freely | One more account/service; need a key-naming + manifest scheme | **RECOMMENDED** |

### Recommendation: **Cloudflare R2 + Cloudflare CDN.**

Reasons over S3+CloudFront: **R2 has zero egress fees** (media is read-heavy — users download audio
repeatedly), it is **S3-API-compatible** (standard SDK/tooling), and the CDN is included. S3 also works
fine if the user already has AWS; the architecture is identical (only the endpoint/keys differ).

### Key / folder naming scheme

```
media/                              ← bucket root
  meditation/
    {session_id}/                   ← e.g. body_scan, focus_reset
      {lang}/                       ← en, ru, de, fr, it, pt, id, hi, ja, ko, es
        step-1.m4a
        step-2.m4a
        ...
        manifest.json               ← optional per-session checksum list
  ambient/
    rain.m4a
    brown-noise.m4a
    ocean.m4a
  video/                            ← Phase 3
    {name}/
      720p.m3u8
```

- **Per-step files** map 1:1 to the player's `_RunStep` model — play `step-{n}.m4a` when step *n*
  starts, then let the existing timer run out the remaining silence. No timestamp bookkeeping.
- `{lang}` mirrors the l10n tags from ADR-043 (region falls back to base language, same resolver rule).
- **Format:** **AAC in `.m4a`** — best compatibility across iOS/Android/Web at small size. (Opus is
  smaller but iOS/Safari support is weaker; stick with AAC.)

### How the client discovers URLs — **manifest endpoint, not hardcoded**

Add **`GET /api/v1/media/manifest`** to the existing backend (it already serves the API the client
talks to). It returns the CDN base URL + which sessions/languages are available + a **version/etag per
file** so the client knows when to re-download:

```jsonc
// GET /api/v1/media/manifest   (snake_case per ADR-008)
{
  "media_base_url": "https://media.kaizen.app",
  "version": 7,
  "meditation": {
    "body_scan": {
      "en": { "steps": ["step-1.m4a", "step-2.m4a"], "voice": "elevenlabs-rachel", "etag": "ab12" },
      "ru": { "steps": ["step-1.m4a", "step-2.m4a"], "voice": "azure-svetlana",   "etag": "cd34" }
    }
  },
  "ambient": [
    { "name": "rain",        "file": "ambient/rain.m4a",        "etag": "ef56" },
    { "name": "brown_noise", "file": "ambient/brown-noise.m4a", "etag": "00ff", "synth": true }
  ]
}
```

This endpoint is **static config**, not DB-backed — it can be a checked-in JSON file the backend reads
and serves (no migration, no Prisma model), or even a JSON object on R2 the client fetches directly. A
backend route is preferred so we can localize/gate it and reuse the existing CORS allowlist (ADR-045).
**Re-versioning media never requires an app-store release** — bump `version`, the client re-downloads.

> Note on `render.yaml`: the backend deploy is unchanged except for **adding the manifest route** (and
> optionally an env var `MEDIA_BASE_URL`). No static-file serving is added to Render — media stays on R2.

### Caching / offline-download strategy on device

- On first play of a session, the client **downloads its per-step files** (via `dio`) into the app
  documents dir (`path_provider`), keyed by `{session}/{lang}/step-n.m4a@etag`.
- Subsequent plays read from disk → **works offline**, no repeated egress.
- A **"Download for offline"** button per session (and a "manage downloads" screen) lets users
  pre-fetch. Ambient loops cache the same way.
- Cache invalidation by **etag/version** from the manifest; stale files are re-fetched.
- Web has no persistent file cache the same way → rely on **HTTP/CDN caching** + the browser cache;
  acceptable since Web is the secondary platform.

---

## 5. Flutter playback implementation plan

### Package choice — verified against current `pubspec.yaml`

- `audioplayers ^6.0.0` is present but is tuned for **one-shot SFX** (task-done sound). It can loop and
  set volume, so it is **fine for Phase 1**, but it is weak for **sample-accurate gapless loops + a true
  two-track mixer + background/lock-screen** control.
- **Add `just_audio` + `audio_session`** (the standard Flutter choice for mixing/looping/background) for
  Phase 2. `just_audio` gives independent player instances, gapless `LoopMode`, precise `setVolume`, and
  Web support; `audio_session` configures the OS audio category (mixing, ducking, interruptions).
- **Add `flutter_tts`** for the on-device free fallback and Phase-1 narration.
- Keep `audioplayers` for the existing short SFX — no need to migrate that.

### `AudioService` / player abstraction

Introduce one seam (mirrors the project's `PurchaseService`/AI-provider abstraction pattern,
ADR-022/028) so the player screen is agnostic to *how* a voice is produced:

```dart
abstract class MeditationAudio {
  Future<void> loadSession(RunSession s, {required String lang});
  Future<void> playStep(int index);     // hosted file OR flutter_tts, decided inside
  Future<void> setAmbient(String? name); // null = off; loops at ambientVolume
  Future<void> setNarrationVolume(double v);
  Future<void> setAmbientVolume(double v);
  Future<void> pause();
  Future<void> dispose();
}
```

- **`HostedMeditationAudio`** (Phase 2): narration = `just_audio` player on the downloaded `step-n.m4a`;
  ambient = a second `just_audio` looping player; falls back to TTS per-step if a file is missing.
- **`DeviceMeditationAudio`** (Phase 1 / custom sessions): narration = `flutter_tts.speak(stepText)` in
  the current locale; ambient = `audioplayers` looped brown-noise/loop. Same interface.

The existing stepped player (`_SessionPlayerScreenState`) calls `playStep(index)` from `_startStep` and
`setAmbient(...)` once at session start — the **step/timer model is untouched** (audio is additive). On
`MediaQuery.disableAnimations` the visuals already degrade; audio is independent of that.

### Mixing + independent volumes

Two players, two volumes, two persisted sliders (section 2). `audio_session` category =
playback-with-mixing; optionally duck ambient while the narration clip plays. Voice and ambient are
fully decoupled so the user can have voice-only, ambient-only, or both.

### Background / lock-screen playback

`just_audio` + `audio_session` (and, if we want full lock-screen transport controls, `audio_service`)
enable continued playback when the screen locks — important for a 15-minute `sleep_prep` session. iOS
needs the **`audio` background mode** in `Info.plist`; Android a foreground service (provided by
`audio_service`). Phase 2 item.

### Graceful Web fallback

- Web **cannot** do true background audio and has limited autoplay (needs a user gesture — the player is
  already opened by a tap, so the first play is gesture-initiated → OK).
- `flutter_tts` on Web uses the **Web Speech API** (voices vary by browser); `just_audio` supports Web
  for file playback. Lock-screen/background controls are simply **absent** on Web — acceptable, Web is
  secondary. The `AudioService` abstraction hides the platform differences from the screen.

---

## 6. Phased rollout

### Phase 1 — tonight / baseline (NO paid deps, a build agent can do this immediately)

Goal: meditation plays end-to-end **with voice + ambient**, fully free, fully offline.

1. Add **`flutter_tts`** to `pubspec.yaml` (no account, no key).
2. Implement **`DeviceMeditationAudio`** behind the `MeditationAudio` interface:
   - **Narration:** on each step start (`_startStep`), `flutter_tts.setLanguage(currentLocaleTag)` then
     `speak(step.text)`. Step text is already localized (`_RunStep.text`). Respect a "voice on/off" pref.
   - **Ambient:** loop a background using the **already-present `audioplayers`** —
     `AudioPlayer()..setReleaseMode(ReleaseMode.loop)`. For the **licensing-free baseline**, ship a
     **synthesized brown-noise** loop (generate a short PCM/WAV once, store under `assets/sounds/`,
     already a declared asset dir) — OR a single **CC0** rain loop if one is approved.
   - **Mixing:** two players, two volume sliders ("Voice" / "Ambient") persisted in
     `shared_preferences`. Ambient defaults quiet (~0.25).
3. Wire the player screen to call `playStep`/`setAmbient` — **do not change the step/timer logic**.
4. l10n: add keys for the new controls (voice toggle, ambient picker, volume labels) in **all active
   languages** (anti-regression gate in `app/CLAUDE.md`). Add a widget test (small width + large text,
   `takeException() == null`).

> Result after Phase 1: every session has a spoken (if robotic) voice + quiet ambient, on every
> platform, offline, $0. This is the demoable end-to-end baseline.

### Phase 2 — premium hosted narration + ambient library

1. Stand up **Cloudflare R2 + CDN**; create the key scheme (section 4).
2. Build a **generation script** (Node/TS, runs on dev/CI **outside RU**) that reads the localized step
   texts, calls the chosen TTS provider per language, and uploads `step-n.m4a` to R2. Idempotent; only
   regenerates changed steps. Key + budget = user decisions.
3. Add **`GET /api/v1/media/manifest`** to the backend (+ `MEDIA_BASE_URL` in `render.yaml`).
4. Add **`just_audio` + `audio_session`**; implement **`HostedMeditationAudio`** (download-and-cache via
   `dio` + `path_provider`, gapless ambient loop, two-track mix, fall back to TTS when a file is absent).
5. Add a **curated CC0 ambient library** on R2 + a "Download for offline" UX.
6. Background/lock-screen playback (`audio_service`, Info.plist background mode).

### Phase 3 — video

1. Decide **(A) looping ambience vs (B) guided video** with the user.
2. Until then, ship the **animated gradient / Kai / shader** placeholder (zero bytes).
3. When real: **HLS streaming** from R2+CDN via the existing `video_player`, never bundled.

---

## DECISIONS NEEDED FROM USER

1. **TTS provider & budget.** Approve build-time pre-generation. Pick provider(s): proposed default is
   **ElevenLabs for EN/RU (hero "красивые" voices) + Azure Neural TTS for the other ~9 languages**, or a
   single provider for simplicity. Confirm a **one-time budget** (estimated **<$50**).
2. **TTS API key(s)** for the chosen provider — used **only at build time on a non-RU machine**, never
   in the client, never committed (ADR-006 rule).
3. **Voice selection** per language (gender/tone) and **per-step vs single-track** narration (per-step
   recommended).
4. **Storage account:** approve **Cloudflare R2** (recommended, zero egress) — or AWS S3+CloudFront if
   an AWS account already exists. Need the account + access keys (build-time only).
5. **Ambient licensing approach:** approve **synthesized brown/white noise + CC0/Pixabay loops** (no
   paid library), and pick the first 3–6 ambient tracks.
6. **Video meaning:** confirm (A) looping background ambience vs (B) guided video, so Phase 3 is scoped
   (or confirm it stays deferred behind the animated-gradient placeholder).
7. **Custom-session narration:** confirm that user-created sessions use the **on-device `flutter_tts`
   fallback** (they can't be pre-generated) — i.e. premium hosted voices are for built-in sessions.
```
