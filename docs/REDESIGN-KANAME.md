# Redesign «Kaname» — implementation spec & tracker

> Single working doc for the full visual/UX redesign (functionality almost untouched).
> Token values: `docs/design-tokens.json` (v4). Motion: `docs/ANIMATIONS.md`. Product: `docs/SPEC.md`.
> Every redesign agent reads THIS file + design-tokens.json before touching UI.
> Status keys: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked.

## Decisions (user, 2026-06-28)
- **Cadence:** fully autonomous; commit+push each phase; user tests at the very end.
- **Wordmark:** show «Kaname» via ONE config constant (`kAppWordmark` in `app/lib/core/branding.dart`).
  Final name change later = edit one string. Code packages stay `com.kaizen` (do NOT rename).
- **Categories:** reuse the existing tag/subject concept as the coloured «category» (dot from the 8-colour
  palette). NO backend/schema change, minimal touch to add-task logic.
- **App icon:** user will make it later → SKIP. **Rive:** SKIP — Kai is built in CODE (CustomPaint).

## The five principles (apply on every screen)
1. One focus per screen (one hero, the rest yields). 2. Calm premium minimalism (Things 3 / Linear).
3. Colour in 3 roles only: accent / category / status — screens are almost monochrome by default.
4. Meaning encoded by FORM not only colour (the main task = shield shape → survives accent change + colour-blind).
5. Kai = presence, not a character (formless, no face; never blocks content; fully disable-able).

## Design-system rules (from tokens v4)
- **Theme = surfaces+text+border ONLY.** Accent decoupled (6 accents, user picks). One font (Geist) all themes.
- **Day is the default theme** (light, warm off-white). Themes: Day / Night / Black / Calm.
- **Accent roles:** `accent` (fill/icon), `accentTint` (soft underlay), `accentInk` (text on tint), `onAccent` (text on fill).
- **Status:** success / ember / danger (semantic, per-brightness). **Category:** 8 fixed colours, dots only, off by default.
- **Type:** weights 400/500 (600 rare) — NOT 700 bold. Sentence case everywhere. Tabular figures for numbers.
- **Icons:** Phosphor. regular (outline) default, fill+accent when active/selected. 20 navbar/inline, 16 caption, 24 ceiling.
- **Spacing** 4·8·12·16·24·32·48 (screen padding 24). **Radius** 8·12·14·16·20·pill. **No one-sided rounded borders.**
- **Flat by default.** Shadows only on bottom sheets + popovers. Cards = surface1 + 0.5dp hairline, no shadow.
- **No left colour fill-bars on cards** (category dot instead). **No ALL-CAPS.**
- **Motion:** instant 120 / transition 180 / card 240 / sheet 280 / screen 300. Spring only on joy. All off under reduce-motion.

## CRITICAL migration rule (do not break 106 files)
`FocusThemeExtension` is referenced in ~106 files. **KEEP the class name and ALL existing field names**
(`textMuted`, `ember`, `border`, `surfaceElevated`, `textFaint`, `accentMuted`, `success`, `borderStrong`).
Change VALUES + how the theme is CONSTRUCTED; ADD new fields (`accentTint`, `accentInk`, `danger`,
`textSecondary`). Map old → new surfaces (surface1=ColorScheme.surface, surface2=surfaceElevated, ink=onSurface).
Screens keep compiling; we restyle them screen-by-screen in later phases.

## §4 Component patterns (define once, screens reference)
- **4.1 Timeline row (core of Today + Plan-day):** `[time col 44dp right] · [spine: 2dp vertical line + node] · [card]`.
  Nodes encode type/status by shape+fill: main-pending = filled accent circle 14 + bg ring, card shows `shield` icon;
  done = filled textFaint circle, card struck-through/dimmed; normal task/event = hollow circle 13 (border textMuted),
  type icon on the right (event `calendar`, workout `barbell`, call `phone`…). **Now line** = thin accent line + node + "now"
  on the time col. Card = surface1, hairline, R14, pad 11×13, **no time inside** (it's on the spine). Main = accentTint underlay.
  Optional 10dp category dot before title. Swipes (configurable) done/skip/delete/snooze + Undo.
- **4.2 Lists & cards:** dense lists (settings/ingredients/entries) = hairline-divided rows, NOT tiles. Object cards
  (program/recipe/session) = surface1 + hairline + R14, leading neutral icon, title+subtitle, trailing chevron / `trash`(ember).
  Empty state = invitation: Kai (neutral, 64) + space name + one line + verb button. No "it's empty".
- **4.3 Buttons/fields/controls:** ONE primary (`FilledButton`, accent) per screen; rest Outlined/ghost; height ≥52, R12.
  Destructive = ember outline. Inputs 36–52dp, hairline, focus ring. Choice chips = accentTint + accent border when selected.
  **Time stepper** (− [value] +) or wheel for manual task-time edit (not a clock dial). Bottom sheet: handle · title row + close ✕ ·
  content · one primary button at bottom. Toasts: bottom, 3–4s, success/ember/neutral + Undo.
- **4.4 Add/edit task sheet:** natural-language field (parses date/time/repeat/priority/tag) + mic (hidden on web) →
  parsed chips with smart defaults → manual time via stepper → «Main» toggle (shield) → category (colour dot) →
  subtasks checklist → reminder → repeat (RRULE) → attachments. Keep existing add-task logic; just restyle + add category dot.

## Kai (built in code, CustomPaint — no Rive)
Formless fluid "liquid pebble" (metaball/superellipse), ONE solid accent fill, no face/eyes/mouth. Breathes at rest.
6 states (shape+motion+colour, no mimicry): neutral · thinking(AI/loading) · success · anxious(→ember) · harsh(→ember-tint) · idle/bored.
Sizes: 22–30 inline/sheets, 64 empty/paywall, up to 96 onboarding. Never overlaps content. `KaiLoader` = the brand loader for
ALL AI/loading. Tone (gentle/harsh) lives in Profile. Freezes neutral under reduce-motion/high-contrast. Off-toggle in Profile.

## RESUME 2026-06-30 (ветка night/…, запушено; analyze=0)
- 🔴→✅ **Блокер сборки решён:** phosphor_flutter расширял `IconData` (стал final во Flutter 3.44) → app не компилировался; `analyze` не ловил. Вендорнут+пропатчен в `app/third_party/phosphor_flutter` (commit 1731ed2). **analyze=0 ≠ собирается — проверяй `flutter test`.**
- ✅ **Гэпы закрыты (commit 9e1a3ce):** accent picker (6 акцентов) в Профиль→Внешний вид; custom_theme_editor HSV→accent; удалён fab_position_provider (FAB=endFloat в plan/food/habits/goals); auth 'Kaizen'→kAppWordmark; онбординг визуально унифицирован + Phosphor; l10n нотификаций/воды/превью темы (11 яз). Today/Plan-лента+Kai+KaiLoader+Paywall — подтверждены готовыми аудитом.
- ⏳ **Осталось:** (1) `flutter test` — ~38 устаревших ассертов под старую структуру (НЕ баги app, напр. date_navigator ждёт Material chevron вместо Phosphor caret) → обновить тесты; (2) 34 analyze-warning (линты); (3) overflow-тесты для 8 экранов; (4) опц.: структурное слияние онбординга (сейчас 3 маршрута, визуально едины), убрать bg-warmth слайдер; (5) реальный build/`flutter run` — рендер иконок; (6) иконка app (юзер).

## Phase tracker
- **[x] Phase 1 — Foundation:** tokens v4 → app_theme.dart (4 themes surfaces-only + accent decoupled + HankenGrotesk/Atkinson + a11y hooks),
  AccentKey + accentNotifierProvider, ThemeNotifier (4 themes + prefs migration focus→night/white→day), highContrastProvider + text-size,
  phosphor_flutter dep, `branding.dart` (kAppWordmark='Kaname'). Default theme = Day. Fix theme-picker references.
  flutter analyze=0, screens_smoke 8/8, overflow_audit 24/24. Font TODO: switch to Geist when google_fonts exposes it.
- **[~] Phase 2 — Scaffold + Kai:** scaffold_with_nav_bar Phosphor icons (sun/calendar-blank/heartbeat/notebook) + content
  max-width 1160 + landscape min-height guard [x DONE]; FAB fixed bottom-right (remove position setting); Kai CustomPaint rewrite
  (formless, 6 states) + KaiLoader.
- **[ ] Phase 3 — Core:** Today (quiet header + thin Kai review row + `Главное X/Y` counter + unified timeline §4.1; remove
  ring-hero/streak-row/7-dots/big-mascot/two-review-cards/«Main» section/habits) → Plan day on the same timeline + month
  category dots → add-task sheet §4.4.
- **[ ] Phase 4 — Themes & a11y UI:** Profile→Appearance (4 themes + accent picker §1.2); high-contrast + text-size as settings;
  remove FAB-position setting (`_FabPositionSetting`); custom-theme-editor → accent picker (drop HSV).
- **[ ] Phase 5 — Remaining screens:** Health/Food/Workouts/Breathing/Meditation/Diary/Water/Wrapped/Goals/ScreenTime/Sleep/
  Focus/Costudy — apply §4, Phosphor, KaiLoader on AI, gamification→Profile «Progress», localise hardcoded EN, unify water buttons.
- **[ ] Phase 6 — Onboarding + Paywall:** merge onboarding_screen+setup_flow into one Kai-led flow; remove ALL ad copy; no
  Google/Apple buttons; adaptive for web; «Kaname» wordmark.
- **[ ] Phase 7 — Icon (user) / Rive (skip).**
- **[ ] Final — Bug pass:** flutter analyze=0, flutter test green, overflow + l10n gates (app/CLAUDE.md), 320px / textScale 1.5 / keyboard.

## Anti-regression gates (app/CLAUDE.md — BLOCKING)
- No hardcoded user-facing EN — `context.s('key')` for ALL strings incl. content; add keys for en+ru (+9). Units via plural helpers.
- No overflow — Expanded/Flexible + ellipsis; test 320px, textScale 1.5–2.0, keyboard open. Prefer a widget test asserting no exception.
- Commit + push each verified slice.
