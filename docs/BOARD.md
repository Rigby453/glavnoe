# Kaizen («Главное») — Board

> Lightweight status board. Orchestrator updates this after every block of work.
> Statuses: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked
> Full task detail lives in `/docs/agents/*-tasks.md`.

## Текущая фаза: Ф1 (платный контур) — ЗАКРЫТА 2026-06-11 (кроме OAuth)
Весь порядок выполнен: Water → Баланс → штрихкод → AI-03 фото → Wrapped (+AI-05) →
список покупок → анимации §5/§7 → RevenueCat-срез (ADR-028) → рецепты →
«Собрать ИИ» (AI-07) → голос. Ресторан-меню → Ф3 (ADR-029).
Остаток: OAuth Google/Apple (нужны аккаунты сторов — на пользователе);
утром с пользователем: живая проверка на телефоне (особенно голос) +
отложенный им бэклог (онбординг, тайминги анимаций).

## В работе
- [x] Аудит всего проекта (2026-06-10): полный отчёт — **docs/AUDIT.md** (реализовано/в процессе/не начато/баги/техдолг)
- [x] Ф1 — Water: анимированный стакан §4.2 + график 7 дней + настраиваемая норма (2026-06-10)
- [x] Ф1 — Food: баланс рациона (rule-based, unit-тесты) + сканер штрихкода + поиск OFF (2026-06-10)
- [x] Ф1 — AI-03 еда по фото: бэк (premium, 3/день) + Flutter UI камера/галерея (2026-06-10, 47fa586)
- [x] Ф1 — Wrapped Неделя/Месяц + AI-05 абзац on-demand (ADR-026) (2026-06-10, 6542c90)
- [x] Ф1 — список покупок (SPEC C5, 2026-06-10, a05b448): Drift v4 shopping_items + DAO + экран /shopping (добавление, галочки, свайп-удаление с Undo, Clear checked) + корзина на Food; локально, без синка (синк/доставка — Ф3)
- [x] Ф1 — анимации §5 «День завершён» (2026-06-10): CelebrationOverlay переписан — зелёный фон #1D9E75 @95%, галочка 96px (path draw + elasticOut), заголовок fade+slide, burst-конфетти из центра (радиальная физика + гравитация, без пакетов), стрик bounce 1→1.3→1; один контроллер 2300мс + Interval-ы; тап или 4с → fade-out; reduce motion
- [x] Ф1 — анимации §7 AI-состояния (2026-06-10): ai_pulse_dot (§7.1) + ai_skeleton shimmer без пакетов (§7.2) + ai_insight_reveal (§7.3) в core/animations; подключены: wrapped (skeleton+reveal), morning/evening review (pulse+reveal), diary (pulse), food AI-фото (pulse+reveal — хвост доделан оркестратором, субагент оборвался)
- [x] Ф1 — AI-07 «Собрать ИИ» бэкенд (2026-06-11): POST /api/v1/ai/menu-build (premium) — клиент шлёт СВОИ продукты/рецепты (имя + КБЖУ/100г) и цели, модель возвращает только name+grams по приёмам + note; числа пересчитывает клиент; фильтр галлюцинаций по списку кандидатов; api-spec дополнен; jest ai 10/10. Подключение в клиент — после рецептов. Примечание: ai-субагент завис (watchdog 600s), эндпоинт сделан оркестратором
- [x] Ф2 — Sleep-трекер (SPEC C5, 2026-06-11, 832cdc6): Drift v6 sleep_logs + SleepDao (открытая ночь, идемпотентный startNight) + sleep_stats (чистые, юниты: через полночь, мультисегмент) + карточка в Health («Going to bed»/«I'm awake» + график недели, ≥7ч подсветка). Health Connect/Apple Health — позже отдельно
- [x] Ф3 — веб-шеринг плана, клиент (2026-06-11): карточка «Share my week» в профиле — POST /share на 7 дней вперёд → ссылка в буфер обмена + снэкбар; офлайн-режим → «Sign in to share». Попутно стабилизирован flaky-тест порядка сессий (секундная точность Drift). flutter test 94/94
- [x] Ф3 — веб-шеринг плана, бэкенд (SPEC C7, 2026-06-11, ADR-030): POST /api/v1/share (JWT purpose:share, 7 дней, диапазон ≤31 дня) + публичный GET /share/:token (HTML-страница в стиле Focus, escapeHtml) и GET /api/v1/share/:token (JSON без id/приватных полей). Без таблицы/миграции. Фикс: Fastify maxParamLength 100→1000 (роутер не матчил URL с ~300-символьным JWT — валидные ссылки давали 404). Субагент завис — дотипизирован и отлажен оркестратором. jest 80/80 (+8 share)
- [x] Ф2 — Workouts 2/2: режим «тренер» + сессии (SPEC C5, 2026-06-11): Drift v8 workout_sessions (имя-снапшот, finishedAt null = прервана) + start/finish/watchRecent в DAO (3 юнита) + /workouts/:id/train (подход → отдых с отсчётом и Skip → следующее упражнение → «Did it as planned! · N min»; Stop с подтверждением не финиширует сессию) + Start workout в редакторе + History в списке. Видео/голос тренера — позже (нет контента). Субагент оборвался (без build_runner) — генерация/роут/кнопки/история доделаны оркестратором. flutter test 94/94
- [x] Ф2 — Workouts 1/2: база+редактор (SPEC C5, 2026-06-11): Drift v7 (workouts + workout_exercises: подходы/повторы/вес/отдых/техника) + WorkoutsDao (8 юнитов) + /workouts (шаблоны) + /workouts/:id (редактор упражнений, диалог, свайп-удаление) + карточка в Health (секция «скоро» опустела и убрана). Под-блок 2: режим «тренер» + сессии «Сделал по плану»
- [x] Ф2 — осанка (SPEC C5, 2026-06-11): 6 текстовых упражнений (posture_exercises) + /posture экран (ExpansionTile-инструкции) + тумблер напоминаний «Sit up straight» каждые 2 ч 10:00–18:00 (id 301-305, канал kaizen_posture Importance.low — утренние/вечерние разборы не задеты). Живая проверка уведомлений — на телефоне утром
- [x] Ф2 — дыхательные сессии (SPEC C5, 2026-06-11): breathing_engine (пресеты Box 4-4-4-4 / Calm 4-7-8 / Simple 5-5, phaseAt — юниты) + /breathing экран (круг растёт/сжимается по фазе, 1/3/5 мин, reduce motion) + карточка в Health. Аудио/видео-контент — позже (нет CDN). Субагент оборвался — роут/плитка доделаны оркестратором. flutter test 83/83
- [x] Ф1 — голосовой ввод еды (SPEC C5, 2026-06-11): speech_to_text (локальное распознавание, без AI-бэкенда), кнопка-микрофон в шите поиска еды → надиктованный текст в строку → авто-поиск; разрешения Android (RECORD_AUDIO + queries) и iOS (mic+speech) прописаны; flutter build apk --debug собрался. ЖИВАЯ ПРОВЕРКА НА ТЕЛЕФОНЕ — утром с пользователем
- [x] Ф1 — «Собрать ИИ» клиент (SPEC C5, 2026-06-11): кнопка на Food → кандидаты из рецептов + недавних продуктов (ai_menu.dart, дедуп, мин. 5) → /ai/menu-build → предложение по приёмам с числами, ПЕРЕСЧИТАННЫМИ КОДОМ из локальных данных (страховка от галлюцинаций: чужие позиции отбрасываются) → [Log all] пишет в food_logs. §7-анимации (pulse/skeleton/reveal), premium-гейт. flutter test 58/58
- [x] Ф1 — рецепты из ингредиентов (SPEC C5, 2026-06-11): Drift v5 (recipes + recipe_ingredients со снапшотом КБЖУ на 100 г) + RecipesDao + recipe_nutrition (чистые totals/per-100g, юниты) + экраны /recipes (список) и /recipes/:id (редактор: поиск OFF → граммы, итоги, «Log this recipe» → обычная строка food_logs, синк уже работает) + вход с Food. Субагент завис на середине — экраны/тесты доделаны оркестратором. flutter test 54/54
- [x] Ф1 — RevenueCat-срез (2026-06-10, ADR-028): PurchaseService-абстракция (purchase_service.dart) + StubPurchaseService (debug: Subscribe сам зовёт dev-upgrade — отдельная Dev-кнопка удалена; release: «coming soon») + Restore purchases; реальный RevenueCat = одна строка в провайдере. Попутно: восстановлены потерянные заголовки ADR-022..025 в decisions.md
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
- [x] AI-03 food photo (2026-06-10, 47fa586): /ai/food-recognize (vision → блюдо+порция, числа из OFF, лимит 3/день) + Flutter «AI photo (Premium)» (камера/галерея). Тесты: гейтинг + 429 на 4-й вызов.
- [x] AI-05 wrapped summary (2026-06-10, 6542c90): /ai/wrapped-summary on-demand (ADR-026, числа считает клиент) + кнопка «AI recap» в Wrapped (Неделя/Месяц toggle).
- [x] Food module (Phase 1, C5): OFF integration (src/food/) + /food/barcode + /food/search · Drift food_logs + sync (ADR-024) · Food screen (поиск → граммы/приём → лог; итоги дня ккал/Б/Ж/У + сахар/клетчатка) · баланс рациона rule-based (unit-тесты) · сканер штрихкода · AI-фото. Осталось из C5: список покупок, рецепты/меню ИИ, ресторан, голос.
- [x] AI provider abstraction (src/ai/provider.ts): Gemini (REST, cheap model via GEMINI_MODEL) or Anthropic, chosen by which key is set — swap by .env. All 4 features refactored; tests still green (mock features).
- [x] Paywall UI (C7): /paywall screen ($10/mo, benefits) + Profile premium card + AI upsell snackbars link to it. Real payments = Phase 1; dev-only POST /subscription/dev-upgrade (404 in prod, kDebugMode button) flips tier so AI is testable. 50/50 backend tests.

## MVP Definition of Done
A free, no-AI app you use daily: accounts + sync, Today/Plan/Diary, rule-based review
(morning + evening + variants), schedule import, streaks + freeze, onboarding,
themes Focus/Black/White, home widget. All QA suites green.
