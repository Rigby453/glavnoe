# Flutter Agent — Kaizen

## Read these first (in order)
1. /CLAUDE.md — project overview, phase plan, principles
2. /docs/design-tokens.json — colours, fonts, spacing per theme
3. /docs/ANIMATIONS.md — animation spec (durations, curves, per-element behaviour) — THE source of truth for motion
4. /docs/api-spec.yaml — endpoints to call (implement Dio client matching exactly)
5. /docs/UX-LAYOUT.md — control placement, accent usage, tap-reduction (ADR-033) — read before touching navigation/screen layout
6. /docs/MASCOT.md — mascot "Kai" spec (ADR-032) — read before building the mascot/Rive presence

---

## Stack
Flutter 3 · Dart 3 · flutter_riverpod · Drift (SQLite) · go_router · Dio · google_fonts

## Project structure
```
app/lib/
├── core/
│   ├── theme/          ← ThemeData for all 5 themes
│   ├── router/         ← go_router config
│   └── database/       ← Drift DB tables + DAOs
├── features/
│   ├── today/          ← Today tab
│   ├── plan/           ← Plan tab
│   ├── health/         ← Health tab (summary: Sleep always; Water/Food/Workouts/Meditation/Breathing behind mode-flags)
│   ├── diary/          ← Diary tab
│   └── profile/        ← Profile screen (NOT a tab)
└── services/
    ├── api/            ← Dio HTTP client
    └── sync/           ← offline-first sync service
```

---

## MVP implementation order

### Step 1 — Init + dependencies
```bash
flutter create . --org com.kaizen --platforms ios,android,web
```
`pubspec.yaml` add:
```yaml
dependencies:
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  drift: ^2.18.0
  drift_flutter: ^0.2.0
  go_router: ^14.0.0
  dio: ^5.4.0
  shared_preferences: ^2.2.0
  google_fonts: ^6.2.0
  intl: ^0.19.0
  sqlite3_flutter_libs: ^0.5.0

dev_dependencies:
  build_runner: ^2.4.0
  drift_dev: ^2.18.0
  riverpod_generator: ^2.4.0
```

### Step 2 — Focus theme (`lib/core/theme/`)
From `/docs/design-tokens.json` → theme `focus`:
```dart
// Colors
bg:       Color(0xFF141009)
surface:  Color(0xFF241D11)
text:     Color(0xFFF6EFE1)
textMuted:Color(0xFF9E9070)
accent:   Color(0xFFD9F24B)   // lime
ember:    Color(0xFFFF6A3D)   // for urgent/overdue
border:   Color(0xFF3A3020)

// Fonts: Fraunces (display/headings) + Hanken Grotesk (body)
// Load via google_fonts package
```
Create `AppTheme` class with static `ThemeData focusTheme`.
Store selected theme key in SharedPreferences; rebuild via Riverpod provider.

### Step 3 — Navigation (`lib/core/router/`)
```
Bottom nav: 4 tabs only
  /today   → TodayScreen   icon: sun (Icons.wb_sunny_outlined)
  /plan    → PlanScreen    icon: calendar (Icons.calendar_today_outlined)
  /health  → HealthScreen  icon: heart (Icons.favorite_border)
  /diary   → DiaryScreen   icon: book (Icons.menu_book_outlined)

Profile: NEVER a tab — AppBar leading button (avatar icon → /profile)
```
Use `ScaffoldWithNavBar` wrapper and `StatefulShellRoute` in go_router.

### Step 4 — Drift local DB (`lib/core/database/`)
Tables matching `/docs/data-model.md`:
- `ItemsTable` (id, userId, title, type, priority, status, scheduledAt, durationMinutes, isProtected, recurrenceRule, createdAt, updatedAt)
- `StreakTable` (userId, current, longest, lastCompletedDate, freezeCount)
- `WaterLogsTable` (id, userId, amountMl, loggedAt)
- `DayLogsTable` (id, userId, date, mood, note, insight, createdAt)
- `SyncQueueTable` (id, tableName, recordId, operation, payload, createdAt)

### Step 5 — Today screen
```
AppBar: greeting ("Good morning, {name}") + date · avatar button (leading)
Body:
  - RingWidget (CustomPainter): arc = done_main / total_main, animates 300ms
  - Streak row: 🔥 N · 7 dots (last 7 days, filled/empty)
  - MorningReviewCard (appears if pending items from yesterday)
  - Section "Main today": filtered priority=main items, shield badge
  - Section "Later today": rest of today's items, chronological
  - Swipe left on item → skip; swipe right → done (with haptic)
  - FAB [+] → AddTaskBottomSheet
```

### Step 6 — Plan screen
Week strip (swipe weeks) + day timeline (items by scheduledAt).
Tap [+] → AddEventSheet with type selector (task/event/exam/deadline).

### Step 7 — Diary screen
- Mood selector (1–5 emoji)
- Text note field
- "What went wrong" chip multi-select (soсials/walked/tired/other)
- [Save Day] → insert DayLog to Drift

### Step 8 — API + Sync
`lib/services/api/api_client.dart` — Dio with:
- baseUrl from const / .env flavor
- Bearer token interceptor (token from SharedPreferences)
- 401 interceptor → clear token, redirect /login

`lib/services/sync/sync_service.dart`:
- Write to Drift first, always
- Add to SyncQueue
- On app resume + connectivity: POST /api/v1/sync
- Merge server response (replace local if server updatedAt > local updatedAt)

---

## Rules

| Rule | Detail |
|------|--------|
| Offline-first | Write to Drift DB first — always. Sync is secondary. |
| Claude API | NEVER in Flutter — backend handles all AI calls |
| State | Riverpod only — no setState in feature screens |
| Themes | All 5 themes switchable; default = focus; load from SharedPreferences |
| Navigation | Profile is AppBar leading button, NOT a 5th tab. Placement rationale + refinements in /docs/UX-LAYOUT.md (ADR-033) |
| Mascot | "Kai" presence (Rive) per /docs/MASCOT.md (ADR-032); eyes = theme accent; behaviour from gentle/harsh tone; off-toggle in Profile; static under disableAnimations |
| Main limit | Max 3 items with priority=main per day — enforce in AddTaskBottomSheet |
| Optional modules | Health screen is a **summary**: Sleep always visible; **Water/Food/Workouts/Meditation/Breathing are optional modules behind mode-flags** (`core/settings/feature_modes_provider.dart`), toggled in Profile → Behavior, off by default. They are NOT premium gates. Posture is reminder-toggle-only (no nav). Habits + co-study tiles are removed from nav. See SPEC §C5/§C8b. |
| Animations | Follow /docs/ANIMATIONS.md exactly (snap=120, fast=180, normal=280, slow=400; constants in core/animations/constants.dart); all disableable via MediaQuery.disableAnimations |
| Tone | gentle/harsh stored in prefs, affects display strings ONLY (not logic) |

---

## 🚫 MANDATORY anti-regression rules (READ + ENFORCE every UI task)

The two recurring bug classes in this project are **untranslated English text** and
**RenderFlex "BOTTOM/RIGHT OVERFLOWED BY N PIXELS"**. They are now BLOCKING: do not
finish a UI task until both gates below pass. No exceptions, including "content" data.

### A. Localization — NO hardcoded user-facing text, ever
- Every string the user can see goes through `context.s('key')`. This **includes content
  data**, not just labels: meditation sessions, posture exercises, food staples, canned
  advice, survey options, etc. A `const` list of English `name`/`steps`/`description`
  strings is a BUG — store l10n **keys** in the data class and resolve with `context.s()`.
- Units and counts use the plural/format helpers (`plMinutes`, `plSteps`, `plSeconds`,
  `intl`), **never** string concatenation with English words like `'$mins min'` or
  `'$seconds sec'` — those never translate.
- When you add a key, add it for **all** active languages (at least `en` + `ru`). The
  l10n system falls back to `en` silently, so a missing `ru` value renders as English and
  reads as "half the app is in English". Missing ≠ visible error — you must check.
- **Gate (run before finishing, fix every user-facing hit):**
  ```bash
  rg -n "(Text|hintText:|labelText:|title:|tooltip:|label:)\s*\(?\s*['\"][A-Za-z]" app/lib --glob '!**/l10n/**' --glob '!**/*.g.dart'
  rg -n "'\\\$[a-zA-Z]+ (min|sec|hours?|days?|items?|steps?)'" app/lib   # hardcoded units
  ```

### B. Overflow — every screen must survive small width, big text, and the keyboard
- Any `Row`/`Column` with text wraps the flexible child in `Expanded`/`Flexible` with
  `overflow: TextOverflow.ellipsis` (or `FittedBox`/`scaleDown` for fixed-size circles).
- **Keyboard rule:** on any screen with a text field, the layout must shrink when the
  keyboard opens. Do not place a tall fixed-height widget (expanded calendar, big header,
  hero image) above an `Expanded` in a column that the keyboard squeezes — collapse it,
  make it scrollable, or hide it while a field is focused. (This is the Plan-search bug.)
- **Test EVERY screen at all three:** width **320px**, `textScaleFactor` **1.5–2.0**, and
  **keyboard open** (if it has any input). A change isn't done until checked at these.
- Prefer a widget test that pumps the screen small + large-text and asserts
  `tester.takeException() == null` (no overflow). Put it next to the feature's tests.

### C. Commit discipline (so fixes don't silently regress)
- After a fix is verified (`flutter analyze` = 0 + the gates above), **commit and push it**
  on the working branch — do not leave verified work uncommitted across sessions. An
  uncommitted fix that "we discussed before" but reappears = it was never committed.
