# Flutter Tasks — MVP

> Complete in order. Each task has a clear deliverable.
> Reference: /docs/design-tokens.json + /docs/api-spec.yaml + /app/CLAUDE.md

---

## SETUP

### FL-SETUP-01: Create project + add dependencies
```bash
flutter create . --org com.kaizen --platforms ios,android,web
```
Update `pubspec.yaml` — add under `dependencies`:
```yaml
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
```
Under `dev_dependencies`:
```yaml
build_runner: ^2.4.0
drift_dev: ^2.18.0
riverpod_generator: ^2.4.0
```

### FL-SETUP-02: Focus theme
`lib/core/theme/focus_theme.dart`

Create `AppTheme` class with `ThemeData focusTheme`:
- `scaffoldBackgroundColor`: `Color(0xFF141009)`
- `colorScheme.surface`: `Color(0xFF241D11)`
- `colorScheme.primary`: `Color(0xFFD9F24B)` (lime accent)
- `colorScheme.onSurface`: `Color(0xFFF6EFE1)`
- `textTheme` — use `google_fonts.GoogleFonts.frauncesTextTheme()` for display
  and `google_fonts.GoogleFonts.hankenGroteskTextTheme()` for body

Create `ThemeProvider` (Riverpod) that reads/writes theme key to SharedPreferences.
All 5 theme keys match `/docs/design-tokens.json`: focus · calm · black · white · contrast.

### FL-SETUP-03: Router + navigation
`lib/core/router/app_router.dart`

Use `StatefulShellRoute.indexedStack` for 4 tabs:
- `/today` → `TodayScreen`
- `/plan` → `PlanScreen`
- `/health` → `HealthScreen`
- `/diary` → `DiaryScreen`

`ScaffoldWithNavBar` wrapper:
- `BottomNavigationBar` with 4 items
- `AppBar` with `leading: ProfileAvatarButton()` (navigates to `/profile`)

---

## DATABASE

### FL-DB-01: Drift schema
`lib/core/database/database.dart`

Tables (column names match `/docs/data-model.md`):
```dart
class ItemsTable extends Table { ... }       // all Item columns
class StreakTable extends Table { ... }       // current, longest, lastCompletedDate, freezeCount
class WaterLogsTable extends Table { ... }    // amountMl, loggedAt
class DayLogsTable extends Table { ... }      // date, mood, note, insight
class SyncQueueTable extends Table { ... }    // tableName, recordId, operation, payload
```

`@DriftDatabase(tables: [ItemsTable, StreakTable, WaterLogsTable, DayLogsTable, SyncQueueTable])`

Generate with: `flutter pub run build_runner build --delete-conflicting-outputs`

### FL-DB-02: DAOs
`lib/core/database/daos/items_dao.dart`
- `watchTodayItems(DateTime date)` — stream for Today screen
- `watchMainItems(DateTime date)` — stream for ring widget
- `insertItem(ItemsTableCompanion)` → returns id
- `updateItem(int id, ItemsTableCompanion)` → bool
- `deleteItem(int id)` → bool

---

## TODAY SCREEN

### FL-TODAY-01: Scaffold + AppBar
`lib/features/today/today_screen.dart`
- `AppBar`: greeting text (time-aware: morning/afternoon/evening), date, profile avatar leading
- `StreamBuilder` or `ref.watch` on today's items

### FL-TODAY-02: Ring widget
`lib/features/today/widgets/progress_ring.dart`
- `CustomPainter`: draw arc from 0 to `2π × (done / total)`
- Center label: `"$done/$total"` in Fraunces
- Animate with `AnimationController` (300ms, Curves.easeOut) when value changes
- If total = 0 → show full grey ring

### FL-TODAY-03: Streak row
`lib/features/today/widgets/streak_row.dart`
- Flame icon + `current` number
- 7 dots: filled accent / empty border for each of last 7 days

### FL-TODAY-04: Task list
`lib/features/today/widgets/task_list.dart`
- Section "Main today": items with priority=main, shield icon badge
- Section "Later": rest, chronological by scheduledAt
- `Dismissible`: swipe right = done (green), swipe left = skip (grey)
- Tap item = edit sheet

### FL-TODAY-05: Add task bottom sheet
`lib/features/today/widgets/add_task_sheet.dart`
- Title text field (autofocus)
- Type chips: task / event / exam / deadline
- Priority chips: low / medium / high / main
  - If user taps main and already 3 main items today → show snackbar "Max 3 main tasks"
- Date + time picker (default: today, next round hour)
- [Save] → `ref.read(itemsDao).insertItem(...)` → close sheet

---

## PLAN SCREEN

### FL-PLAN-01: Week strip
`lib/features/plan/widgets/week_strip.dart`
- `PageView` of weeks (swipe left/right)
- 7 day cells: day name + number; selected day highlighted with accent

### FL-PLAN-02: Day timeline
`lib/features/plan/widgets/day_timeline.dart`
- `ListView` of items for selected day, sorted by `scheduledAt`
- Each item card shows time + title + type badge

---

## DIARY SCREEN

### FL-DIARY-01: Diary form
`lib/features/diary/diary_screen.dart`
- Mood selector: 5 emoji buttons (1–5), tap to select
- Text field: "Anything interesting today?"
- "What went wrong?" chip group (multi-select):
  `social_media | went_out | was_tired | sick | other`
- [Save Day] → insert `DayLog` to Drift, show success snackbar

---

## API + SYNC

### FL-API-01: Dio client
`lib/services/api/api_client.dart`
- baseUrl from const (configurable via `--dart-define`)
- `InterceptorsWrapper`:
  - `onRequest`: add `Authorization: Bearer $token` from SharedPreferences
  - `onError`: if 401 → clear token, navigate to `/login`
- Methods for each endpoint in `/docs/api-spec.yaml`

### FL-SYNC-01: Sync service
`lib/services/sync/sync_service.dart`
- `syncNow()`:
  1. Read all items from `SyncQueueTable`
  2. `POST /api/v1/sync` with queued items + `last_sync_at`
  3. Merge `updated_items` response into local Drift DB
  4. Clear sync queue on success
- Call `syncNow()` on app resume (`AppLifecycleListener`)
