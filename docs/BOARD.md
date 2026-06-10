# Kaizen («Главное») — Board

> Lightweight status board. Orchestrator updates this after every block of work.
> Statuses: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked
> Full task detail lives in `/docs/agents/*-tasks.md`.

## Текущая фаза: MVP (добивка) — блоки 1–6

## В работе
- [x] Миссия 0: аудит и наведение порядка в доках (2026-06-10) — см. «Решения» ниже
- [x] Блок 1 — AI живой (2026-06-10): ключ добавлен пользователем; дефолтная gemini-2.0-flash-lite отдавала 429 quota=0 (модель выведена для новых ключей) → дефолт и .env подняты до gemini-2.5-flash-lite (ADR-025). Все 4 эндпоинта проверены вживую premium-пользователем: /ai/morning-message (тон harsh, персонально) · /ai/redistribute (3 валидных варианта плана по реальным item id) · /ai/diary-insight (инсайт по паттернам настроения) · /ai/schedule-import (multimodal: прочитал все 4 пары из сгенерированного PNG-расписания). Модели по ТЗ: на Gemini-пути обе ступени = дешёвая модель (ADR-022); Anthropic-путь (haiku/sonnet) активируется ключом
- [x] Блок 2 — сеть на телефоне: scripts/run-phone.ps1 (LAN IP → --dart-define=API_BASE_URL) + START.md; IP-детект и health-check проверены, телефон 2311DRK48G виден flutter (2026-06-10)
- [x] Блок 3 — анимации MVP по /docs/ANIMATIONS.md (2026-06-10): §0 constants.dart · §1.1/1.2 Pressable (scale/lift карточек) · §2.3 AnimatedCheck (path-галочка + strikethrough fade; фикс: единая обёртка Dismissible чтобы переход ловился) · §3 тосты ×3 (done/deadline/removed+Undo; Undo вставляет копию с новым id из-за tombstone ADR-021; deadline-вариант готов, триггер придёт с пер-дедлайн уведомлениями) · §4.1 кольцо 400ms+пружина · §8.1 кроссфейд вкладок 150ms · §8.2 showAppSheet 320/220ms (кривые шита не задаются через AnimationStyle — отмечено в коде) · §10 reduce motion везде. Примечание: 2 субагента упёрлись в лимит сессии — хвосты доделаны оркестратором
- [x] Блок 4 — food_logs sync (2026-06-10): контракты (api-spec FoodLog + SyncRequest/Response, data-model, ADR-024) · Prisma FoodLog + миграция add_food_log (применена пользователем через migrate deploy) · sync.ts append-логика + serializeFoodLog · клиент: ApiClient.sync(foodLogs) + SyncService отправка/мёрж · живой roundtrip через /sync проверен · jest 67/67
- [x] Блок 5 — онбординг как единый поток (2026-06-10): слайды → auth (+ Google/Apple заглушки, OAuth=Phase 1 TODO) → /setup из 6 шагов (интересы → импорт расписания (открывает ImportSheet) → время разборов (часы пишутся в prefs и применяются к уведомлениям, в т.ч. при старте) → тон → тема → норма воды). Норма воды стала настраиваемой (water_goal_provider, Health читает). Redirect роутера держит на /setup до завершения; «Skip all» доступен. flutter analyze 0, flutter test 22/22
- [x] Блок 6 — тесты (2026-06-10): виджет-тесты Today×2/Plan/Diary с in-memory Drift (AppDatabase.forTesting; уроки: реальные await к Drift в testWidgets — только через tester.runAsync, иначе дедлок fakeAsync; в конце теста размонтировать дерево, чтобы zero-таймеры drift не висели) · food sync — 4 jest-теста (Блок 4) · AI с моками — было (44 кейса). Итог: flutter test 26/26, jest 67/67, analyze 0

## Блокеры
- нет. (add_food_log применена 2026-06-10, /sync живой)

## MVP-добивка (блоки 1–6): ЗАВЕРШЕНА 2026-06-10 — фаза ждёт ревью пользователя

## Ревью MVP (2026-06-10) — фидбек пользователя
Починено сразу:
- [x] add_task_sheet: «BOTTOM OVERFLOWED BY 112 PIXELS» с клавиатурой → SingleChildScrollView
- [x] Размер текста: «Larger» → «Extra large»
- [x] Поиск еды не находил ничего: легаси OFF cgi/search.pl стабильно 503 → переехали на search.openfoodfacts.org (search-a-licious; hits[], brands массивом)
- [x] Версия приложения в профиле (package_info_plus, «Version 1.0.0 (2) · debug»); build bumped до +2
- [x] run-phone.ps1: UTF-8 BOM (PS 5.1 ломал кириллицу без BOM)

Бэклог по указанию пользователя (НЕ делать до закрытия остального ТЗ):
- [ ] Онбординг-настройка «поработать в начале»: норма воды из параметров пользователя (не вручную), стрелка «назад» между шагами, + будущие правки пользователя
- [ ] Анимации: конфетти слишком быстрое; пройтись по таймингам/лагам на реальном устройстве — «после всего ТЗ»

## Решения (мини-ADR, полные — в /docs/decisions.md)
- 2026-06-10: Миссия 0 — animations_tz.md → ANIMATIONS.md (источник истины по моушену);
  тайминги в design-tokens.json приведены к ANIMATIONS.md (ADR-023); доки про AI приведены
  к ADR-022 (Gemini default); ITEMS-03 403→404 (по ADR-014); data-model.md дополнен Tombstone;
  START.md переписан в актуальный указатель.

---

## Foundations (do first — everyone depends on these)
- [x] Product spec — `docs/SPEC.md`
- [x] Data model + Prisma — `docs/data-model.md`
- [x] API contract — `docs/api-spec.yaml`
- [x] Design tokens — `docs/design-tokens.json`
- [x] Orchestration + agent guides — `AGENTS.md`, `*/CLAUDE.md`

## Backend (see docs/agents/backend-tasks.md)
- [x] SETUP-01 Project scaffolding (Fastify + TS)
- [x] SETUP-02 Prisma schema + migration
- [x] SETUP-03 Fastify server + health check
- [x] AUTH-01..04 Register / Login / JWT middleware / Me
- [x] ITEMS-01..04 CRUD + ownership
- [x] STREAK-01..02 Get streak + update helper
- [x] SYNC-01 Sync endpoint (last-write-wins); recomputes streak when a main item transitions to done (regression fix — previously only PATCH /items did); + water_logs sync + deleted_item_ids (server deletes owned items) + day_logs sync (upsert by user+date, LWW; DayLog.updatedAt migration on Neon); also syncs water logs (append-only, ADR-017)
- [x] ENGINE-01 Rule redistribution (POST /api/v1/redistribute)

## Flutter (see docs/agents/flutter-tasks.md)
- [x] FL-SETUP-01..03 Project + Focus theme + 4-tab nav (profile = AppBar leading)
- [x] FL-DB-01..02 Drift schema + DAOs
- [x] FL-TODAY-01..05 Today screen (ring, streak, list, add sheet)
- [x] FL-PLAN-01..02 Week strip + day timeline + Day/Week/Month view toggle (week agenda; month calendar with task dots, tap day → day view) + "Clone week → next" (copies the week's events to next week, C4 schedule import)
- [x] FL-DIARY-01 Diary form + morning review carry-over card + free rule-based weekly insight (local: % main closed, streak, top blocker, avg mood) + "Today: plan vs fact" card (planned/done/skipped)
- [x] FL-API-01 / FL-SYNC-01 Dio client + sync service
- [x] Auth screen (login/register + offline mode) + router redirect + live sync on login
- [x] Themes Black + White (+ theme picker in Profile); Focus default. calm/contrast = stubs
- [x] Schedule import — paste/template (text → tasks) via Plan. photo/voice = AI Phase 1
- [x] Onboarding flow (first-run 3-slide intro → auth)
- [x] All 5 themes (Focus/Calm/Black/White/Contrast, contrast 1.15 type scale) + picker
- [x] Home widget (Android) — native AppWidgetProvider + MethodChannel bridge; verified on a real device (shows main progress + streak, tap opens app). iOS widget needs a Mac.
- [x] Extras: tone toggle gentle/harsh (tone-aware copy) · morning-review rule-based plan variants (free) · focus sessions incl 67/15 · weekly wrapped (rule-based) · exam/deadline countdown · Health water tracker · profile streak/freeze card · confetti celebration when all main tasks are closed (signature B4 element) · 401 → /auth redirect
- [x] Streak now actually works: offline-first client computation (StreakService, idempotent, mirrors backend rules) writes local StreakTable on main-task completion → Today/Profile show real streak (was always 0)
- [x] Evening review (SPEC C3): "Plan tomorrow" card (evening, ≥17:00) on Today — carry today's unfinished into tomorrow + rule-based variants (free) + AI smart plan (/ai/redistribute tomorrow, premium). Shared review_engine with morning review.
- [x] Local notifications: flutter_local_notifications + timezone; daily morning (08:00) & evening (20:00) review reminders (inexact, no exact-alarm perm); Profile "Daily reminders" toggle (requests permission), reschedule on app start. Android desugaring + POST_NOTIFICATIONS. APK builds; firing needs on-device check.
- [x] Task duration picker (15m–2h) in add/edit sheet
- [x] Recent-subjects quick-pick for events/exams in add-task (C4; prefs-backed, no migration; mergeRecent unit-tested)
- [x] Delete a task: edit-sheet Delete action + offline-first delete-sync (SyncQueue tombstones → /sync deleted_item_ids; fixes "deleted tasks reappear"; activates the dead SyncQueueTable)
- [x] Cross-device delete propagation: backend Tombstone table → /sync returns deleted_item_ids (deletes from other devices) → client applies locally. DELETE /items also tombstones. Closes the ADR-019 limitation. 57/57 backend tests.
- [x] Profile Settings (C7): default-tone selector + Text size (accessibility, global textScaler, generalizes the Contrast bump); Profile made scrollable

## QA (see docs/agents/qa-tasks.md)
- [x] QA-01 Auth flow
- [x] QA-02 Items CRUD
- [x] QA-03 Streaks
- [x] QA-04 Redistribution engine
- [x] QA-05 Sync conflict resolution
- [x] DoD: 36/36 tests pass (Jest+inject); engine coverage 100% lines (≥80% req); no AI calls (no ai/ code in MVP)
- [x] First Flutter unit tests: review_engine (slots, AI-plan mapping) + diary_insight (weekly insight, issue parsing) — 12 tests via flutter_test

## Landing (see landing/CLAUDE.md)
- [x] index.html — hero, problem/solution, features, pricing, footer
- [x] Smart [Download] button (platform detection)

## AI — Phase 1 (paid; see docs/agents/ai-tasks.md)
- [x] AI-06 Schedule import from photo (premium): /api/v1/ai/schedule-import + Claude Haiku multimodal in src/ai/ + premium gate + Flutter photo button. Tests mock ai/ (4/4). Live run needs real ANTHROPIC_API_KEY + a premium user.
- [x] AI-01 smart redistribute (/ai/redistribute, Sonnet, 2-3 plan variants) · AI-02 morning message (/ai/morning-message, Haiku, tone-aware) · AI-04 diary insight (/ai/diary-insight, Sonnet) — premium-gated, src/ai/, tests mock ai/ (44/44). Live run needs ANTHROPIC_API_KEY + premium user.
- [x] AI wired into Today UI: morning-review card now has "Smarter plan with AI (Premium)" (→ /ai/redistribute, applies variants locally) + "AI nudge" message button (→ /ai/morning-message). Premium-gated via isPremiumProvider; graceful snackbar for free/errors. (diary insight + photo import were already wired.)
- [ ] AI-03 food photo (needs food DB) · AI-05 weekly wrapped
- [~] Food module (Phase 1, C5): backend OFF integration (src/food/) + /food/barcode + /food/search (6 tests). Client: Drift food_logs (v3 migration), Food screen (search → grams/meal → log; day totals ккал/Б/Ж/У + sugar/fiber) in Health hub. Pure nutrition calc unit-tested. Next: barcode scanner (camera), AI photo/menu (premium), food-log sync.
- [x] AI provider abstraction (src/ai/provider.ts): Gemini (REST, cheap model via GEMINI_MODEL) or Anthropic, chosen by which key is set — swap by .env. All 4 features refactored; tests still green (mock features).
- [x] Paywall UI (C7): /paywall screen ($10/mo, benefits) + Profile premium card + AI upsell snackbars link to it. Real payments = Phase 1; dev-only POST /subscription/dev-upgrade (404 in prod, kDebugMode button) flips tier so AI is testable. 50/50 backend tests.

## MVP Definition of Done
A free, no-AI app you use daily: accounts + sync, Today/Plan/Diary, rule-based review
(morning + evening + variants), schedule import, streaks + freeze, onboarding,
themes Focus/Black/White, home widget. All QA suites green.
