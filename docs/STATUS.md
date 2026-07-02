﻿# Kaizen («Главное») — Статус проекта

> Единственный файл «где мы сейчас / что осталось». Оркестратор обновляет его после каждого блока.
> *Что обещали* (продукт) — в `docs/SPEC.md`. Архитектурные решения — в `docs/decisions.md`.
> Статусы задач в журнале ниже: `[ ]` todo · `[~]` в работе · `[x]` сделано · `[!]` заблокировано.

## ⚠️ СВЕРКА РЕАЛЬНОСТИ 2026-07-02 (читать первым — ниже встречаются устаревшие блоки)

Пользователь указал на рассинхрон: то, что он делает вне репозитория (ключи на Render,
устные апдейты), не попадало в этот файл, а старые «ОСТАЛОСЬ»-блоки внизу не вычищались.
Актуальное состояние по спорным пунктам (перекрывает всё, что ниже):

- **ЮKassa — backend-код СДЕЛАН** (2026-07-02, ADR-067): `POST /api/v1/billing/yookassa/create-payment`
  (реальный вызов ЮKassa API) + реальный `/api/v1/billing/webhook/yookassa` (HMAC-подпись сырого
  тела + идемпотентность + `premiumUntil += 31д`). Ключи (`YOOKASSA_SHOP_ID`/`YOOKASSA_SECRET_KEY`/
  `YOOKASSA_RETURN_URL`) должны быть заданы на Render — без них 503. Цена `399.00` — **заглушка**
  (юнит-экономика не просчитана). **Осталось:** флаттер-пейвол на flutter-web, который вызывает
  `create-payment` и открывает `confirmation_url`.
- **RuStore — работает только с ИП**; у пользователя ИП нет → **отложен**. Прочие RF-стор-площадки
  пока тяжело. Для России платёжный путь = **ЮKassa (веб-оплата)**, не сторы.
- **Resend — `RESEND_API_KEY` и `RESEND_FROM` ЗАДАНЫ на Render** (сделано). Письмо сброса пароля
  работает. Проверить только «verified sender»: домен из `RESEND_FROM` должен быть подтверждён в
  дашборде Resend (DNS SPF/DKIM), иначе спам. Блок «ОСТАЛОСЬ: завести Resend» ниже — УСТАРЕЛ.
- **Groq — добавлен третьим ИИ-провайдером** (2026-07-02, ADR-063; `GROQ_API_KEY`→Gemini→Anthropic).
  Ждёт бесплатный ключ пользователя (console.groq.com/keys), чтобы включить вместо глючного Gemini.
- **Синк имени/аватара клиент+сервер — СДЕЛАН** (2026-07-02, ADR-064). Ниже блок «клиент — отдельная
  задача» и TODO(profile-name-sync) — УСТАРЕЛИ (клиент теперь пушит при правке + адоптит на старте).
- **Apple/Google IAP (заграница)** — по-прежнему нужны Dev-аккаунты + RevenueCat + ключи (не сделано).

Прочие фиксы 2026-07-02 (ветка night, запушены): красный-экран parse + правило + error-boundary;
time_grid мигание/мелкий блок; ИИ язык+именованные блюда; логика стрика (пересчёт из истории).

## Волна 6 / Этап 1 — ИИ-онбординг + quick-add, backend (2026-07-02)

Дизайн: `docs/AI-ONBOARDING-DESIGN.md`. Решения A/B/C — дефолты из QUESTIONS-DRAFT (premium-гейт
без триал-слоя; всегда превью, сервер не сохраняет; deadline мапит клиент).

- **[x] `backend/src/ai/onboardingPlan.ts`** — NEW. `generateOnboardingPlan({answers,date,timezone,language,languageCode})`
  по шаблону smartRedistribute: Zod, `withAiRetry`, `languageDirectiveForFields`, tier:'smart', json:true.
  Промпт: не выдумывать даты (только явные/относительные от date+timezone), main экономно. Постобработка:
  main ≤ 3 (лишние → high), фильтр пустых title.
- **[x] `backend/src/ai/quickAdd.ts`** — NEW. `generateQuickAddTask({text,date,timezone,...})` — одна задача
  из свободной фразы; тип/важность — авторитет модели; место → note.
- **[x] `backend/src/routes/ai.ts`** — POST `/api/v1/ai/onboarding-plan` + `/api/v1/ai/quick-add`
  (requireAuth + ensurePremium, snake_case ответ, aiError-классификация).
- **[x] `tests/integration/ai.test.ts`** — моки обоих модулей + 4 теста (403 free / 200 premium / 400×2).
  **16/16 passed** (~70 c). `npx tsc --noEmit` — 0 ошибок.
- **[x] `docs/api-spec.yaml`** — оба эндпоинта, аддитивно.
- **[x] Этап 2** (`ef64501`, см. блок ниже) · **[x] Этап 3** (`e758943`) — брейндамп-экран
  (VoiceTextField-холст + 6 гаснущих подсказок + согласие-диалог + premium-гейт) → превью плана
  (toggles включить/исключить, tap-to-edit через prefill) → пакетная запись Drift/Goals с лимитом
  main≤3/день. Вход: Профиль «Собрать план с ИИ» + маршрут /onboarding/brain-dump. Тесты 14/14.
  Страница-приглашение в setup_flow ОТЛОЖЕНА (жёсткие индексы PageView — TODO в setup_flow.dart).
  **Осталось:** Этап 4 — адверсариальное ревью промптов/схем.
- **Fix `tests/integration/sync.test.ts`** — ожидание стрика приведено к v2: волна 2 (cd04139)
  обновила engine+unit-тесты, но пропустила этот интеграционный тест; он ронял полный jest-прогон.

## Волна 6 / Этап 2 — ИИ quick-add, app (2026-07-02)

Дизайн: `docs/AI-ONBOARDING-DESIGN.md`. Решение B (всегда превью через `add_task_sheet`, сервер
ничего не сохраняет), решение C (deadline без scheduled_at → type=deadline).

- **[x] `app/lib/services/api/api_client.dart`** — `aiQuickAdd(...)` (используется) +
  `aiOnboardingPlan(...)` (задел под Этап 3), рядом с `aiRedistribute`.
- **[x] `app/lib/features/today/widgets/add_task_sheet.dart`** — новый `AddTaskPrefill` +
  опциональный параметр `prefill` в `showAddTaskSheet`/`AddTaskSheet` (не ломает существующие
  вызовы): предзаполняет title/type/priority/scheduledAt/durationMinutes для НОВОЙ задачи;
  `note` → поле «Место» (в `Items` нет отдельной колонки note); лимит main (≤3/день) соблюдается
  и для предзаполнения (тихий даунгрейд main→high при исчерпанном лимите).
- **[x] `app/lib/features/today/widgets/ai_quick_add_sheet.dart`** — NEW. `showAiQuickAddSheet`:
  premium-гейт (`isPremiumProvider`/`showPremiumUpsell`) ДО открытия листа → `VoiceTextField` →
  `/ai/quick-add` → `parseQuickAddResponse` (чистая функция, маппинг deadline) → превью через
  `showAddTaskSheet(prefill: ...)`. Ошибки 502/503 → снекбар с `Retry`; 403 → апсейл.
  Таймзона: `timezoneOverrideProvider` → `FlutterTimezone.getLocalTimezone()` → `'UTC'` fallback.
- **[x] Кнопка вызова** — вторичный `FloatingActionButton.small` (accent-контур, sparkle) над
  основным «+» на Today (`today_screen.dart`) и Plan (`plan_screen.dart`, mobile+tablet).
- **[x] l10n** — 9 новых ключей `today.ai_quick_add_*`, все 11 языков (en/ru/de/fr/it/pt/id/hi/ja/ko/es).
- **[x] `app/test/ai_quick_add_test.dart`** — 8/8 passed: юнит-тесты `parseQuickAddResponse`
  (deadline-маппинг, note, пустой заголовок) + виджет-тесты (320px/textScale 2.0 без overflow,
  успешный путь открывает предзаполненный `add_task_sheet`, ошибка API → снекбар+Retry).
- `flutter analyze` — 0 ошибок (8 предсуществующих info/warning в других файлах, не тронуты).
- **Дальше:** Этап 3 — брейндамп-экран онбординга (использует уже готовый `aiOnboardingPlan`);
  Этап 4 — верификация/адверсариальный ревью промптов.

## Feature — имя + аватар-пресет синкаются на сервер, backend-часть (2026-07-01)

Тот же класс бага, что и у профиля/КБЖУ ниже: `profile_identity_provider.dart` хранит имя и
аватар-пресет **только** в SharedPreferences — телефон и веб/новое устройство показывают разное
имя/аватар. `User.name` в БД уже был, но `PATCH /auth/me` его не принимал; аватар-пресета в БД не
было вообще. Backend-часть (ADR-064) готова; **клиент — отдельная задача** (заменить/дополнить
`profile_identity_provider.dart` синком через `GET/PATCH /auth/me`, см. TODO в шапке файла).

- **[x] `backend/prisma/schema.prisma`** — новое nullable-поле `avatarPreset String?` на `User`
  (без `@map`, как и все прочие поля `User` в этой схеме — колонка в БД тоже `avatarPreset`).
- **[x] Миграция `backend/prisma/migrations/20260701150000_add_user_avatar_preset/migration.sql`**
  — `ALTER TABLE "User" ADD COLUMN "avatarPreset" TEXT;`. НЕ применена к prod вручную — доедет
  через `prisma migrate deploy` в start command на Render (как и остальные миграции).
- **[x] `backend/src/routes/auth.ts`** — `updateMeSchema` принимает `name` (string, 1-255) и
  `avatar_preset` (string, max 64); `PATCH /api/v1/auth/me` мапит оба в `User.name`/`avatarPreset`.
- **[x] `backend/src/models/user.ts`** — `serializeUser` возвращает `avatar_preset` (snake_case) на
  `GET` и `PATCH /auth/me` (name уже отдавался).
- **[x] Контракт**: `docs/api-spec.yaml` (`name`+`avatar_preset` в теле `PATCH /auth/me` и в схеме
  `User`) и `docs/data-model.md` (таблица Users + embedded prisma-блок) обновлены.
- **Результат**: `npx prisma validate` — OK; `npx prisma generate` + `npm run build` (tsc) — 0
  ошибок. Интеграционные тесты `tests/integration/auth*.test.ts` **не запускались** — нет
  `DATABASE_URL_TEST`, а основной `DATABASE_URL` указывает на prod Neon (см. `backend/CLAUDE.md`);
  прогон оставлен оркестратору/QA-агенту с тестовой БД.
- **Следующий шаг (клиент, не в этой задаче):** `profile_identity_provider.dart` — читать/писать
  `name`/`avatar_preset` через `GET/PATCH /auth/me` вместо/вместе с prefs.

## Feature — профиль (антропометрия + цели питания/воды) синкается на сервер, backend-часть (2026-07-01)

Баг с устройства: телефон показывал 3000 ккал (введено пользователем), веб/новое устройство — 2000 (дефолт из
онбординга), потому что цель калорий/КБЖУ и антропометрия жили **только** в SharedPreferences на устройстве —
в модели `User` таких полей не было (тот же TODO, что и в `profile_identity_provider.dart` про имя/аватар,
см. строку 28 выше, но для более критичных данных). Это ADR-062, backend-часть готова; **клиент — отдельная задача**
(читать/писать эти поля через `GET/PATCH /auth/me` вместо/вместе с prefs, разово залить существующие локальные
значения на сервер при первом входе после обновления).

- **[x] `backend/prisma/schema.prisma`** — модель `User`: 13 новых nullable/default полей — `weightKg Float?`,
  `heightCm Int?`, `ageYears Int?`, `sex String?`, `activityLevel String?` (антропометрия); `foodGoal String?`,
  `calorieGoal Int?`, `macroOverrideEnabled Boolean @default(false)`, `macroKcalTarget Int?`, `macroProteinG Int?`,
  `macroFatG Int?`, `macroCarbsG Int?` (цели питания, с ручным override); `waterGoalMl Int?` (цель воды).
- **[x] Миграция `20260701143417_add_profile_sync_fields`** — применена на Neon через `prisma migrate deploy`
  (обычный `migrate dev` не сработал в неинтерактивном окружении; SQL сгенерирован через `prisma migrate diff`,
  подробности в ADR-062). `prisma migrate status` → up to date.
- **[x] `backend/src/routes/auth.ts`** — `updateMeSchema` (Zod) принимает все поля в snake_case с границами
  (`weight_kg` 20-400, `height_cm` 50-260, `age_years` 5-120, `sex` enum, `activity_level` enum, `food_goal` enum,
  `calorie_goal`/`macro_kcal_target` 800-6000, `macro_protein_g`/`macro_fat_g`/`macro_carbs_g` 0-1000,
  `water_goal_ml` 200-8000); `PATCH /api/v1/auth/me` обновляет только переданные поля, теперь может вернуть `400`.
- **[x] `backend/src/models/user.ts`** — `serializeUser` возвращает все 13 полей в snake_case и на `GET`, и на
  `PATCH /auth/me`.
- **[x] Контракт**: `docs/api-spec.yaml` (схема `User` + тело `PATCH /auth/me`) и `docs/data-model.md` (таблица
  Users + embedded prisma-блок) обновлены точно под новые поля.
- **[x] `tests/integration/auth.test.ts`** — 6 новых тестов (defaults=null/false на GET; PATCH антропометрии+целей
  → GET отражает; PATCH ручного macro-override; 400 на выход за границы; 400 на невалидный enum).
- **Результат**: `npx tsc --noEmit` — 0 ошибок. Полный backend-набор **370/370 passed** (28 suites), включая новые.
- **Следующий шаг (клиент, не в этой задаче):** заменить/дополнить SharedPreferences-хранение цели калорий/КБЖУ и
  антропометрии на синк через `GET/PATCH /auth/me`, аналогично `onboarding_done` (ADR-055).

## Ночная автономная сессия 2026-07-01 — 9 агентов, 12 коммитов (ветка night, всё запушено)

Полный разбор фидбека двух тест-батчей + триаж 72 отложенных пунктов. Детали и хэши — в
`docs/TEST-SESSION-2026-06-30-batch2.md` и `docs/DEFERRED-TRIAGE-2026-06-30.md`.

**Сделано и верифицировано** (`flutter analyze` 0 ошибок · смоук 28/28 · overflow 59/59 · backend 365/365):
- **Еда:** правка КБЖУ залогированного блюда (`e941197`); расширенный редактор рецептов — описание/шаги/фото/видео, схема Drift v23 (`a104496`); live-поиск ингредиентов; backend-поиск — язык lc=ru + фикс бага 1-символа (`586d188`).
- **Дневник:** История — год-heatmap по настроению + правка любого прошлого дня (`8ac0743`).
- **Профиль:** имя + аватар-пресеты (`abb6b00`); убран дубль-раздел «Аккаунт», стрик-шер к Прогрессу, премиум-бейдж (`05389db`).
- **Health:** screen-time overflow без лимита + неверное «всего сегодня» (фильтр системных пакетов) + отключённые модули пропадают (`254f3b7`).
- **Вода/Сон:** отчёты день/неделя/месяц + кривая, недельный = среднее/день (`d3fc423`).
- **Онбординг:** единый поток (вход опционален) + наглядное демо + поле «откуда узнал» + пейвол текст B (`3df5fca`,`cb10980`).
- **ИИ:** диагноз падения меню = квота Gemini на smart-модели (flash); ретраи всем 8 функциям + классификация ошибок (`eacf7b5`, ADR-060). Фикс: `GEMINI_MODEL_SMART=gemini-2.5-flash-lite` на Render (пользователь добавил).
- **Backend:** отправка письма сброса пароля через Resend (`a151316`, ADR-059) — оживёт после вливания.

**Действия пользователя сделаны:** на Render добавлены `GEMINI_MODEL_SMART`, `RESEND_API_KEY`, `RESEND_FROM`.

**Зарезервировано на утро (с пользователем):** вливание `night`→`main`+редеплой (расхождение 8 коммитов, конфликты в backend/ai, передеплой прода — под присмотром); размытые задачи (#16, ядро); перетаскивание с 1 касания (#15) + синк стрика (#14); темы (2+акцент); иконка (v2-filled); Kai-плашка overflow (#23); медитация+дыхание (#19); глобальный поиск (#17); виджет (A1). Большое видение голос-ИИ — `docs/VISION-AI-VOICE-PLANNING.md`.

## Feature profile-name-avatar — редактируемое имя + аватар-пресеты в профиле (2026-06-30)

- **[x] `app/lib/features/profile/profile_identity_provider.dart`** — NEW. `AvatarPreset` enum (9 пресетов: default/cat/dog/bird/fish/leaf/rocket/star/sun, иконки Phosphor, цвет = accent текущей темы — без сетевых картинок). `ProfileIdentity{displayName, avatar}` + `ProfileIdentityNotifier` (Riverpod `Notifier`, SharedPreferences-ключи `profile_display_name`/`profile_avatar_preset`, по образцу `mascot_provider.dart`). Имя обрезается до `kProfileDisplayNameMaxLength=40`; пустая строка сбрасывает переопределение. **TODO(profile-name-sync)** в шапке файла: `PATCH /api/v1/auth/me` пока поддерживает только `onboarding_done` (см. `/docs/api-spec.yaml`) — имя/аватар хранятся устройство-локально, бэкенд-эндпоинт НЕ добавлялся (вне скоупа задачи).
- **[x] `app/lib/features/profile/profile_screen.dart`** — `_UserHeader` (шапка хаба) теперь `ConsumerWidget`: показывает `_AvatarCircle` по выбранному пресету + резолвленное имя (`resolveDisplayName()`: локальное переопределение → имя аккаунта → "You"/"Offline mode"), весь блок кликабелен → `/profile/account`. `ProfileAccountScreen` дополнена `_AvatarEditRow` (тап по кружку/кнопке "Change avatar" → `_AvatarPickerSheet`, модальный шит с `Wrap` из 9 пресетов, тап сразу применяет+закрывает) и `_NameEditRow` (карандаш → `_EditNameDialog`, контроллер в `State.initState`/`dispose` — паттерн из `NumberInputDialog`, во избежание краша «used after disposed»). Везде `Expanded`+`ellipsis` на длинных строках.
- **[x] `app/lib/core/l10n/strings/profile_paywall.dart`** — 8 новых ключей, все 11 языков: `profile.edit_name`, `profile.edit_name_title`, `profile.edit_name_label`, `profile.edit_name_hint`, `profile.name_updated`, `profile.edit_avatar`, `profile.choose_avatar_title`.
- **[x] `app/test/profile_identity_test.dart`** — NEW, 13 тестов: 6 unit (provider defaults/set/clear/clip-длины/setAvatar/персистентность через пересоздание `ProviderContainer`), 4 widget на `ProfileAccountScreen` (имя аккаунта без override; правка через диалог сохраняется в prefs и отображается; очистка поля возвращает имя аккаунта; выбор пресета в шите применяется+персистится), 3 overflow (320px×1.5 с длинным именем, 320px×2.0 офлайн, 320px×2.0 с открытым шитом аватара). Без pumpAndSettle (доп. `_settleDialog` helper для transition-анимаций диалога/шита). **13/13 passed.**
- **Зависимости**: не добавлялись — `image_picker` уже был в pubspec (используется в food/import), но для аватара выбран набор пресетов (без галереи/разрешений) по явной альтернативе из ТЗ.
- **Результат `flutter analyze`** на изменённых файлах: 0 ошибок.

## D1 — укрепление надёжности локальных уведомлений Android (2026-06-30)

- **[x] `app/android/app/src/main/AndroidManifest.xml`** — добавлены: `SCHEDULE_EXACT_ALARM` (точные будильники, пробивает Doze), `RECEIVE_BOOT_COMPLETED` (разрешение на приём BOOT_COMPLETED). Три receiver'а из `flutter_local_notifications`: `ScheduledNotificationReceiver` (без него zonedSchedule не срабатывал), `ScheduledNotificationBootReceiver` + intent-filter BOOT_COMPLETED/MY_PACKAGE_REPLACED/QUICKBOOT_POWERON (перепланирование после reboot), `ActionBroadcastReceiver` (кнопки в уведомлениях). Всё отсутствовало до D1.
- **[x] `app/lib/services/notifications/notification_service.dart`** — (A) `resolveScheduleMode(bool?)` top-level: null/true→exactAllowWhileIdle, false→inexactAllowWhileIdle. `_chooseScheduleMode()`: вызывает `canScheduleExactNotifications()`, деградирует в inexact при ошибке/не-Android. `requestExactAlarmsPermission()`: открывает системный экран настроек, возвращает актуальный флаг. Все 8 `zonedSchedule`-вызовов (reviews×2, posture×5, task, habit) заменены с хардкода `inexactAllowWhileIdle` → `await _chooseScheduleMode()` (один вызов на batch). (B) `rescheduleAllReminders({reviewsEnabled, morningHour, eveningHour, postureEnabled})`: пере-планирует reviews+posture при холодном старте. (C) Доставка через Doze теперь использует exactAllowWhileIdle с graceful fallback.
- **[x] `app/lib/core/l10n/strings/misc.dart`** — 2 новых ключа, все 11 языков: `notif.task_body` («Скоро начинается — приготовься») и `notif.task_title_fallback` («Напоминание») — убраны хардкод-строки из scheduleTaskReminder/scheduleHabitReminders.
- **[x] `app/lib/main.dart`** — `scheduleDailyReviews()` при старте заменён на `rescheduleAllReminders(reviewsEnabled, morningHour, eveningHour, postureEnabled)` — теперь перепланируются и posture-напоминания при reboot; добавлен import `kPostureRemindersKey`.
- **[x] `app/test/notification_schedule_mode_test.dart`** — NEW. 12 unit-тестов: 3 теста `resolveScheduleMode` (null/true/false), 4 теста `taskReminderId` (стабильность, разные id, диапазон ≥1M, пустая строка), 5 тестов `rescheduleAllReminders` (флаги reviews/posture/оба/ни одного/кастомные часы). `_FakeNotificationService` overrides init/scheduleDailyReviews/schedulePostureReminders — ни одного вызова MethodChannel.
- **Результат analyze**: 0 ошибок (2 pre-existing info в конструкторе). **Тест**: 12/12 passed, ~1с, не висит.

## Feature G2 Stage 2 — напоминание о резервном копировании (2026-06-30)

- **[x] `app/lib/features/today/widgets/backup_reminder_card.dart`** — NEW. Тихая закрываемая карточка-напоминание для гостей (офлайн-режим). Чистая функция `shouldShowBackupReminder({isGuest, launchCount, isDismissed}) → bool`. Провайдеры: `isGuestModeProvider` (guest=true когда authController=true + api.token=null), `backupReminderDismissedProvider` (StateProvider←prefs ключ `backup_reminder_dismissed`), `showBackupReminderProvider` (объединённое условие). Виджет: Phosphor `cloudArrowUp`, текст через l10n, кнопка «Войти» → `/auth`, крестик → dismissed=true+prefs. Overflow-safe: `Expanded`+`ellipsis`+`maxLines`. TODO-заглушка для будущего export через share_plus.
- **[x] `app/lib/features/today/today_screen.dart`** — `const BackupReminderCard()` добавлена первым элементом в ListView (`_TodayBody`), до `_QuietHeader`. При conditions=false → `SizedBox.shrink()`, вёрстка Today не ломается.
- **[x] `app/lib/core/l10n/strings/profile_paywall.dart`** — 5 новых ключей, все 11 языков: `backup.reminder_title`, `backup.reminder_text`, `backup.sign_in`, `backup.export` (stub), `backup.dismiss`.
- **[x] `app/test/backup_reminder_test.dart`** — 13 тестов: 7 unit-тестов чистой функции (все комбинации guest/launchCount/dismissed) + 4 widget-теста показа/скрытия (`isGuestModeProvider.overrideWithValue`) + 1 dismiss-тест (крестик → prefs флаг + карточка скрыта) + 2 overflow-теста (320px×textScale 2.0 и 1.5). Без pumpAndSettle; prefs через setMockInitialValues.

## Feature G1 — шер-карточка стрика (2026-06-30)

- **[x] `app/lib/features/today/widgets/streak_share_card.dart`** — NEW. `StreakShareCard` (квадратная 1:1 карточка: Phosphor `fire(fill)` ember + крупное число accent + подпись через `streak.share_text` + бренд-ватермарк; `FittedBox(scaleDown)` защита от overflow при textScale 2.0). `StreakShareModal` (нижний шит: предпросмотр карточки + кнопка «Поделиться»; логика: `RepaintBoundary→PNG→Share.shareXFiles` → при ошибке clipboard fallback + снэкбар). `captureCardAsPng(GlobalKey)` (рендер boundary в Uint8List, pixelRatio 3.0, тихий try/catch).
- **[x] `app/pubspec.yaml`** — добавлен `share_plus: ^10.0.0` (web+mobile, PNG через `XFile.fromData`).
- **[x] `app/lib/features/profile/profile_screen.dart`** — `_ShareStreakRow` (ConsumerWidget, `_NavRow` с Phosphor `fire(fill)` ember, читает `_streakProvider`, открывает `StreakShareModal`). Вставлен между `_ShareWeekRow` и `_SharedWithMeRow`.
- **[x] `app/lib/core/l10n/strings/profile_paywall.dart`** — 4 ключа, все 11 языков: `streak.share_btn` / `streak.share_title` / `streak.share_text` ({count}) / `streak.copied`.
- **[x] `app/test/streak_share_card_test.dart`** — 6 тестов: no-overflow 320px (textScale 1.0 и 2.0), no-overflow 400px textScale 2.0, число стрика на экране, стрик=0, стрик=1234 (длинный). Нативный Share не тестируется — только виджет.

## Feature B4 Stage 2 — перенос повторяющихся задач: UI-диалог + интеграция (2026-06-30)

- **[x] `app/lib/features/plan/widgets/recurrence_scope_dialog.dart`** — NEW. `enum RecurrenceEditScope { onlyThis, thisAndFuture, wholeSeries }` + `showRecurrenceScopeDialog(BuildContext) → Future<RecurrenceEditScope?>`. Нижний лист Kaname (R20, hairline 0.5, Phosphor-иконки calendarBlank/arrowRight/repeat). 3 опции + Cancel. Overflow-safe на 320px + textScale 2.0.
- **[x] `app/lib/features/today/widgets/add_task_sheet.dart`** — импорт `recurrence_scope_dialog.dart`. В `_save()/_isVirtualOccurrence`-ветке: если `_scheduledAt.h:m != origAt.h:m` → `showRecurrenceScopeDialog` перед `materializeOccurrence`. `null` → return (остаёмся в форме); `thisAndFuture` → `dao.rescheduleThisAndFuture` + pop; `wholeSeries` → `dao.rescheduleWholeSeries` + pop; `onlyThis` → существующий `materializeOccurrence` путь (все поля). Поведение без изменения времени не изменено.
- **[x] `app/lib/features/plan/widgets/time_grid.dart`** — TODO-комментарий в `_commitDrag` (drag-перенос виртуального повтора): объясняет, почему диалог пока не вызывается (async-safety drag-конвейера); приоритет — путь через форму.
- **[x] `app/lib/core/l10n/strings/today.dart`** — 4 новых ключа: `today.recur_scope_title`, `today.recur_scope_only_this`, `today.recur_scope_this_future`, `today.recur_scope_all`. Все 11 языков.
- **[x] `app/test/recurrence_scope_dialog_test.dart`** — 6 widget-тестов: no-overflow 320px+textScale2.0, тап onlyThis/thisAndFuture/wholeSeries возвращает правильный enum, Cancel → null, dismiss → лист закрывается.

## Feature B4 Stage 1 — перенос повторяющихся задач: логика и DAO (2026-06-30)

- **[x] `app/lib/features/plan/recurrence.dart`** — три новых чистых помощника: `timeOfDayDelta(oldDt, newDt) → Duration` (дельта времени суток), `splitHeadRule(rule, splitDate) → RecurrenceRule` (UNTIL=splitDate−1, EXDATE только прошлое), `splitTailRule(rule, splitDate) → RecurrenceRule` (без UNTIL/с унаследованным, EXDATE только будущее). Без зависимостей Flutter/Drift.
- **[x] `app/lib/core/database/daos/items_dao.dart`** — три новых публичных метода: `rescheduleSingleOccurrence(anchorId, date, newScheduledAt)` (делегирует materializeOccurrence с scheduledAt-override), `rescheduleThisAndFuture(anchorId, date, newScheduledAt)` (расщепляет серию: UNTIL якоря + новый якорь + копия шаблона подзадач + сдвиг будущих concrete-строк), `rescheduleWholeSeries(anchorId, newScheduledAt, {fromDate})` (сдвигает scheduledAt якоря + все / >= fromDate concrete-строки). Схема БД не изменена.
- **[x] `app/test/recurrence_reschedule_test.dart`** — 28 тестов (in-memory NativeDatabase): 4 теста `timeOfDayDelta`, 3 `splitHeadRule`, 6 `splitTailRule`, 3 `rescheduleSingleOccurrence`, 8 `rescheduleThisAndFuture`, 5 `rescheduleWholeSeries`. Прямой async, без pumpAndSettle.

## Feature B7 — autocomplete/подсказки тегов в форме создания задачи (2026-06-30)

- **[x] `app/lib/core/database/daos/items_dao.dart`** — новый метод `allUsedTags()`: читает все строки с тегами, split по запятой, trim+lowercase, подсчёт частоты, сортировка по частоте (убывание)+алфавит. Чистый Dart, build_runner не требуется.
- **[x] `app/lib/core/database/database_providers.dart`** — `allUsedTagsProvider` (FutureProvider) для публичного доступа к тегам из других потребителей.
- **[x] `app/lib/features/today/widgets/add_task_sheet.dart`** — `_allUsedTags` state + `_loadUsedTags()` + `_typingTagPrefix` (regex-детектор частичного `#tag` в конце заголовка) + `_tagSuggestions` (фильтр: исключить выбранные, фильтр по префиксу, лимит 20). В `build()`: `Builder` → `_TagSuggestionsRow` под `_TagChipsRow` (показывается когда есть подсказки). Новый виджет `_TagSuggestionsRow`: Phosphor `hash`-иконка + чипы surface+hairline-border, accent цвет текста, тап добавляет тег в `_tags`.
- **[x] `app/lib/core/l10n/strings/today.dart`** — ключ `today.suggested_tags` (11 языков).
- **[x] `app/test/tags_autocomplete_test.dart`** — 8 DAO unit-тестов + 3 виджет-теста: пустая БД, null-теги, дедупликация, нормализация lowercase, сортировка по частоте, trim, чипы рендерятся, тап добавляет тег, no overflow на 320px+textScale 2.0.

## Feature E2 — экран «Прозрачность Premium» (2026-06-30)

- **[x] `app/lib/core/widgets/premium_lock_badge.dart`** — NEW. Переиспользуемый виджет-таблетка `PremiumLockBadge` (Phosphor `lock(fill)` + метка «Premium» через l10n). Параметр `showLabel` для компактного использования (только иконка). Размещается рядом с любой premium-фичей на любом экране.
- **[x] `app/lib/features/paywall/compare_plans_screen.dart`** — NEW. `ComparePlansTable` — таблица «фича | Free | Premium» с иконками `check(fill)` / `lock(fill)`. 3 секции: Productivity (6 строк, все бесплатные) / Wellbeing (5 строк, бесплатные) / AI features (6 строк, Premium only). Hairline cards + hairline dividers (design-tokens). `ComparePlansSheet` — обёртка-шит (modal bottom sheet, R20, shadow, хэндл, заголовок, ✕). `showComparePlansSheet(context)` — публичная функция-открывалка.
- **[x] `app/lib/features/paywall/paywall_screen.dart`** — добавлена кнопка «Compare plans» (TextButton.icon + Phosphor `list`) в обоих layout (`_buildNarrow` / `_buildWide`), открывает `showComparePlansSheet`. `colorScheme` добавлен в оба builder-метода.
- **[x] `app/lib/core/l10n/strings/profile_paywall.dart`** — 20 новых ключей в секции `paywall.compare_*`: `lock_badge_label`, `compare_plans_btn`, `compare_plans_title`, `compare_col_free/premium`, `compare_section_productivity/wellbeing/ai`, `compare_tasks_planning`, `compare_priority_limit`, `compare_streaks`, `compare_review`, `compare_diary`, `compare_plan_sharing`, `compare_water`, `compare_sleep`, `compare_breathing`, `compare_workouts`, `compare_food_basic`, `compare_ai_insights`. Все 11 языков. AI-строки таблицы переиспользуют существующие `paywall.benefit_*_title` ключи.
- **[x] `app/test/premium_compare_test.dart`** — 7 тестов: 400px рендер (no exception), 320px антирегрессия overflow, 6 lock-иконок на AI-строках, 28 check-иконок на free+premium строках, ComparePlansSheet с заголовком и кнопкой ✕, PremiumLockBadge с иконкой и меткой, PremiumLockBadge(showLabel:false) без метки.

## Feature F1 — режим секундомера в фокус-сессии (2026-06-30)

- **[x] `app/lib/features/focus/focus_stopwatch_controller.dart`** — новый файл. Чистая Dart-логика: `start/pause/reset/tick/display`. Без зависимостей Flutter; тестируется изолированно.
- **[x] `app/lib/features/focus/focus_screen.dart`** — добавлен переключатель режимов (пилюли «Таймер» / «Секундомер» в Kaname-стиле с `accentTint`/`border`/Phosphor-иконками `timer`/`clockClockwise`). Idle секундомера: «00:00» в `textFaint`. Running секундомера: `_sw.display` (`mm:ss` / `h:mm:ss`) + `FontFeature.tabularFigures` + кнопки Пауза/Продолжить + Сброс (`arrowCounterClockwise`). Существующий таймер обратного отсчёта, пресеты, Kai ambient — не тронуты. PopScope и exit-диалог работают для обоих режимов.
- **[x] `app/lib/core/l10n/strings/misc.dart`** — 3 новых ключа (`focus.mode_timer`, `focus.mode_stopwatch`, `focus.btn_reset`), все 11 языков.
- **[x] `app/test/focus_stopwatch_test.dart`** — 15 unit-тестов для `FocusStopwatchController`: idle state, start, tick, pause, resume, reset, display (mm:ss / h:mm:ss переход на 3600 с), полный state machine.

## Feature C1 — онбординг: шаг «Откуда узнал?» (2026-06-30)

- **[x] `app/lib/core/l10n/strings/onboarding_quiz.dart`** — 10 новых ключей `onboarding_quiz.acq_*` (title/subtitle/cta/skip + 6 вариантов). Все 11 языков.
- **[x] `app/lib/features/onboarding/setup_flow.dart`** — новый шаг `_buildAcquisitionStep()` (индекс 13), `_pageCount` 14→15, `acquisitionSourceKey = 'acquisition_source'`, поле `_acquisitionSource`, сохранение в `_finish()` (null = не пишем). UI: 6 `_choiceTile` (Phosphor-иконки) + TextButton «Пропустить» внутри контента; стиль — Kaname (accent-border у выбранной карточки).
- **[x] `app/test/onboarding_steps_test.dart`** — `_summaryPage` 13→14 (саммари сдвинулся из-за C1).
- **[x] `app/test/acquisition_source_test.dart`** — 7 тестов: 3 widget (рендер 320px/textScale 2.0, 6 вариантов, тап без исключений) + 4 prefs-unit (round-trip 6 кодов, skip→ключ отсутствует, константа равна 'acquisition_source').

## Fix C3 — logout не чистил локальные данные (2026-06-30)

- **[x] `AppDatabase.clearAllUserData()`** — новый метод в `app/lib/core/database/database.dart`. Одна транзакция, удаляет ВСЕ строки из 23 пользовательских таблиц (items, streak, water_logs, day_logs, food_logs, sync_queue, shopping_items, recipes, recipe_ingredients, sleep_logs, workouts, workout_exercises, workout_sessions, goals, goal_steps, habit_logs, habits, item_attachments, subtasks, workout_set_logs, custom_breathing, custom_meditation, mood_logs). Схема/версия БД не затрагивается.
- **[x] `AuthController.logout()`** — теперь последовательно: clearToken → clearGuest → remove(kLocalPremiumUntilKey) → clearAllUserData() → state=false. Другой аккаунт не увидит чужих задач.
- **[x] `app/test/logout_clear_test.dart`** — 3 unit-теста на in-memory NativeDatabase: засев данных → clear → count==0 по 14 таблицам; идемпотентность; streak (без PK) очищается.

## Backend — YooKassa billing prep (2026-06-30, ADR-058)

- **[x] `backend/src/billing/yookassaWebhook.ts`** — HMAC-SHA256 stub для входящих вебхуков ЮKassa. `verifyYookassaWebhook(rawBody, headers)` + `computeYookassaSignature(rawBody, secret)`. Dev-режим без `YOOKASSA_WEBHOOK_SECRET`. 14 unit-тестов.
- **[x] `backend/src/billing/yookassaPayment.ts`** — Zod-валидация платёжного объекта ЮKassa (type / event / status / amount / metadata.user_id) + in-memory идемпотентность по payment_id. 24 unit-тестов.
- **[x] `backend/src/lib/rateLimiter.ts`** — `InMemoryRateLimiter` (fixed window). Синглтоны `webhookRateLimiter` (60/мин) и `publicRateLimiter` (20/мин). 14 unit-тестов.
- **[x] `backend/src/lib/deviceLimit.ts`** — лимит активных устройств на аккаунт (default 5, env `DEVICE_LIMIT`), in-memory Map-стаб. 24 unit-тестов.
- **[x] Live-интеграция ЮKassa (2026-07-02, ADR-067)** — `backend/src/billing/yookassaClient.ts` (новый, `createPayment` через реальный API ЮKassa, `kPremiumMonthlyRub='399.00'` заглушка-цена). `POST /api/v1/billing/yookassa/create-payment` (auth, rate-limit) + реальный `/api/v1/billing/webhook/yookassa` (`verifyYookassaWebhook` по raw-body HMAC + `validateYookassaPayment` + идемпотентность → `premiumUntil += 31д`, `premiumSource='yookassa'`). Raw body для HMAC — кастомный `addContentTypeParser` в `app.ts` (`request.rawBody`), без новых зависимостей. Канал `yookassa` выведен из общего каркаса-заглушки ADR-041 (apple/google/rustore/stripe там и остаются). Тесты: `tests/integration/billing-yookassa.test.ts` (новый). `npx tsc --noEmit` — 0 ошибок; jest не прогонялся этим агентом (правило проекта — не 2 раннера сразу), верификация тестами на оркестраторе. **Осталось:** UI-пейвол на flutter-web, который вызывает create-payment и открывает confirmation_url.
- **[ ] `Device` model в schema.prisma** — добавить при переходе от стаба к production device management.
- **[ ] `@fastify/rate-limit` + Redis** — заменить `InMemoryRateLimiter` при горизонтальном масштабировании.

## 🎨 Kaname Redesign — Phase 3 Today screen + add-task sheet (2026-06-28)

- **[x] Today restyle (Phase 3 §6 — today portion):** `today_screen.dart`, `widgets/add_task_sheet.dart`, `widgets/morning_review_card.dart`, `core/l10n/strings/today.dart`
  - `today_screen.dart` full rewrite: quiet header (date labelMedium+textMuted + greeting headlineSmall; gearSix→`/profile/appearance`, user-avatar circle→`/profile`). Thin Kai review row (`_KaiReviewRow` / `_KaiReviewCard`) shown only when `overduePendingProvider` has items OR evening (17+) + pending main; tapping expands inline Accept/Adjust/Leave card. `_MainCounter`: "Главное · X/Y" + up to 3 status dots. `_TodayTimeline`: unified time-ordered list of all today items interleaved by scheduledAt; mainPending/done/task/event nodes (Widget-based spine, no CustomPaint, for Dismissible compat); now-line; done items struck in place; hide/show completed toggle. All swipe logic (_doDone/_doSkip/_doSnooze/_doDelete with undo toasts) ported from task_list.dart. `CelebrationOverlay` preserved at 100%.
  - REMOVED from Today: ProgressRing hero, streak_row, 7-dot strip, big KaiMascot, two separate review cards, "Main today" section block, HabitsTodaySection rendering (files kept).
  - `add_task_sheet.dart` restyle (§4.4): Phosphor X close icon; Phosphor shield.fill in "main" hint; time OutlinedButton → `_TimeStepper` (±15min stepper, tap opens clock dialog); `_MainToggle` shield row (after priority chips, with max-3-main enforcement via `canSelect`); CategoryDot row (after MainToggle, shown when `categoriesEnabledProvider`+tags). New widget classes appended: `_TimeStepper`, `_StepButton`, `_MainToggle`. All existing parsing/saving/NL/subtask logic preserved.
  - `morning_review_card.dart`: renamed `_showMorningReviewSheet` → public `showMorningReviewSheet` (called from today_screen.dart via explicit `show` import).
  - l10n: 13 new keys added to `strings/today.dart` with all 11 languages: `today.morning_review_accept/adjust/leave`, `today.evening_review`, `today.now`, `today.main_counter_label`, `today.kai_review_text/moved`, `today.hide/show_completed`, `today.header_settings/profile_tooltip`, `today.main_toggle_label`, `today.category_dot_label`.
  - Anti-regression: all Riverpod providers preserved (`todayItemsProvider`, `todayMainItemsProvider`, `overduePendingProvider`); public widget APIs unchanged; no Material `Icons.` references in modified files; all text via `context.s()`; Expanded/ellipsis on all flexible text; `IntrinsicHeight` timeline rows survive 320px + textScale 1.5.

## 🎨 Kaname Redesign — Phase 3 Plan screens (2026-06-28)

- **[x] Plan restyle (Phase 3 §6):** `plan_screen.dart`, `day_timeline.dart`, `pinned_exam_card.dart`, `expandable_week_calendar.dart`, `month_view.dart`, `week_strip.dart`, `week_agenda.dart`, `year_view.dart`, `task_detail_card.dart`, `time_grid.dart`
  - `day_timeline.dart` full rewrite: replaces `_ItemCard`/`ListView.separated` with shared `TimelineList` + `TimelineEntry` (§4.1 spec). Mapping: `priority=='main'→mainPending`, `status=='done'→done`, `type=='event/exam/deadline'→event`, else `task`. CategoryDot via `item.tags` first tag. Module-link icons: `barbell/moon/timer/wind/flowerLotus/forkKnife` (Phosphor). Countdown Text(ember w600) as `trailing` widget for exam/deadline. Empty state: `calendarCheck(regular)` + `uploadSimple(regular)`. `dayItemsProvider` preserved unchanged.
  - `plan_screen.dart`: All Material icons → Phosphor: FAB `plus`, toolbar `caretDown` (date/view dropdowns), search `magnifyingGlass(regular/fill)` + `x` (clear), layout toggle `listBullets`/`squaresFour`.
  - `pinned_exam_card.dart`: `graduationCap`/`alarm`/`caretUp`/`caretDown` (Phosphor). Removed `.toUpperCase()` from type label (was violating NO ALL CAPS). `FontWeight.w700→w600` on ember label.
  - `expandable_week_calendar.dart`: `caretLeft`/`caretRight` navigation. Anti-regression `maxCalendarHeight` clamp kept. Keyboard rule (calendar hides when search visible) preserved.
  - `month_view.dart`: `caretLeft`/`caretRight`. Color stripes replaced with 6dp `_CategoryOrTypeDot` circle indicators (category color if tag present, else type/priority color). `taskStripeColor` kept as fallback. New `_CategoryOrTypeDot` widget added.
  - `week_strip.dart`: `FontWeight.w700→w500` for selected/today day numbers.
  - `week_agenda.dart`: `copy`/`barbell`/`moon`/`forkKnife` (Phosphor). Module link icons and clone-week button updated.
  - `year_view.dart`: `caretLeft`/`caretRight` navigation.
  - `task_detail_card.dart`: All Material icons → Phosphor (`x`/`clock`/`info`/`repeat`/`mapPin`/`check`/`minusCircle`/`pencilSimple`/`calendarX`/`broom`/`trash`/`listChecks`/`paperclip`). Removed 4dp left fill-bar; replaced with 10dp `CategoryDot` (from `item.tags`). Drag handle added (32×4dp, `textFaint@30%`). Sheet radius 16→20 (design-tokens). Title `FontWeight.w700→w500`. Removed `task_colors.dart` import (no longer needed). Added `phosphor_flutter` + `category_dot.dart` imports.
  - `time_grid.dart`: `FontWeight.w700→w500` for today day header; `w700→w600` for block content titles (colored block context); `w700→w600` for time-chip label. No Material `Icons.` refs were present.
  - Anti-regression kept: `_segmentsFit` clamp in plan_screen, `maxCalendarHeight` in expandable_week_calendar, tablet 2-column layout, search-collapses-calendar keyboard rule.

## 🎨 Kaname Redesign — Phase 5 Food screens (2026-06-28)

- **[x] Food restyle (Phase 5 §C):** `food_screen.dart`, `light_food_sheet.dart`, `ai_menu_sheet.dart`, `ai_menu.dart`, `food_icons.dart`
  - `food_screen.dart` full restyle: `_TotalsCard` (surface1 + 0.5dp hairline + R14, no shadow; calories in `colorScheme.primary`/headlineMedium; macro triplet via `food.macro_value_of`; Sugar=ember+PhosphorIcons.warning, Fiber=muted+PhosphorIcons.leaf); `_BalanceCard` (hairline card, no left fill-bar; balanced→`checkCircle(fill)+success`, hints→`lightbulb`+muted); `_FoodRow` (surface1 + R14 + hairline, dense Row + `FoodIconTile`; Phosphor `x` trailing; subtitle via `food.row_grams_kcal`).
  - Empty state: `KaiMascot(neutral, 64)` + `FilledButton.icon` (primary `food.empty_add_food`). ONE FilledButton per screen (§4.3).
  - FAB unified add sheet: search + voice (Phosphor `microphone`/fill) + barcode (Phosphor `qrCode`) + AI-photo premium (Phosphor `camera`, KaiLoader while loading) + from recipe (Phosphor `notebook`, routes to `/recipes`) + recent (tap=repeat log).
  - AppBar icons: `PhosphorIcons.notebook()` recipes, `PhosphorIcons.shoppingCart()` shopping.
  - AI menu/repeat week: secondary `TextButton.icon` rows (Phosphor `sparkle`/`clockCounterClockwise`); `_repeatLastWeek` copies food_logs from 7 days ago with Undo snackbar.
  - `ai_menu_sheet.dart`: Phosphor `sparkle`/`x`/`arrowsClockwise`/`check(fill)`/`info`; l10n totals row (`food.menu_totals_line`); l10n item line (`food.menu_item_line`); `KaiLoader` while building menu.
  - `light_food_sheet.dart`: Phosphor `x`/`magnifyingGlass`/`plus`; inline CircularProgressIndicator kept (search spinner, not AI).
  - `food_icons.dart`: Phosphor `forkKnife()` as fallback icon.
  - l10n: 7 new keys added to `food.dart` (`food.totals_kcal_goal`, `food.macro_value_of`, `food.row_grams_kcal`, `food.menu_totals_line`, `food.menu_item_line`, `food.empty_add_food`, `food.from_recipe_btn`); all en+ru (11 langs).
  - All Material icons removed from all 5 files. All strings via `context.s()`. Business logic, providers, DB/sync calls, public APIs preserved.

## 🎨 Kaname Redesign — Phase 5 Workouts screens (2026-06-28)

- **[x] Workouts restyle (Phase 5 §D):** `workouts_screen.dart`, `workout_editor_screen.dart`, `workout_trainer_screen.dart`, `exercise_history_screen.dart`, `exercise_detail_sheet.dart`, `ai_workout_sheet.dart`
  - Segment bar: custom `_SegmentBar` (surface + hairline + R12, accentTint underlay + accent text when selected) replaces `SegmentedButton`.
  - Program cards: `Material(surface1 + 0.5dp hairline + R14)` per §4.2; Phosphor `barbell(fill)` leading, `trash` (ember) delete, `caretRight` trailing.
  - FAB: `FloatingActionButton` with Phosphor `plus`; empty state uses `KaiMascot(neutral, 64)` + `FilledButton` (new workout).
  - Diary tab: past sessions in hairline-divided card (checkCircle(fill)+success icon, caretRight); exercise progress grouped by muscle in hairline-divided cards with chartLineUp icon.
  - Editor: `Material(surface1 + hairline + R14)` exercise cards; Phosphor `barbell`/`pencilSimple`/`chartLineUp`/`trash`/`plus`/`play(fill)`; KaiMascot(neutral,64) empty state.
  - Trainer: work phase — big `displaySmall` exercise name, `barbell(fill)` decorative, accent `FilledButton` "Done" (h52, R12); rest phase — big mono timer `displayLarge` + `FontFeature.tabularFigures`, ember color at ≤10s, Phosphor `minus`/`plus` adjusters, fact steppers with Phosphor `minus`/`plus`; done screen — `KaiMascot(success, 80)` replacing check_circle icon.
  - Exercise detail sheet: Container (surface + R20 top + soft shadow), handle, Phosphor `x` close, `barbell(fill)` muscle chip, `wrench` equipment, `chartBar` difficulty, `playCircle` video, `warning` mistakes; chips are surface + 0.5dp hairline (no filled color).
  - AI workout sheet: Container (surface + R20 + soft shadow), handle, Phosphor `barbell(fill)`/`x`/`lightning(fill)`/`sparkle`/`warningCircle`; choice chips — accentTint + accent border when selected (§4.3); `_Stepper` uses bordered icon buttons; `KaiLoader` for AI loading.
  - All Material icons removed. Weight units via `context.s('workout.weight_short')` (no hardcoded "kg"). All strings via `context.s()`. Business logic, providers, public APIs preserved.

## 🎨 Kaname Redesign — Phase 5 Breathing screens (2026-06-28)

- **[x] Breathing restyle (Phase 5 §E):** `breathing_screen.dart` + `breathing_editor_screen.dart`
  - Idle: `_TechChip` (pill, accentTint+accent border selected / surface+hairline unselected) replaces `ChoiceChip`/`InputChip`/`SegmentedButton`; custom techniques show Phosphor `x` delete; duration chips use `plMinutes()` (no hardcoded EN).
  - Running: `_BreathCircle` outer ring → `ext.border` hairline (static guide); glow layer (color @ 8%); inner circle retains color fill + border; Pause/Stop use Phosphor `pause`/`play`/`stop`.
  - Done: Phosphor `checkCircle(fill)` + `ext.success`; `plMinutes()` for duration in message.
  - Editor: phase cards → `Container(surface + 0.5dp hairline + R14)` replacing `Card`; Phosphor `trash`/`minus`/`plus`/`timer`/`check`; AppBar title has `wind` icon prefix.
  - All Material icons removed. All strings via `context.s()`. Business/engine logic preserved.

## 🎨 Kaname Redesign — Phase 5 Meditation + Session screens (2026-06-28)

- **[x] Meditation restyle (Phase 5 §E):** `meditation_screen.dart`, `meditation_editor_screen.dart`, `session_detail_screen.dart`
  - Session list cards: `Card(elevation:0, surface1 + 0.5dp hairline ext.border + R14)` replacing old Card with shadow.
  - All Material icons → Phosphor: `flowerLotus` (session avatar + completion dialog), `personSimpleTaiChi`, `bed`, `sun`, `moon` (pose icons per session type), `caretRight` (list chevron), `plus`/`trash` (add/delete), `play(fill)`/`pause(fill)` (player controls), `speakerHigh`/`slidersHorizontal` (audio panel toggle), `waveform` (narration), `wind` (ambient), `timer`/`check`/`minusCircle`/`plusCircle` (editor), `barbell` (session_detail empty state + exercise block).
  - `_sessions` list made non-const (Phosphor `IconData` values from function calls are not const expressions).
  - `_formatTime` / `_StaticArcTimer` label: MM:SS format `'$m:${s.padLeft(2,'0')}'` — removed hardcoded `'${sec}s'` (English "s" suffix).
  - `_StaticArcTimer` takes explicit `trackColor` parameter (was using `ext.border` from context internally).
  - Pose preview screen: large 96dp `accentMuted` circle + Phosphor pose icon in `colorScheme.primary`, `FilledButton.icon` with play-fill icon.
  - Player progress bar: `LinearProgressIndicator` styled with `ext.border` background + accent value, thin 3dp.
  - Player step text: `textSecondary` color + 1.55 line height.
  - Audio controls card: `Card(elevation:0, surface1 + hairline + R12)`.
  - Completion dialog: `flowerLotus(fill)` in `ext.success` (not accent per discipline), `Wrap` mood picker preserved.
  - Editor step cards: `Card(elevation:0, surface1 + hairline + R12)`, stepper with `plSeconds()` plurals, `ConstrainedBox(minWidth:80)` for stable layout.
  - `session_detail_screen.dart`: `ListView.separated` with 0.5dp hairline dividers (was manual spacing), `barbell` icon in exercise block header.
  - All strings via `context.s()`, plurals via helpers. Business logic, providers, public APIs untouched.

## 🎨 Kaname Redesign — Phase 5 Health screens (2026-06-28)

- **[x] Health restyle (Phase 5):** `health_screen.dart` + `warmup_screen.dart` + `posture_screen.dart`
  - Header: `displaySmall` (was `headlineMedium`).
  - All Material icons → Phosphor: `drop`, `arrowSquareOut`, `arrowCounterClockwise`, `bell`,
    `pencilSimple`, `caretRight`, `moon`/`moon(fill)`, `sun`, `forkKnife`, `flowerLotus`, `wind`,
    `barbell`, `slidersHorizontal`, `personSimpleWalk`, `checkCircle(fill)`, `play`, `pause`.
  - Cards: local `_KaCard` (surface1 + 0.5dp `ext.border` + R14, no shadow). Enabled module
    tiles use `Material(shape: RoundedRectangleBorder)` + `InkWell` for ripple.
  - Week charts: day letters via `DateFormat('EEEEE', locale)` (localized, was hardcoded EN).
  - Tablet 2-col preserved (Nutrition+Sleep / Mind+Movement).
  - posture_screen: Container + `clipBehavior: Clip.antiAlias` wraps `ExpansionTile`.
  - warmup player: Phosphor play/pause/checkCircle(fill+success) for UI chrome; data-model
    icons (routine.icon/step.icon from warmup_routines.dart) kept as Material (file out of scope).
  - All strings via `context.s()`, plurals via helpers. Business logic untouched.

## 🎨 Kaname Redesign — Phase 5 Diary screens (2026-06-28)

- **[x] Diary restyle (Phase 5 partial):** `diary_screen.dart` + `diary_history_screen.dart`
  - Phosphor icons: history→`clockCounterClockwise`, AI-insight→`sparkle`, this-week→`calendarCheck`,
    plan-vs-fact→`listChecks`, weekly-insight→`chartLineUp`, life-insights→`chartLine`, screen-time→`deviceMobile`, back→`arrowLeft`.
  - Extracted `_InsightCard` component (surface1 + hairline 0.5dp ext.border + R14) used by all 4 insight cards.
  - VerticalDivider tablet layout: fixed from `colorScheme.outline` → `ext.border`.
  - AI insight button uses `KaiLoader(size:16)` while loading (spec: KaiLoader on AI).
  - All strings via `context.s()` — no hardcoded EN. All overflow guards preserved (Expanded + ellipsis).
  - Business logic, providers, public APIs untouched.

## 🎨 Kaname Redesign — Phase 1 Foundation (2026-06-28, ветка `night/2026-06-25-meditation-onboarding-audio`)

- **[x] Phase 1 — Foundation (дизайн-система Kaname v4):**
  - `app/lib/core/branding.dart` (NEW): `kAppWordmark='Kaname'`, `kAppTagline`
  - `pubspec.yaml`: добавлен `phosphor_flutter: ^2.1.0`
  - `app_theme.dart` переписан: 4 темы (day/night/black/calm), AccentKey (6 акцентов),
    `_Surfaces`+`_Accent` struct, `AppTheme.build(...)` primary builder; deprecated compat-обёртки
    (focusTheme→night, whiteTheme→day, blackTheme→black, calmTheme→calm, contrastTheme→day+highContrast).
    Шрифт: HankenGrotesk (TODO: Geist, когда google_fonts ^6 его экспортирует); highContrast → Atkinson.
    Type scale из токенов v4, tabular figures для числовых стилей.
    `FocusThemeExtension`: все старые поля сохранены, добавлены `accentTint`, `accentInk`, `danger`, `textSecondary`.
  - `theme_provider.dart`: default=day, prefs-миграция (focus→night/white→day/contrast→day/custom→day),
    `accentNotifierProvider` (AccentKey, persist), `highContrastProvider` (bool, persist),
    `themeDataProvider` → `AppTheme.build(theme+accent+highContrast+harshness)`.
  - `main.dart`: `highContrastProvider` вместо `AppThemeKey.contrast` для scaler.
  - `profile_screen.dart`: 4 чипа (Day/Night/Black/Calm), убран custom-чип (Phase 4).
  - `setup_flow.dart`: 4 темы, новые свотчи, новые l10n-ключи.
  - `widget_service.dart`: миграция старых ключей при чтении.
  - `custom_theme_editor_screen.dart`: shim (Phase 4 заменит на accent-пикер).
  - L10n: `profile.theme_day/night`, `onboarding_quiz.theme_day/night/black/calm` (11 языков).
  - `flutter analyze` = 0, `screens_smoke_test` 8/8, `overflow_audit_test` 24/24.

## 🌙 Итог ночной сессии 2026-06-27 (оркестратор, ветка `night`)

Параллельный прогон агентов по фидбэку с теста 2026-06-27. Все правки — на ветке `night`,
`flutter analyze` = 0, новые тест-файлы зелёные. Сделано:

- **[x] Баги вёрстки Плана (2):** интервальный переключатель больше не ломает подписи вертикально
  (`_segmentsFit` консервативнее → раньше уходит в компактный dropdown); overflow 6-недельного
  месяца устранён (календарь ограничен по высоте через `LayoutBuilder`, ≤55% тела).
- **[x] ИИ-hook (ядро продукта):** `/ai/redistribute` теперь отдаёт КОНКРЕТНЫЙ план переноса
  по задачам (title+priority+время+разбор), а не общий nudge; инсайт дневника не обрезается
  (`maxTokens` 450→650) и возвращает охваченный период (`covered_from/to`). ADR-057, api-spec
  обновлён. **Клиент** рисует это как предложение «задача → 09:00 … Применить» (не обрезано).
- **[x] Контент медитаций:** 5 новых сессий + позы (читаются ДО старта), 11 языков; аудио —
  on-device TTS (без прав) + сгенерированный коричневый шум (без прав). Старая сессия дотянута до 11 языков.
- **[x] Маркер версии сборки:** видимая строка версии в Профиле + git-хэш через `run-phone.ps1`
  (`--dart-define=APP_BUILD_TAG`).
- **[x] Даты на английском:** оказалось уже починено централизованно (`applyIntlLocale` в
  `main.dart`/locale-провайдере); добавлен тест. Английские даты на тесте = старый веб-билд из `main`.
- **[x] Ре-категоризатор экранного времени:** тап по приложению → смена категории (игры MIUI
  из «другое» в «Игры»), сохраняется локально, применяется сразу.
- **[x] Health перегруппирован:** 4 темы (Питание+Вода · Сон · Разум=Медитация+Дыхание · Движение);
  модули включаются прямо на экране Health; экран не пустой по умолчанию.
- **[x] Настройки Kai упрощены:** было 8+ контролов → стало 2 (Показывать Kai · Тон) + живое превью.
- **[~] Шапка Today:** только ПРЕДЛОЖЕНИЕ (`docs/TODAY-HEADER-PROPOSAL.md`, 3 варианта, рекоменд. A) —
  ждёт выбора пользователя, код не трогали.

**Вопросы пользователю (на вечер):** (1) вариант шапки Today (A/B/C); (2) стрик в день без
main-задачи — считать день успешным или нет (продуктовое решение, не угадывал).

## Сводка для пользователя (обновлено 2026-06-27, Plan layout bugs)

- **[x] Bug 1 — интервальный переключатель (SegmentedButton 5 видов) рендерил надписи вертикально (по букве).**
  - Корневая причина: `_segmentsFit()` с `perSegmentPadding=40` переоценивала, что все 5 меток влезут на планшете — SegmentedButton получал стеснённое место и рендерил текст «по буквам».
  - Фикс: поднят `perSegmentPadding` с `40.0` до `56.0` + добавлен запас `+24` на всю строку (`return available >= needed + 24`). При пограничной ширине виджет переходит в безопасный `_ViewDropdown`.
  - Защитный фикс: weekday-метки в `ExpandableWeekCalendar` (Пн/Mo/…) теперь получают `maxLines: 1, softWrap: false, overflow: TextOverflow.clip` — не могут рендериться вертикально при любом `textScale`.
  - **Файлы:** `app/lib/features/plan/plan_screen.dart` (±`_segmentsFit`), `app/lib/features/plan/widgets/expandable_week_calendar.dart` (weekday Text).

- **[x] Bug 2 — RenderFlex "BOTTOM OVERFLOWED BY ~27px" на 6-рядном месяце + пустой день.**
  - Корневая причина: `ExpandableWeekCalendar` при 6 строках-неделях имеет естественную высоту ~410px. В ограниченной Column (header + divider + PinnedExamCard + Expanded) это больше тела экрана → `Expanded` схлопывался, Column переполнялась.
  - Фикс: 
    1. В `ExpandableWeekCalendar` добавлен параметр `maxCalendarHeight`. При наличии — высота grid-секции зажата в `effectiveGridH = naturalGridH.clamp(_kRowHeight, maxCalendarHeight - fixedParts)`. `ClipRect` + `OverflowBox` уже обрабатывают визуальное отсечение внутри.
    2. В `_bodyContent` для `PlanView.day` и `PlanView.week` — обёртка в `LayoutBuilder`, `maxCalH = (constraints.maxHeight * 0.55).clamp(220.0, ∞)` передаётся в виджет.
  - Коллапс/раскрытие, drag-жест, грабер — не тронуты.
  - **Файлы:** `app/lib/features/plan/widgets/expandable_week_calendar.dart`, `app/lib/features/plan/plan_screen.dart`.
  - **Тест:** `app/test/plan_layout_fix_test.dart` (3 теста: switcher 600px textScale 1.5, calendar expanded 400px body, calendar collapsed 400px body).

## Сводка для пользователя (обновлено 2026-06-27, meditation audio + 5 new sessions)

- **[x] Медитация: 5 новых встроенных сессий + озвучка (TTS) + фоновый эмбиент.**
  - **PART 2 — 5 новых сессий (все 11 языков):**
    - `anxiety_reset` (5 мин, 5 шагов) — быстрый сброс тревоги, поза «Grounded seat»
    - `morning_wake` (5 мин, 5 шагов) — утренний заряд, поза «Upright seat»
    - `gratitude_reset` (8 мин, 5 шагов) — перезагрузка благодарностью, поза «Comfortable seat»
    - `deep_work_entry` (4 мин, 4 шага) — вход в глубокую работу, поза «Desk-ready seat»
    - `evening_unwind` (10 мин, 6 шагов) — вечернее расслабление, поза «Resting pose»
  - **PART 1 + PART 3** (поза до старта + TTS + эмбиент): были реализованы в предыдущей сессии; текущая сессия завершила l10n всех 10 существующих сессий до 11 языков и добавила 5 новых с полным l10n.
  - **L10n:** все 5 новых сессий × (name + desc + pose_name + pose_desc + step1..6) × 11 языков в `health_b.dart`; весь блок `stress_relief` также расширен с en+ru до 11 языков.
  - **Тесты:** `test/meditation_new_sessions_test.dart` — 8 тестов: все 5 сессий в списке, превью позы для 4, нет overflow на 320px, нарратор через toggle, ambient toggle. Gate A (hardcoded strings) = 0. `flutter analyze` = 0.
  - **Существующие тесты** (`meditation_pose_preview_test.dart`, `meditation_audio_test.dart`) — все зелёные.
  - **Файлы:** `app/lib/features/health/meditation_screen.dart`, `app/lib/core/l10n/strings/health_b.dart`, `app/test/meditation_new_sessions_test.dart`.

## Сводка для пользователя (обновлено 2026-06-27, Health taxonomy)

- **[x] Health screen перегруппирован по 4 тематическим осям (Nutrition / Sleep / Mind / Movement).**
  - **Было:** плоский список — Water + Sleep всегда, остальные L2-плитки в одну кучу после.
  - **Стало:** 4 чётко названных секции (заголовки «Nutrition» / «Sleep» / «Mind» / «Movement»), строгая тематика:
    - **Nutrition** → Water card (всегда) + Food module tile (включаемый)
    - **Sleep** → Sleep card (всегда)
    - **Mind** → Meditation + Breathing (включаемые)
    - **Movement** → Workouts (включаемый)
  - **Обнаруживаемость:** каждый выключенный модуль показывает инлайн-Switch прямо на экране Health (без перехода в Profile → Behavior). Тап на Switch = включить / выключить — те же `feature_modes_provider` флаги. Profile → Behavior по-прежнему работает. Кнопка «Manage Health modules» снизу ведёт в Profile/Behavior.
  - **Water + Sleep остаются дефолтными** (без настройки, всегда видны); оба теперь логично встроены в таксономию (Water → Nutrition, Sleep → Sleep).
  - **l10n:** 5 новых ключей × 11 языков в `health_a.dart`: `health.section_nutrition`, `health.section_sleep`, `health.section_mind`, `health.section_movement`, `health.manage_modules`.
  - **Тест:** `test/health_taxonomy_test.dart` — 3 теста: 4 секции на 320px, 4 секции при textScale 1.5, ≥4 Switch в default-состоянии. Все зелёные. Существующие `overflow_audit_test` HealthScreen — всё ещё зелёные.
  - **Файлы:** `app/lib/features/health/health_screen.dart`, `app/lib/core/l10n/strings/health_a.dart`, `app/test/health_taxonomy_test.dart`.
  - `flutter analyze` → 0 ошибок. Gate A (hardcoded strings) → 0 в новых виджетах.

## Сводка для пользователя (обновлено 2026-06-27, упрощение настроек Kai)

- **[x] Настройки Kai упрощены: сложный «Mood & Kai» пульт → компактный блок «Kai».**
  - **Было (Profile → Behaviour):** «Mood & Kai» с 4 чипами-пресетами (Calm / Normal / Strict Coach / Custom) + скрытый раздел «Fine Tuning» с двумя SegmentedButton (тон + интенсивность). Итого ≥6 контролов для одной функции — пользователь (и разработчик!) не мог разобраться, что что делает.
  - **Стало:** один раздел **«Kai»** с двумя читаемыми контролами:
    1. **«Show Kai»** (тумблер) — маскот присутствует / скрыт. Перенесён из Внешнего вида в Поведение — логично рядом с настройками тона.
    2. **«Tone»** (SegmentedButton Gentle / Strict) — как Kai с тобой разговаривает. Описание под меткой одной строкой.
  - **Живое превью** сохранено: пользователь сразу видит пример реплики Kai в выбранном тоне.
  - **Что убрано из UI:** 4 чипа-пресета, раскрывающаяся «Fine Tuning», ось интенсивности (Off/Slight/Full). Провайдеры `reactiveIntensityProvider` и `MoodPreset`/`applyMoodPreset` остались в коде — не сломают другие части.
  - **l10n:** 3 новых ключа × 11 языков: `profile.section_kai`, `profile.kai_tone`, `profile.kai_tone_subtitle`.
  - **Файлы:** `app/lib/features/profile/profile_screen.dart`, `app/lib/core/l10n/strings/profile_paywall.dart`.
  - `flutter analyze lib/features/profile/` → 0 ошибок. Hardcoded-strings gate → 0 хитов.

## Сводка для пользователя (обновлено 2026-06-27, баг intl-дат)

- **[x] Баг — DateFormat показывает даты по-английски в не-EN локалях.** Корневая причина: `DateFormat` без явной локали использует `Intl.defaultLocale`, и если он не установлен или данные не инициализированы, падает обратно на `en_US`.
  - **Центральный фикс** — в `locale_provider.dart` функция `applyIntlLocale(localeTag)` делает оба шага: `await initializeDateFormatting(localeTag)` + `Intl.defaultLocale = localeTag`.
  - **Старт приложения** — `main()` вызывает `await applyIntlLocale(savedLocale)` до `runApp`, так что первый кадр уже видит правильную локаль.
  - **Смена локали** — `LocaleNotifier.setLocale()` вызывает `await applyIntlLocale(...)` до обновления состояния; все `DateFormat()` без аргумента локали (включая `DateFormat.yMMMMEEEEd()`, `DateFormat.MMMd()`, `DateFormat('d MMM')`, `DateFormat('MMMM yyyy')`, `DateFormat.E()`) автоматически используют новую локаль — call sites не тронуты.
  - **Добавлен тест** `test/intl_date_locale_test.dart` (4 теста): `applyIntlLocale('ru')` → `DateFormat.MMMM()` = «июнь»; `applyIntlLocale('de')` → «juni»; `applyIntlLocale('en')` → «June»; переключение ru→de→ru. Все зелёные. `flutter analyze` → 0.

## Сводка для пользователя (обновлено 2026-06-27, screen-time per-app category override)

- **[x] Screen-time: ручное переназначение категорий приложений.** MIUI/Android не всегда корректно выставляет `ApplicationInfo.category` — игры могут падать в «Другое». Пользователь теперь может исправить это вручную прямо в приложении:
  - **Хранилище:** `SharedPreferences`, ключ `screen_time_overrides`, JSON `{packageName: ourCategory}`. Новый `ScreenTimeOverridesNotifier` (файл `screen_time_overrides_provider.dart`).
  - **Агрегация:** `categorizeUsageMinutes()` и новая `resolvePackageCategory()` в `screen_time_categories.dart` принимают `userOverrides` с наивысшим приоритетом (userOverride > whitelist > androidCategory > 'other').
  - **State:** `ScreenTimeUsageState` расширен `perPackageMinutes` + `perPackageCategories` — raw-данные и resolved-категории для каждого пакета.
  - **UI:** в карточке «Usage data» появился подраздел «Apps» — список всех приложений за день (сортировка по убыванию минут, первые 8 + кнопка «+ N»). Тап на строке открывает `_AppCategoryPickerSheet` (ListTile-радио из 6 категорий). Accent-точка на чипе = есть пользовательский оверрайд. Кнопка «Reset to default» удаляет оверрайд. После выбора: снэкбар «Category saved» + немедленный `refresh()` агрегации.
  - **l10n:** 4 новых ключа × 11 языков в `health_b.dart`: `screentime.apps_section`, `screentime.reassign_title`, `screentime.category_changed`, `screentime.reset_to_default`.
  - **Тест:** `test/screen_time_overrides_test.dart` — 8 чистых юнит-тестов на `categorizeUsageMinutes` + `resolvePackageCategory` с оверрайдами. Все 59 screen-time тестов зелёные. `flutter analyze` → 0.

## Сводка для пользователя (обновлено 2026-06-27, баги food_screen)

- **[x] Bug 1 — ИИ-фото: выбор совпадения не работал.** В `_FoodSearchSheetState.build()` ветка «Недавнее» срабатывала при `_controller.text.isEmpty`, перекрывая результаты ИИ-фото (поле пустое, но `_results` непустые). Фикс: добавлено `&& _results.isEmpty` в условие. Теперь при наличии AI-результатов отрисовывается ListView совпадений, тап открывает диалог порции.
- **[x] Bug 2 — Хардкод английских строк в `food_screen.dart`.** Заменено на l10n:
  - `'AI: $dish (…%) — pick a match'` → `food.ai_photo_match` {dish}/{pct}
  - `'AI: $dish (…%)'` → `food.ai_photo_recognized` {dish}/{pct}
  - `'$kcal kcal / 100g'` в subtitle поиска → `food.kcal_per_100g` {kcal}
  - `'Sugar … / … g'` и `'Fiber … / … g'` в TotalsCard → `food.totals_sugar_line`/`food.totals_fiber_line` {val}/{max}
  - `'Product not found for barcode …'` → ключ `food.barcode_not_found`
  - Добавлено 6 новых ключей × 11 языков в `core/l10n/strings/food.dart`.
  - Gate A (`rg`) → 0 хитов в `food_screen.dart` после правки.
- **[x] Тест.** Новый `test/food_search_sheet_display_test.dart` (3 теста): проверяет отрисовку списка совпадений при `_results != []` + пустом поле, отсутствие «Недавнее» при результатах, открытие диалога порции по тапу. Все зелёные. `flutter analyze lib/` → 0.

## Сводка для пользователя (обновлено 2026-06-27, эпик «план как позвоночник» + синк доков)

- **Эпик «план как позвоночник» — реализован в коде; продуктовые/UX-доки приведены в соответствие:**
  - **Навигация = 4 таба** Today / Plan / Health / Diary; профиль — кнопка-аватар в AppBar (не таб).
  - **Today:** hero-секция для `priority='main'`, заметный утренний разбор (ember-карточка, 3 кнопки в один тап), **привычки убраны** из Today и из навигации (`/habits` удалён).
  - **Health — теперь СВОДКА, не хаб:** Вода и Сон встроены и видны всегда; **Еда / Тренировки / Медитация / Дыхание — опциональные модули за режимами-флагами** (`feature_modes_provider.dart`), включаются в Профиле → «Поведение», по умолчанию выкл. Старый «хаб из 10 плиток» больше не существует.
  - **Осанка** выведена из навигации (`/posture` удалён) — остался только тумблер напоминаний в Профиле. **Co-study** (`/costudy`) тоже выведен из нав (экран в коде остаётся).
  - **Профиль** разбит на подстраницы: Внешний вид / Поведение / Аккаунт (+ Мои данные).
  - **Иерархия задач** = подзадачи (Subtasks, ADR-048), а не отдельные уровни L0/L1/L2.
  - **Веб задеплоен на GitHub Pages** (лендинг `/glavnoe/`, веб-апп `/glavnoe/app/`; см. workflow `deploy-web.yml`).
  - **Доки обновлены:** `SPEC.md` (C2 Today, C5 Health новая модель, C7 профиль-подстраницы, C8b опциональные модули), `UX-LAYOUT.md` (§5 Health), `UX-LAYOUT-FULL.md` (пометки «вне навигации» на costudy/posture/habits + актуализирован хаб), `app/CLAUDE.md` (правило про опциональные модули), `MEDITATION-AUDIO-ARCH.md` (помечен PROPOSED — NOT IMPLEMENTED).
  - **To review (НЕ редактировал — shared-контракты):** в `data-model.md`/`api-spec.yaml` могли остаться сущности привычек/co-study/осанки — сверить при следующем проходе по контрактам; **«разбор недели»** и кнопка **«Пересчитать»** из SPEC всё ещё **не реализованы** (кандидаты будущей фазы).

## Сводка для пользователя (обновлено 2026-06-26, задача 10 — иерархия Today)

- **Задача 10 ЗАВЕРШЕНА (иерархия Today):** три точечных изменения без редизайна:
  1. **Hero main-задачи:** в `task_list.dart` секция `priority='main'` теперь оформлена как визуальный герой — accent-разделитель 2dp + `_HeroSectionHeader` (titleLarge + pill-счётчик). Цвет через `colorScheme.primary` (= `palette.accent` во всех 5 темах). Тап/свайп — без изменений (все `_buildRow` вызовы сохранены).
  2. **Заметный утренний разбор:** `MorningReviewCard` переработан: ember-фон (`withAlpha(20)`) + ember-бордер, счётчик задач в pill, три кнопки одного касания в `Wrap` (без overflow на 320px): «Accept all» → `moveAllToDay`, «Adjust» → `_MorningReviewSheet`, «Leave» → `_dismissed=true`. Кнопка перемещена в самый верх скролла (перед `ProgressRing`). 3 новых l10n-ключа × 11 языков.
  3. **Уменьшена геймификация:** `HabitsTodaySection` убрана из Today (mobile + tablet). Файл сохранён, только не рендерится. Существующий тест `habits_today_section_test.dart` не затронут (тестирует виджет напрямую).
  - `flutter analyze` → 0. Новый тест `test/today_hero_test.dart` — 7/7 зелёных.

## Сводка для пользователя (обновлено 2026-06-26, §3a mood_logs Drift)

- **§3a ЗАВЕРШЕНО:** настроение после медитации перенесено из SharedPreferences в Drift-таблицу `mood_logs` (schemaVersion 21→22). Новый DAO `MoodLogsDao` с методами `insertMood`/`getSince`/`watchSince`/`getSinceBySource`. Провайдер `moodLogsDaoProvider`. `meditation_mood_log.dart` переписан: `appendMeditationMood(MoodLogsDao, entry)` и `readMeditationMoodLogs(MoodLogsDao)`. Вызов в `meditation_screen.dart` обновлён. Таблица локальная — синк не тронут. Старый prefs-ключ `'meditation_mood_logs'` не удаляем (beta-данные целы). 10 тестов (включая миграционный) — все зелёные. `flutter analyze` → 0. §3b (чтение инсайтами) — отдельная задача.

## Сводка для пользователя (обновлено 2026-06-25, привычки ADR-053)

- **Привычки — редизайн ЗАВЕРШЁН (ADR-053, 4 слайса, всё в `test/integration`):**
  - Слайс 1 (`dabfef5`): модель частоты в `HabitsTable` (`frequencyType`/`weekdayMask`/`weeklyTarget`/`reminderMinutes`, Drift v18→v19) + стрик по расписанию (daily / по дням недели / X раз в неделю) — стрик больше не «врёт» на не-ежедневных. 9 юнит-тестов.
  - Слайс 2 (`a48ef9d`): диалог создания — выбор частоты (чипы Пн-Вс / N раз в неделю) + «раз в день»; полоска прогресса скрыта при target=1. 6 ключей × 11 языков. 2 теста.
  - Слайс 3 (`e8d7f75`): секция «Привычки на сегодня» в «Сегодня» (показывает запланированные-и-невыполненные, отметка одним тапом), `dueGoodHabitsProvider`. 12 тестов.
  - Слайс 4 (`688b11d`): напоминания — время на привычку, локальные уведомления по расписанию частоты (cancel/reschedule на delete/archive/undo). 14 тестов. **Реальное срабатывание уведомлений — нужна проверка на телефоне.**
  - Итого: полный Flutter-сьют **1108 зелёных, 0 красных**; попутно починен предсуществующий протухший тест `workout_templates` (`77e0cbf`, сентинель rest-default после Phase A3).
- **Импорт календарей — проверен и укреплён (`edad5d3`):** все 4 источника живые (текст/ICS/Todoist CSV/фото-AI), импортированное **синкается** (тревога про `userId='local'` — ложная, это нормальный сентинел). Починен реальный **краш** Todoist-парсера (нет колонки приоритета/даты), добавлены экранирование ICS / all-day / разбор RRULE на уровне парсера, **+52 теста** (было ноль). Полный сьют **1160 зелёных**.
  - ⚠️ **Известная лимитация (отложено на дизайн-фазу):** экран подтверждения импорта сводит событие к строке «ЧЧ:ММ Название» → при импорте **теряются повторяемость / «весь день» / длительность** (парсер их понимает, но текстовый превью — нет). Чтобы переносить их, нужен **структурный превью** (карточки событий) — это UX-переделка, делаем в дизайн-фазу.
- **«Своя техника» — дыхание (`fcf1f3b`) + медитации (`cfc1f09`) ГОТОВО:** у обоих модулей появился редактор пользовательских сессий (Drift v19→v20→v21, чистый codec, DAO, editor-экран, интеграция в пикер/список, delete с undo), кастомные сессии бегут через тот же движок/плеер, что и встроенные. ~36 тестов. Полный сьют **1196 зелёных**.
- **Порядок работ (решение пользователя 2026-06-25):** **1) сначала весь функционал → 2) затем дизайн/полиш → 3) в самом конце перед хакатоном/выгрузкой — большой прогон тестов (вкл. бэкенд jest на Neon) + блокеры релиза (деплой/иконка/подпись/аккаунты).** На вехах функционала всё равно гоняется полный локальный Flutter-сьют (см. [[feedback-kaizen-testing]]).
- **Очередь функционала:** [x] привычки · [x] импорт · [x] дыхание «своя техника» · [x] медитации «своя техника» (редактор) · [~] **КОНТЕНТ медитаций** (5 новых сессий + позы к 10 — **текст УТВЕРЖДЁН пользователем**; осталось: добавить поле `pose` в модель, вставить 5 сессий + позы, показать позу/описание ПЕРЕД стартом, перевести на 11 языков; тон — как в примере «Быстрый сброс тревоги») · [ ] онбординг (продумать вместе — разбор+предложение, не вслепую) · [ ] «разбор недели»/«Пересчитать» из SPEC (уточнить нужность — это перепланирование дня, НЕ КБЖУ).
- **Решения по велнесу (для дизайн-фазы):** Медитации — **аудио (голос через on-device TTS + музыка) приоритетнее видео**; поток: поза/описание читаются ДО старта, технику плеер ведёт по таймеру. Вода — единый набор кнопок + «своё количество», кнопки карточки = подмножество набора полноэкранного (числа-набросок 200/300/500).
- **Параллельно — на пользователе (долгий разгон, нужно начать сейчас):** регистрация аккаунтов RuStore + Render + самозанятость (для платежей); подтверждение хакатона Kodik (трек+дедлайн); логотип для иконки. Без них финальная выгрузка не уедет.

## Сводка для пользователя (обновлено 2026-06-25, l10n)

- **workouts_library.dart l10n — ЗАВЕРШЕНО:** добавлены последние hi/ja/ko для оставшихся 73 ключей (17 упражнений) — 219 новых строк. Теперь **все 236 ключей техники покрыты всеми 11 языками** (en/ru/de/fr/it/pt/es/id/hi/ja/ko). `flutter analyze` → 0 ошибок. Это закрыло остаток прерванного l10n-прогона.
- **workouts_library.dart l10n (предыдущий блок):** добавлено hi/ja/ko для 81 ключа (17 целевых упражнений) — 243 новые строки. `flutter analyze` → 0 ошибок.

## Сводка для пользователя (обновлено 2026-06-25)

Сессия 2026-06-25 (ветка `test/integration`, не влита в `main`). Всё закоммичено и запушено:
- **Монетизация → freemium без рекламы** (ADR-052): SPEC + CLAUDE обновлены, пункт «рекламные аккаунты» из остатка убран.
- **#17 теги:** `#тег` авто-выносится в чипы, вырезается из заголовка; локальная колонка `tags` (Drift v18); поиск по тегам.
- **#8 экранное время:** короткие ночные сессии больше не теряются (ceil вместо floor) + обновление при открытии экрана (цифры «застывали»). Часовой пояс корректный (локальная полночь). Хвост: на MIUI игры падают в «другое» → нужен пользовательский ре-категоризатор (НЕ сделано).
- **#9 календарь Plan:** раскрывается с первого тапа (грабер получил onTap; на вебе клик вообще не работал).
- **#18 иконка дедлайна:** `alarm_outlined` вместо общего с целями флажка.
- **#7 форма задачи:** модуль определяется автоматически по названию (ручной пикер убран); блок «Ещё» расхлопнут (поля сразу); тип/приоритет остаются видимыми.
- **#5 + #6 редактируемые КБЖУ + единый экран «Мои данные»:** `macroOverrideProvider` (ручной + авто-баланс с замочками, `rebalanceMacros`), виджет `MacroEditor`; экран `MyDataScreen` (Тело·Цель·КБЖУ·Вода·Питание·Здоровье·Сон) вместо трёх секций, одна точка входа (переименовано с «Изменить цели»), предзаполняется из тех же ячеек, онбординг не тронут.
- ⚠️ `MyDataScreen` компилируется (analyze 0), но **на устройстве не прогонялся** — нужна живая проверка вёрстки (длинный скролл, 320px).

Остаток дизайна (нужно решение/контент): #10 доработка Kai, #11 тренировки (видео/ИИ-тренер), #12 экраны Privacy + User Agreement, ре-категоризатор приложений для экранного времени.

## Сводка для пользователя (обновлено 2026-06-23)

### ✅ Миграция Neon применена (2026-06-23) — критический блок закрыт
Миграция `20260623030000_subtasks_reminders_groups_reset` применена к Neon через `prisma migrate deploy` (в `.env` добавлен `DIRECT_URL`, ADR-050; текущая строка уже прямая, без `-pooler`, поэтому DIRECT_URL = DATABASE_URL). Созданы `Subtask`, `PasswordResetCode`, `study_groups`, `study_group_members` + колонка `Item.reminderMinutesBefore` (ADR-047/048/049). `prisma migrate status` → «Database schema is up to date». **`P2021` устранён**: backend jest **199/199** зелёные (18 сьютов). Закоммичено и запушено в `main` (b750ff4).

> На прод (Render): после деплоя выполнить `prisma migrate deploy` с прод-`DIRECT_URL`, либо положиться на `postinstall`/билд-шаг.

## Сводка для пользователя (обновлено 2026-06-21)

### ✅ Готово (работает, под тестами)
- **Render-деплой (2026-06-21, ADR-045):** `render.yaml` в корне репо (rootDir: backend); CORS доработан: production разрешает только origin'ы из `ALLOWED_ORIGINS` (env, запятая); `postinstall: prisma generate` в package.json. Jest: 136/136 (добавлено 16 CORS-тестов).
- **MVP целиком** — аккаунты + синхронизация (офлайн-первый), Today/Plan/Diary, rule-разборы утро/вечер, импорт расписания (текст / клон недели / фото-AI), стрики + заморозка, онбординг (расчёт воды по весу/росту, кнопка «Назад»), 5 тем, Android-виджет, локальные уведомления, все MVP-анимации (≤300 мс).
- **Вход по закону РФ (406-ФЗ) — 2026-06-18:** убран вход через Google/Apple; добавлен вход по телефону (РФ `+7`, без СМС) и по российской почте (фильтр доменов, env `ALLOWED_EMAIL_DOMAINS`); регистрация/вход — ровно один идентификатор (email **или** телефон) + пароль. Бэкенд jest 110/110, Flutter 118/118, миграция `auth_phone_ru_compliance` применена в Neon (ADR-031).
- **Ф1 целиком** (OAuth убран по закону 406-ФЗ, см. выше) — Food (поиск OFF / штрихкод / фото-AI / голос / рецепты / «Собрать ИИ» / баланс рациона / список покупок), Water с графиком, Wrapped Неделя/Месяц + AI-абзац, все 7 AI-фич через провайдер Gemini⇄Claude, paywall + Subscribe (срез под RevenueCat), лимит фото 3/день.
- **Ф2, кроме Health Connect** — Sleep-трекер, дыхание (3 пресета с авто-фазами), медитации (5 текстовых сессий), осанка (упражнения + напоминания), Workouts (шаблоны → редактор → режим «тренер» → журнал «Did it as planned»), фокус-сессии (вкл. фирменный 67/15).
- **Ф3-шеринг и соц-слой** — веб-ссылка на план (открывается без приложения), «поделились со мной» + копирование к себе, co-study (друзья по email, сессии по коду, общий таймер, недельный лидерборд), реферальная карточка.
- **Цели C4** — Месяц / Год / 5 / 10 лет → шаг цели становится задачей на сегодня («Plan today»).
- **UX-бэклог 16–17 июня** — история за прошлые даты (Water/Sleep/Diary/Plan), выбор даты календарём, восстановление пароля, трекер привычек, шаблоны задач, хештеги + поиск, глобальный undo, вложения фото/видео к задачам, адаптивная вёрстка всех 4 табов, экранное время (лимиты по категориям), аналитика образа жизни, Terms & Privacy, **импорт из планнеров (ICS + Todoist CSV)**.

- **Fast-entry hooks (2026-06-19):** NL-парсер дат/времени (`core/utils/nl_datetime.dart`) — RU/EN/DE, 26 юнит-тестов все зелёные. Поле заголовка в `add_task_sheet.dart` получило mic-иконку (голосовой ввод через `speech_to_text`, web gracefully hidden) + dismissible hint-чип с распознанной датой ("Tomorrow 17:00 — tap to change"). Диктовка тоже прогоняется через NL-парсер. `flutter analyze` 0.

### ⏸ Осталось — упирается в тебя / железо / аккаунты (не в код)
- **Health Connect / Apple Health** — нет устройств для проверки.
- **iOS-виджет — код готов, нужна сборка на Mac.** Swift-исходники (`KaizenWidget/`) и AppDelegate-обработчик написаны, `widget_service.dart` обновлён (iOS-ветка). Осталось: создать Widget Extension target в Xcode, добавить App Group capability, скопировать Kai PNG в Asset Catalog. Подробно: `docs/SETUP-ios-widget.md`.
- **Реальные платежи — пейвол ни к чему НЕ подключён (важно, ADR-039).** Экран `/paywall` и кнопка «Start free» сейчас зовут `StubPurchaseService` — это заглушка: в debug она просто включает premium (`dev-upgrade`), в release возвращает «недоступно». **Настоящего списания нет ни на одной платформе.** Реальный путь: iOS → App Store IAP, Android → Google Play Billing (оба через **RevenueCat**, замена одной строки в `purchase_service.dart`); **веб → отдельный процессор (Stripe / RevenueCat Web Billing) — для веба RevenueCat сторовый биллинг не работает**. Нужны: аккаунты Apple/Google, проект RevenueCat + ключи, (для веба) Stripe-аккаунт. Это твоя зона — код-абстракция готова, подключение = ключи.
- **Умные часы [Ф4]** — Wear OS / watchOS; нужны часы + Apple Developer Account.
- **Реклама на free-тарифе** — нужны рекламные аккаунты (осознанно отложено).
- **Живые проверки на телефоне** — голос, сканер, уведомления, диагностика «connection refused»/премиум через `scripts/run-phone.ps1`.
- **Онбординг quiz-flow (2026-06-19)** — `setup_flow.dart` переписан: 16 экранов (Hello→Problem→Solution→Language→Goals→PlanTime→Horizon→Projection→Age→HeightWeight→Activity→FirstTask→RescheduleDemo→Timing→Summary→Paywall). Честные данные, Kai на каждом экране, первая задача вставляется в Drift, демо переноса — интерактивный sandbox, locale устанавливается live, все провайдеры reused, `flutter analyze` 0. Новые prefs keys: `onboarding_goals` (StringList), `onboarding_plan_minutes` (int), `onboarding_horizon` (String). Строки: `core/l10n/strings/onboarding_quiz.dart` (83 ключа en/ru/de).
- **Дизайн-полиш (нужна проверка на устройстве)** — виджет Android (больше данных, оформление под темы, размеры), Calm-тема по всем экранам, тайминги конфетти/переходов вживую, прогон на 360px и планшете.

### ✅ Готово (2026-06-25) — Phase A3: Фикс «magic 60» сентинель для времени отдыха
- **[x] Phase A3:** Введён `kUseDefaultRest = -1` как явный сентинель «использовать глобальный дефолт» (вместо перегруженного 60). `kLegacyRestMarkerSeconds = 60` сохранён для обратной совместимости старых записей БД. `effectiveRestSeconds` и `isUseDefaultRest` обновлены — проверяют оба значения. Генератор шаблонов (`workout_templates.dart`): все нормальные силовые упражнения теперь пишут `kUseDefaultRest` (глобальный дефолт пользователя), явный 30с остаётся только у core/cardio holds (планки, берпи, прыжки). Редактор (`workout_editor_screen.dart`): поле отдыха нового упражнения по умолчанию пустое — плейсхолдер «Default (MM:SS)»; сохраняется `kUseDefaultRest`; карточка показывает «rest Default (02:00)» вместо «rest 60s». DAO `addExercise` умолчание = `kUseDefaultRest`. Схема Drift не изменилась (миграция не нужна). L10n: добавлен ключ `workout.rest_default_fmt` (11 языков). Тесты: `rest_default_test.dart` 25/25 зелёных. `flutter analyze` 0.

### ✅ Готово (2026-06-25) — Task #17: Реальная система тегов через хэштег-парсер
- **[x] Task #17:** `core/utils/tag_parser.dart` (42 юнит-теста), колонка `tags` в `ItemsTable` (schemaVersion 18, миграция addColumn, локальная как moduleLink), `add_task_sheet.dart` — живые чипы тегов при вводе + сохранение в колонку tags + tooltip `today.tag_remove_tooltip` (12 языков), `task_list.dart` + `day_timeline.dart` — чипы тегов под заголовком (уже было), `week_agenda.dart` — чипы тегов добавлены в `_AgendaRow`, `planSearchMatches` — поиск сначала по полю `tags`, fallback на заголовок (обратная совместимость); `plan_search_test.dart` расширен до 28 тестов. `flutter analyze` 0 ошибок.

### ✅ Готово (2026-06-24) — онбординг + профиль здоровья
- **[x] Фичи A/B/C онбординг/профиль:** (A) мин. приёмов пищи 1 (OMAD) + пикер 1–6 + «другое» вместо SegmentedButton 3/4/5; (B) расписание сна (bedtime/wake TimeOfDay) в онбординге (экран 14) + профиле здоровья; (C) поле аллергий упрощено — без избыточной подсказки; поле заживления заменено на чипы с конкретными временными диапазонами («день-два» / «неделя» / «2+ недели»). Prefs-ключи: `sleep_bedtime_hour`, `sleep_wake_hour`. L10n: 24 новых ключа в `health_a.dart` + 1 ключ в `onboarding_quiz.dart` + `btn.ok` в `common.dart` — EN+RU и 9 языков. `flutter analyze` 0.

## Сводка для пользователя (обновлено 2026-06-27, подсистема Undo)

- **Дефект 1 (HIGH) — ЗАКРЫТ: Undo после выполнения задачи в «Сегодня» теперь работает.**
  - Обычные задачи: `updateItem(pending, updatedAt=now)` — добавили `updatedAt` для LWW-корректности при синхронизации.
  - Виртуальные повторы (серии): вместо «поставить pending на конкретную строку» теперь **полный откат материализации**: удаляем concrete-строку + снимаем EXDATE с якоря → виртуальный повтор возвращается чисто.
  - Добавлена `removeExDateFromRule` в `recurrence.dart` (симметрично `addExDateToRule`).
  - Добавлена `undoMaterializeOccurrence` в `ItemsDao`.
  - Тест: `test/today_undo_test.dart` — 3 зелёных (обычная задача, виртуальный повтор, локализация кнопки Undo).

- **Дефект 3 — ЗАКРЫТ: кнопка Undo в AppToast теперь локализована.**
  - `app_toast.dart`: `const Text('Undo')` → `Text(context.s('common.undo'))`. Ключ `common.undo` уже присутствовал во всех 11 языках.

- **Дефект 2 — регресс-тест добавлен; сам дефект — вендорский баг MIUI.**
  - Тест `test/workout_editor_undo_test.dart` — 2 зелёных: SnackBar появляется, Undo восстанавливает упражнение.
  - Auto-dismiss (4с) на MIUI зависает из-за системного оверлея вендора — это не баг Flutter/нашего кода. Воспроизведение только на реальном устройстве MIUI; в тестовой среде авто-скрытие работает корректно.
  - `flutter analyze` на всех 6 изменённых файлах → 0 ошибок.

### 🐞 Баги / техдолг (мелочь, не блокирует)
- **[ ] ОТЛОЖЕНО на «после UX + утверждённых фич» (по решению пользователя 2026-06-23):** ещё более глубокий проход по багам — расширить `interaction_smoke_test.dart` на оставшиеся под-флоу (привычки: создание/лог; добавление воды; создание/шаги цели; редактор рецепта; AI-листы с мок-провайдером; тоглы настроек профиля/осанки; импорт ICS/CSV; undo-сценарии) и добить потенциальные краши до сборки на телефон. Контекст: большой проход 2026-06-23 поднял покрытие до всех 36 экранов в 3 слоя (render `screens_smoke_all_test`, overflow `overflow_audit_all_test`, interaction `interaction_smoke_test`) и нашёл/починил 3 реальных бага (WaterReport+Profile overflow, краш сетки Плана в «3 дня»/grid). Сделать, КОГДА закроем UX-очередь и фичи A/B/C.
- ~~Лимит AI-фото (3/день) хранился в памяти процесса~~ → **закрыто 2026-06-18:** таблица `AiUsage` (устойчиво к рестарту/мультиинстансу), ADR-034, jest 111/111.
- ~~RenderFlex overflow в тулбаре Plan на ~390px~~ → **закрыто 2026-06-18:** `SegmentedButton` обёрнут в `Flexible` + `SingleChildScrollView(Axis.horizontal)`; overflow на 360px устранён, поведение не изменилось.
- ~~«Shared with me» краш с красным экраном~~ → **закрыто 2026-06-18:** `TextEditingController` перенесён в поле `_SharedWithMeCardState` (initState/dispose), больше не утилизируется синхронно после `await showDialog` — каскад ошибок (duplicate GlobalKey / multiple heroes / wrong build scope) устранён.
- Шрифт Geist — временная замена, ждём пакет (`app/.../app_theme.dart`).
- ~~Privacy / Terms на лендинге — плейсхолдеры~~ → **закрыто 2026-06-21:** созданы `landing/privacy.html` и `landing/terms.html` (полный текст, Focus-тема); ссылки в футере `index.html` обновлены. Ссылки сторов остаются плейсхолдерами до публикации приложений.
- ~~`widget_test.dart` — пустышка~~ → **неактуально (2026-06-20):** файла-пустышки нет, реальные виджет-тесты живут в `screens_smoke_test.dart` + 20+ юнит-сьютов в `app/test/`.
- **Перевод RU — остаток (2026-06-19):** основные пропуски устранены sweep-ом (51 ключ, см. блок выше). Обоснованно пропущено: `ToneCopy.*` строки в `tone_provider.dart` (нет BuildContext, строки tone-aware — риск рефактора), `screen_time_provider.dart` (данные провайдера без context), числовые plural-формы («$n min», «$missed workout(s)», счётчик упражнений) — без plural-библиотеки опасно для RU падежей, `'$type'` лейбл в shared-plan viewer, debug-строки `'Error: $err'`.

### 🙋 Нужна твоя помощь (без тебя не двинется)
0. **Деплой веб — СДЕЛАН пользователем (2026-06-27).** ✅ Лендинг живой на https://rigby453.github.io/glavnoe/ (проверено, ссылка на `app/` на месте). ✅ Render-бэкенд живой: **`https://kaizen-backend-d5fr.onrender.com`** — `/health` → `{"status":"ok"}` (проверено; free-tier засыпает, первый запрос ~30с холодный старт). **Осталось проверить:** что GitHub Variable `API_BASE_URL = https://kaizen-backend-d5fr.onrender.com` (иначе веб-апп ходит в localhost), и что в секретах Render `ALLOWED_ORIGINS` содержит `https://rigby453.github.io`. Инструкция: `docs/SETUP-DEPLOY.md`.
1. **Телефон + `run-phone.ps1`** — проверить голос, сканер, уведомления, премиум.
2. **Аккаунты** — Google Play / App Store (OAuth, RevenueCat, публикация), Firebase (пуши), рекламная сеть (free).
3. **Правки ТЗ** — если хочешь что-то поменять: пиши списком, внесу в `SPEC.md` через ADR и пересоберу бэклог.
4. **Контент** — видео техник упражнений, аудио медитаций; подключу, когда появится.

### Тесты
На 2026-06-20 зелёные (`flutter analyze` — 0). Backend: 120/120 jest (11 сьютов, --runInBand). +10 новых тестов в `entitlement.test.ts` (ADR-041). +17 юнит-тестов `freeze_accrual_test.dart` (computeAccrual: инициализация, Free cadence, Premium cadence, пороги 10/25/50 — один раз за жизнь, одновременное достижение нескольких порогов, повторный unclaim невозможен). **+10 overflow_audit_test.dart (2026-06-20):** все ключевые экраны (Today, Plan, Diary, Health, Food) без RenderFlex overflow на 320px и при textScale 1.5. Flutter: 238/238 tests, `flutter analyze` 0.

---

## Журнал работ (хронология сделанного по блокам)

- [x] **Кнопка закрытия на всех action-шитах (2026-06-24):** аудит выявил 11 action-поверхностей без видимого dismiss-аффорданса. Добавлен единый `IconButton(Icons.close)` с tooltip `btn.close` в заголовок каждого: `import_sheet.dart`, `ai_menu_sheet.dart`, `ai_workout_sheet.dart`, `_EveningReviewSheet`, `_MorningReviewSheet`, `_FoodSearchSheet`, `_IngredientSearchSheet` (recipe_editor), `TaskDetailCard`, `_HabitDetailSheet`, `_LimitBottomSheet` (screen_time), `_GroupDetailSheet` (costudy), `_pickTimezone` sheet, `_PlanSheetContent` (profile). `add_task_sheet.dart` уже имел крестик — не трогали. Иконка: `Icons.close`, ключ l10n: `btn.close` (уже был в common.dart, EN+RU+9 языков). `flutter analyze` 0, `interaction_smoke_test.dart` 14/14.

- [!] **Подзадачи + reminder_minutes_before (2026-06-23, ADR-048):** задача получила чеклист подпунктов и поле «напоминание за N минут». Бэк: модель `Subtask` (cascade с `Item`, `@@index([itemId])`) + колонка `Item.reminderMinutesBefore Int?` (валидация 0..10080); `syncSubtasks` (`models/item.ts`) — замена-набором (upsert по id + удаление отсутствующих) внутри `$transaction`; подзадачи едут **вложенным snake_case массивом** на `Item` через `POST/PATCH /items` и `/sync`; `serializeItem` отдаёт `subtasks` (сорт по `sort_order`) + `reminder_minutes_before`. Шаблон подзадач живёт на якоре серии (recurrence). Клиент: Drift поднят до **v15**. Контракты обновлены (api-spec: `Subtask`/`SubtaskInput` + поля на Item/Create/Update; data-model). **Миграция к Neon не применена — `P2021` до `prisma migrate`** (см. блок «Требует миграции Neon»).

- [!] **Co-study группы (2026-06-23, ADR-049):** настоящие учебные группы поверх одиночных сессий. Модели `StudyGroup` (`study_groups`, `code @unique`, владелец cascade) и `StudyGroupMember` (`study_group_members`, `role owner|member`, `status pending|accepted`, `@@unique([groupId,userId])`). Маршруты в `routes/costudy.ts` (snake_case): `POST /study-groups` (создатель = owner/accepted, 201); `POST /study-groups/join/{code}` (заявка pending, code case-insensitive, 404/409); `accept`/`decline` участника (только владелец → 403; нельзя отклонить владельца → 400; 200/204); `DELETE /study-groups/{groupId}/leave` (**выход владельца удаляет группу каскадом**, `{deleted_group}`); `GET /study-groups` (мои accepted + `pending_count` для владельца); `GET /study-groups/{groupId}` (детали; владелец видит pending, участник — только accepted). Контракты обновлены (api-spec: тег Study Groups + 6 путей + схемы; data-model). **Миграция к Neon не применена — `P2021`** (`study_groups`/`study_group_members`).

- [!] **Password-reset в БД (2026-06-23, ADR-047):** коды восстановления пароля переехали из in-memory `Map` в таблицу `PasswordResetCode` (только SHA-256-хэш кода, TTL 15 мин + одноразовость, cascade с User). Контракты дополнены (data-model + prisma-блок). **Миграция к Neon не применена — `P2021`** (`PasswordResetCode`), интеграционные тесты flow падают до `prisma migrate`; юнит-тесты зелёные.

- [x] **Neon connection pooling (2026-06-23, ADR-050):** `datasource db` теперь даёт два URL — pooled `url = env("DATABASE_URL")` (хост `-pooler`, `?pgbouncer=true`) для рантайма и `directUrl = env("DIRECT_URL")` (без pooler) для миграций. Документировано в `.env.example`, `backend/CLAUDE.md`, `render.yaml`; data-model `datasource` приведён в соответствие. Рантайм держит много дешёвых коннектов через PgBouncer, `prisma migrate` идёт по прямому каналу.

- [x] **Recurrence weekly/monthly (2026-06-23):** повторение задач расширено еженедельным и ежемесячным правилами (iCal RRULE); экземпляры серии генерируются по правилу, подзадачи/настройки берутся с якорной задачи (см. ADR-048).

- [x] **NL-парсер: duration/priority/recurrence/reminder (2026-06-23):** парсер быстрого ввода (`core/utils/nl_datetime.dart` и связанные) теперь распознаёт не только дату/время, но и длительность, приоритет, повторение и напоминание из естественного текста — поля задачи проставляются автоматически (ручной выбор перекрывает NL).

- [x] **Настраиваемые свайпы (2026-06-23):** действия свайпа по задаче (влево/вправо) теперь настраиваются пользователем; единый паттерн `SwipeToDelete`/действий переиспользован.

- [x] **Звук (2026-06-23):** добавлены звуковые эффекты ключевых действий (завершение задачи / празднование); уважение системных настроек/выключения.

- [x] **Таймзона (2026-06-23):** корректная работа с часовым поясом пользователя для расписания/напоминаний/повторений (локальное время вместо UTC там, где это важно для пользователя).

- [x] **Жест месяца (2026-06-23):** в Plan добавлен жест переключения месяца в календарном представлении.

- [x] **Строгий режим (2026-06-23):** доработан «жёсткий тренер» (harsh-режим) — поведение/копирайт Kai и разборов в строгом тоне (по фидбэку пользователя о переделке дизайна строгого режима).

- [x] **Чистка: удалён мёртвый `ToneCopy` (2026-06-21):** класс `ToneCopy` (`core/settings/tone_provider.dart`) подтверждён неиспользуемым (UI давно на `KaiCopy`) — удалён (33 строки), живая tone-логика (`toneProvider`/`AppTone`) нетронута. `flutter analyze` 0, `flutter test` 247/247.

- [x] **Лендинг: настоящие Privacy + Terms (2026-06-21):** созданы `landing/privacy.html` и `landing/terms.html` (сбор данных, AI-поток, подписка $10/мес, отказ от гарантий, право РФ; контакт maxklodstapen@gmail.com) в едином стиле с index.html; плейсхолдер-ссылки в футере заменены на реальные. Ссылки на сторы не трогали (приложение не опубликовано).

- [x] **L10n: счётчик привычек plural-safe (2026-06-21):** последняя захардкоженная строка `'$count / $target today'` → ключ `habits.progress` на 12 языков. Остальные числовые формы уже шли через `plurals.dart`. `flutter analyze` 0, `flutter test` 238/238.

- [x] **Серверная синхронизация заморозок стрика (2026-06-21, ADR-044):** закрыт TODO(sync) из `freeze_accrual_service.dart`. Бэк: `Streak.lastFreezeAccrualAt` + миграция `add_freeze_accrual_sync` (применена в Neon), `/sync` принимает `streak{freeze_count,last_freeze_accrual_at}` и мерджит по LWW (курсор), `serializeStreak` отдаёт `last_freeze_accrual_at`, контракты (api-spec/data-model) обновлены, jest 127/127 (+8). Клиент: `sync_service` шлёт freeze-блок и адоптирует серверные значения как авторитетные (без двойного начисления), `flutter test` 247/247 (+9). Заморозки синхронизируются между устройствами.

- [x] **Экономика заморозок стрика (2026-06-20, ветка design-kai):** Реализовано начисление заморозок (ранее только тратились). Новый `app/lib/services/streak/freeze_accrual_service.dart`: чистая функция `computeAccrual` + класс `FreezeAccrualService` (Drift + SharedPreferences). Правила: Free +1/30 дней, Premium +1/14 дней; при покупке Premium +2 бонуса (`grantPurchaseBonus` в `paywall_screen.dart`). Пороги наград: 10 заморозок → +7 дней Premium, 25 → +30, 50 → +90 (каждый порог один раз, хранятся в prefs `freeze_reward_claimed_thresholds`). «Выдать Premium» = `local_premium_until` в prefs; `isPremiumProvider` в `auth_controller.dart` расширен: проверяет оба источника — серверный tier и локальный override. `ProfileScreen` переведён в `ConsumerStatefulWidget`; при открытии вызывает `accrueIfNeeded` с показом SnackBar на начисление/награду. Карточка стрика заменена на `_FreezeCard` с прогресс-баром (`LinearProgressIndicator`) к ближайшему порогу. L10n: 10 новых ключей (`streak.freeze_*`) на все 11 языков в `profile_paywall.dart`. `flutter analyze` 0. `freeze_accrual_test.dart` 17/17. TODO(sync): серверная синхронизация `last_freeze_accrual_at` + `freezeCount` — отдельная задача.

- [x] **Финальная зачистка локализации (2026-06-20, ветка design-kai):** Добавлены ключи на все 12 языков для остатка захардкоженных пользовательских строк: `paywall.premium_feature_upsell` ({feature}), `today.failed_to_load` ({err}), `costudy.*` (not_found_email/friends_studying_one/many/studying_label/session_code_eg), `error.generic` ({err}, заменил `'Error: $e'` в habits/sleep/water/diary-history/goals) + `error.loading_workouts`, метки KaiLoader через существующие `loading.*`. Обоснованно пропущено: dev-only строки в `if(kDebugMode)` пейвола, preview-текст редактора тем, класс `ToneCopy` (подтверждён мёртвым — UI на context-версии `KaiCopy`). Полнота по 12 языкам проверена грепом, `flutter analyze` 0, `flutter test` 189/189.

- [x] **Шрифты hi/ja/ko вшиты + скриншот-тест локалей (2026-06-20, ветка design-kai):** Деванагари/японский/корейский тянулись google_fonts из сети рантаймом → «вспышка тофу-квадратиков» 2-5 с на первой загрузке (и не работало офлайн). Вшил `NotoSansDevanagari/JP/KR.ttf` (~20 МБ) в `app/assets/fonts/`, объявил в `pubspec.yaml`, `app_theme.dart` `fontFamilyFallback` теперь ссылается на вшитые семейства → мгновенный рендер, работает офлайн. Новый `app/test/locale_gallery_test.dart`: рендерит ~12 ключевых строк на каждой из 12 локалей и пишет голдены `test/goldens/locale_<tag>.png` (12 PNG); грузит вшитые Noto + латино-кириллический `test/fixtures/NotoSans.ttf` → все письменности рисуются в headless-тесте. Визуальная проверка: тофу нет, переводы реальные. Заодно пофикшен баг видимого обратного слэша (`\\'` в misc.dart, 23 строки). `flutter analyze` 0, тест 12/12.

- [x] **Локализация: 12 языков + ИИ на языке пользователя (2026-06-20, ветка design-kai, ADR-043):** Расширение с 3 до 12 языков (en, ru, de + fr, it, pt-BR, id, hi, ja, ko, es-LatAm, es-ES) = список Claude + наши. Словарь `app/lib/core/l10n/strings/*.dart` (9 файлов, ~868 ключей) заполнен по КАЖДОМУ ключу для всех языков пачкой из 9 агентов-переводчиков (по файлу на агента); полнота проверена грепом (8 новых колонок == числу ключей в каждом файле, гарантия «нет половины на английском»). Инфраструктура: `locale_provider.dart` (12 локалей, `LocaleEntry`-список с двумя испанскими отдельно, `localeTag`, persist полным тегом с countryCode), резолвер `app_strings.dart` (региональный откат `entry[tag] ?? entry[lang] ?? en ?? key`: pt-BR→pt, es-ES→es, es-419→es), `plurals.dart` (Intl.plural для всех языков; ja/ko/id/hi — одна форма, fr — 0/1 ед.ч.), шрифты `app_theme.dart` (`fontFamilyFallback` Noto Sans Devanagari/JP/KR ко всем TextStyle — иначе hi/ja/ko «квадратики»), переключатели языка в Профиле + онбординге (12 пунктов). ИИ: `backend/src/routes/ai.ts` `langName()` расширен (fr/it/pt/id/hi/ja/ko/es; slice до 2 букв сворачивает регион-теги) — все 5 AI-функций теперь отвечают на языке пользователя через Accept-Language. Заодно влиты правки plural-локализации RU/DE (workouts/breathing/costudy/meditation/posture/recipes/workout_trainer + `plurals.dart`). Гейты: `flutter analyze` 0, `flutter test` 177 passed, backend jest 120/120. **На ревью пользователя:** качество машинного перевода + рендер хинди/японского/корейского на устройстве (шрифты google_fonts тянутся рантаймом).

- [x] **Kai-дашборд виджет Android (2026-06-20, ветка design-kai):** Второй Android-виджет — «ретеншн»-виджет с Kai крупным по центру. Не трогает основной task-виджет. Новые файлы: `res/layout/kai_widget.xml` (Kai 96dp + стрик нейтральным цветом + X/Y главных мелко, фон widget_bg скругление 24dp), `res/xml/kai_widget_info.xml` (targetCell=3×3, updatePeriodMillis=1800000), `KaizenKaiWidgetProvider.kt` (читает тот же prefs-файл `kaizen_widget` — те же ключи что пишет widget_service.dart: streak/kai_emotion/is_harsh/main_done/main_total/theme_*/last_opened_at; away-логика ≥2 дней; getIdentifier `kai_<emotion>[_harsh]`; setColorFilter accent на глаза; PendingIntent requestCode=400, FLAG_IMMUTABLE|FLAG_UPDATE_CURRENT, widget_action=open_today). `AndroidManifest.xml` — добавлен `<receiver android:name=".KaizenKaiWidgetProvider" android:exported="false">`. Dart не менялся. `./gradlew mergeDebugResources compileDebugKotlin` → BUILD SUCCESSFUL. `flutter analyze` 0.

- [x] **Widget deep-links (2026-06-20, ветка design-kai):** Разные зоны виджета ведут в разные места приложения. Android: `KaizenWidgetProvider.kt` — заменены единые `openApp` PendingIntent-ы на отдельные с уникальными requestCode: фон/Kai → `widget_action=open_today` (RC 100/101/200/203/300/306), строки задач → `widget_action=open_day&widget_date=yyyy-MM-dd` (RC 201-202, 301-304), кнопка «+» → `widget_action=add_task` (RC 305). `FLAG_IMMUTABLE|FLAG_UPDATE_CURRENT`, `FLAG_ACTIVITY_SINGLE_TOP`. `MainActivity.kt` расширен: cold start — `extractWidgetAction` в `onCreate` сохраняет extras как pending; Flutter вызывает `getLaunchAction` (новый метод в MethodChannel), нативка возвращает `{action, date?}` и очищает (read-once); warm start — `onNewIntent` зовёт `channel.invokeMethod("onWidgetAction", map)`. Новый Flutter-сервис `app/lib/services/widget/widget_actions.dart`: `initWidgetActions(WidgetRef ref)` — регистрирует handler `onWidgetAction` (warm) + post-frame вызов `getLaunchAction` (cold); маршрутизация: `open_today` → `router.go('/today')`, `open_day` → устанавливает `selectedDayProvider` + `router.go('/plan')`, `add_task` → `showAddTaskSheet(context, day: today)`. Вызов `initWidgetActions(ref)` добавлен в `initState` `KaizenAppState` (main.dart). iOS [iOS-UNVERIFIED]: `AppDelegate.swift` — добавлен `application(_:open:options:)` для обработки `kaizen://` URLs, `parseWidgetURL` расставляет action/date (cold→pending, warm→invokeMethod), новый метод `getLaunchAction` в MethodChannel handler. `KaizenWidgetView.swift` — строки задач в `LargeWidgetView` обёрнуты в `Link(destination: URL("kaizen://widget/day?date=\(todayISOString)"))`, кнопка «+» уже была `Link("kaizen://add-task")`, `.widgetURL("kaizen://widget/today")` на small/medium/large. `docs/SETUP-ios-widget.md` §6 обновлён: таблица URL-зон. `flutter analyze` — 0. `flutter build apk --debug` → BUILD SUCCESSFUL.

- [x] **iOS WidgetKit Extension — исходники + гайд (2026-06-20, ветка design-kai):** Созданы 4 Swift-файла в `app/ios/KaizenWidget/`: `KaizenWidget.swift` (`@main WidgetBundle`, `StaticConfiguration`, `.systemSmall/.systemMedium/.systemLarge`), `Provider.swift` (`TimelineProvider` — читает App Group UserDefaults `group.com.kaizen.app`, строит Timeline с записями на +1h/+24h/+48h для away-эмоции без запуска приложения), `KaizenEntry.swift` (модель данных + `Color(hex:)` хелпер + placeholder/empty), `KaizenWidgetView.swift` (SwiftUI-вьюхи трёх размеров: `SmallWidgetView`/`MediumWidgetView`/`LargeWidgetView` + `KaiPeekView` — PNG с `.renderingMode(.template).foregroundColor(accent)`). Создан `Assets.xcassets` с 8 imageset-заглушками (Contents.json, rendering-intent=template; PNG копируются вручную на Mac). `app/ios/Runner/AppDelegate.swift` расширен: MethodChannel `kaizen/widget` → `handleUpdateWidget` → App Group UserDefaults + `WidgetCenter.shared.reloadAllTimelines()`. `app/lib/services/widget/widget_service.dart` обновлён: `if (kIsWeb) return` заменён на проверку `android || iOS`; payload без изменений (тот же MethodChannel). Гайд `docs/SETUP-ios-widget.md` — 10 шагов для Mac/Xcode (target, App Groups, PNG в Asset Catalog, URL scheme, минимум iOS 14). `flutter analyze` 0. Сборка/проверка невозможна без Mac.

- [x] **Локализация виджета Android (2026-06-20, ветка design-kai):** Нативные Android string resources для домашнего виджета. Создан `res/values/strings.xml` (EN, дефолт) с ключами `widget_up_next`, `widget_today`, `widget_nothing_today`, `widget_nothing_scheduled` + `app_name`. Созданы `res/values-ru/strings.xml` (RU) и `res/values-de/strings.xml` (DE). В `KaizenWidgetProvider.kt` заменены захардкоженные литералы `"Nothing today"` (buildSmallViews, buildMediumViews) на `context.getString(R.string.widget_nothing_today)`. В layout XML заменены: `"Today"` → `@string/widget_today` (kaizen_widget_large.xml), `"Nothing scheduled"` → `@string/widget_nothing_scheduled` (kaizen_widget_large.xml), `"Up next"` → `@string/widget_up_next` (kaizen_widget_medium.xml), `"Nothing today"` → `@string/widget_nothing_today` (kaizen_widget_small.xml). Сборка: `gradlew :app:mergeDebugResources :app:compileDebugKotlin` → **BUILD SUCCESSFUL** (21s, 135 tasks: 10 executed, 125 up-to-date).

- [x] **Kai PNG-ассеты для нативного виджета (2026-06-19, ветка design-kai):** Добавлена публичная функция `renderKaiPng(...)` в `app/lib/features/mascot/kai_mascot.dart` — рендерит статичный кадр Kai через `PictureRecorder`+`_KaiPainter` без виджет-дерева (статичные параметры: дыхание=0.5, моргание=0, взгляд=0, jitter=0, thinkPulse=0). Скрипт генерации `app/test/generate_kai_assets_test.dart` (`flutter test test/generate_kai_assets_test.dart`) создаёт **48 PNG** (4 эмоции × 2 harsh-варианта × 5 плотностей) с белыми глазами (accent накладывается native через `setImageTintList`/`ColorFilter`) и прозрачным фоном: `drawable-{mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi}/kai_{neutral,success,anxious,away}[_harsh].png` + копия xxxhdpi в `assets/kai_widget/` для iOS. Папка `assets/kai_widget/` зарегистрирована в `pubspec.yaml`. `flutter analyze` 0. Повторная генерация: `flutter test test/generate_kai_assets_test.dart`.

- [x] **Серверный entitlement — каркас гибридного биллинга (2026-06-19, ветка design-kai):** ADR-041. Добавлены поля `premiumUntil DateTime?` и `premiumSource String?` в `User` (Prisma-схема + миграция `20260619000000_add_entitlement_fields` применена к Neon). Новый хелпер `src/models/entitlement.ts` — `resolveEntitlement(user)` → `{isPremium, premiumUntil, source}`; правило: `isPremium = subscriptionTier="premium" ИЛИ (premiumUntil!=null && premiumUntil>now)`. `serializeUser` расширен: `is_premium`, `premium_until`, `premium_source` (snake_case, ADR-008). Новый эндпоинт `GET /api/v1/subscription/status` (requireAuth) → `{is_premium, premium_until, source}`. Новый файл `src/routes/billing.ts` — 5 заглушек вебхуков `POST /api/v1/billing/webhook/{apple|google|rustore|stripe|yookassa}` (Zod-валидация тела, защита через `BILLING_WEBHOOK_SECRET` из env если задан, TODO-комментарии по реальным подписям). Зарегистрированы в `app.ts`. AI-гейты `ensurePremium` в `routes/ai.ts` переведены на `resolveEntitlement` (теперь учитывают и legacy subscriptionTier, и срочный premiumUntil). Обновлены контракты: `docs/api-spec.yaml` (+GET /subscription/status, +5 вебхуков, +is_premium/premium_until/premium_source в схеме User, +BillingWebhookRequest/Response), `docs/data-model.md` (+2 колонки Users). Jest: 120/120 (11 сьютов, +1 новый `entitlement.test.ts` с 10 тестами).

- [x] **«Повторить меню прошлой недели» (2026-06-19, ветка design-kai):** Новая кнопка `TextButton.icon(Icons.history)` «Repeat last week» размещена под кнопкой «Build my day with AI» на экране `food_screen.dart`. По тапу: `_repeatLastWeek` читает food_logs за тот же день недели 7 дней назад (`FoodLogsDao.logsForDay`), создаёт новые companion-объекты с новыми UUID и датой = сегодня, батч-вставляет через `FoodLogsDao.addLogsAll` (каждый лог попадает в стандартный синк-путь). Показывает `showUndoSnackBar` «N meal(s) copied from last {weekday}» — по Undo вызывает `deleteLogsById(insertedIds)`, который удаляет ровно ту партию. Если за прошлую неделю ничего нет — SnackBar «Nothing logged last {weekday}», краша нет. Новые DAO-методы: `logsForDay(DateTime)` (одноразовое чтение за дату), `addLogsAll(List<Companion>)` (batch + возвращает вставленные ids), `deleteLogsById(List<String>)` (batch delete by ids). Drift-схема не изменена. L10n (en/ru/de): `food.repeat_week`, `food.repeat_week_tooltip`, `food.repeat_week_done`, `food.repeat_week_empty`. `flutter analyze` 0, `flutter test food_*.dart` 13/13.

- [x] **Безопасное удаление логов еды + «Недавнее» (2026-06-19, ветка design-kai):** ЗАДАЧА 1 — `_FoodRow` в `food_screen.dart` обёрнут в `SwipeToDelete` (свайп влево = удалить); кнопка-корзина (X) теперь также использует паттерн снапшот→удалить→`showUndoSnackBar`→Undo. Метод `_deleteWithUndo`: снапшот лога → `foodLogsDao.deleteLog(id)` → snackbar `"<name> removed"` → Undo → `foodLogsDao.restoreLog(snapshot)` (insertOnConflictUpdate). Новые DAO-методы в `FoodLogsDao`: `restoreLog(FoodLogsTableData)` и `recentDistinctLogs({int limit})` (raw SQL: GROUP BY name + MAX created_at, без изменения схемы). L10n: `food.log_removed`, `food.recent_title`, `food.recent_log_added` в `strings/food.dart` (en/ru/de). Импорты: `swipe_to_delete.dart` и `undo_snack_bar.dart` добавлены в `food_screen.dart`. ЗАДАЧА 2 — Секция «Недавнее» в `_FoodSearchSheet`: при пустом поисковом запросе вместо пустого листа отображаются последние 10 уникальных (дедуп по name) продуктов из истории food_logs. Тап = 1 касание логирует продукт повторно (те же граммы и приём из последней записи, КБЖУ из записи без сети). Источник данных: `recentDistinctLogs()` через `_FoodSearchSheetState.initState`. При вводе текста → обычный поиск как прежде. `flutter analyze` 0, `flutter test food_*.dart` 13/13.

- [x] **Безопасное удаление: привычки + шаги целей (2026-06-19, ветка design-kai):** ЗАДАЧА 1 — `habits_screen.dart`: оба типа карточек (`_GoodHabitCard`, `_BadHabitCard`) обёрнуты в `SwipeToDelete` (свайп влево = удалить); в PopupMenuButton добавлен пункт «Удалить» (ember-цвет) рядом с «В архив» — оба способа работают. Метод удаления `_deleteHabit`: снапшот записи → `habitsDao.deleteHabit(id)` → `showUndoSnackBar` → Undo → `restoreHabit(snapshot)` (insertOnConflictUpdate, тот же id). **Прогресс не теряется**: `HabitLogsTable` при удалении НЕ удаляется (нет CASCADE), после Undo та же запись возвращается по тому же id и логи снова видны. Новые DAO-методы в `HabitsDao`: `deleteHabit(String id)`, `restoreHabit(HabitsTableData snapshot)`. ЗАДАЧА 2 — `goals_screen.dart`: строка каждого шага обёрнута в `SwipeToDelete`; в trailing добавлена кнопка-корзина (delete_outline, textMuted) рядом с «plan today» — оба способа. Метод `_deleteStep`: снапшот → `goalsDao.removeStep(id)` → `showUndoSnackBar` → Undo → `restoreStep(snapshot)` (сохраняет id, goalId, title, done, sortOrder, обновляет updatedAt цели). Удаление всей цели НЕ затронуто. Новый DAO-метод в `GoalsDao`: `restoreStep(GoalStepsTableData snapshot)`. L10n: `habit.removed`, `habits.delete` в `strings/health_a.dart`; `plan.step_removed`, `plan.step_delete_tooltip` в `strings/plan_diary.dart` (en/ru/de). `flutter analyze` — 1 pre-existing warning в `food_screen.dart` (не затронут). `flutter test goals_dao_test.dart` 10/10.

- [x] **UX-полиш FAB «+ Add» (2026-06-19, ветка design-kai):** UX-LAYOUT §9.1 — три улучшения поверх готовых экранов. (1) Зазор: `CollapsingFab` теперь имеет `extraBottomMargin: 16dp` по умолчанию — добавляется к стандартному 16dp Scaffold, итого ≥32dp чистого воздуха над nav-bar. (2) Тень: параметр `elevation: 4.0` переопределяет тему (`elevation: 0`), FAB получает видимую тень и читается как отдельный слой над контентом. (3) Анимация: длительность collapse-on-scroll изменена `kDurationFast(180ms) → kDurationNormal(280ms)` по ANIMATIONS.md §0; reduce-motion → мгновенное переключение (Duration.zero). Tablet-FAB на Today и Plan тоже получили `elevation: 4`. Изменённые файлы: `core/widgets/collapsing_fab.dart`, `features/today/today_screen.dart`, `features/plan/plan_screen.dart`. 360px: свёрнутый FAB (~56dp) не перекрывает Diary-подпись, expanded - тоже (nav-bar ниже). `flutter analyze` 0.

- [x] **Food preferences profile (2026-06-19, ветка design-kai):** Новый `core/settings/food_preferences_provider.dart` — класс `FoodPreferences` (diet/goal/dislikes/likes/mealsPerDay, `isEmpty`, `toApiMap()` snake_case, пропускает дефолтные поля), `FoodPreferencesNotifier`, `foodPreferencesProvider`; ключи `food_diet`, `food_goal`, `food_dislikes`, `food_likes`, `food_meals_per_day`. `computeNutritionTargets` получил опциональный параметр `String goal='maintain'` — множитель TDEE: lose×0.85/gain×1.15/maintain×1.0; макросы пересчитываются от скорректированных ккал. `nutritionTargetsProvider` читает `food_goal` из prefs. `aiMenuBuild` в `api_client.dart` получил `Map<String,dynamic>? foodPrefs` → тело POST `food_prefs` (только если непустой). `ai_menu_sheet.dart` читает `foodPreferencesProvider` и передаёт `fp.isEmpty ? null : fp.toApiMap()`. Профиль: секция `_FoodPreferencesSection` — ChoiceChip диета ×8, SegmentedButton цель ×3 (lose/maintain/gain), SegmentedButton приёмы пищи ×3, VoiceTextField dislikes/likes; заметка «Used to personalise your AI menu». L10n: 27 ключей `food_prefs.*` (en+ru+de) в `strings/health_a.dart`. `flutter analyze` 0, `flutter test nutrition_targets_test.dart` 21/21 (6 новых тестов: maintain=base, lose/gain порядок, closeTo 5, макросы, unknown goal).

- [x] **Plan: pinned exam card + l10n sweep (2026-06-19, ветка design-kai):** JOB 1 — ближайший предстоящий exam/deadline теперь закреплён НАД прокручиваемым контентом Plan (Day и Week). Новый `nearestExamDeadlineProvider` (StreamProvider, ищет [today, +365d), фильтр exam/deadline, берёт ближайший по scheduledAt) в `plan_providers.dart`. Новый виджет `pinned_exam_card.dart` (`PinnedExamCard`): ember-рамка 1.5dp, иконка типа (school/flag), название + обратный отсчёт через `plan.countdown_*`, тап → `showAddTaskSheet` + переключение selectedDay; скрыт если нет предстоящего. В `plan_screen.dart` вставлен в `_bodyContent` и `_bodyContentTablet` для Day/Week (поверх WeekStrip/Divider, вне скролла). 2 новых l10n-ключа (`plan.pinned_type_exam`, `plan.pinned_type_deadline`, en+ru+de). JOB 2 — `morning_review_card.dart` и `evening_review_card.dart` заменили `ToneCopy.morningReview/eveningReview(tone,…)` на `KaiCopy.morningReview/eveningReview(context,tone,…)` — тексты теперь полностью локализованы (EN/RU/DE). `ToneCopy` сохранён как mixin без использования в UI. `flutter analyze` 0 ошибок.

- [x] **Kai prominent + speech bubble + ToneCopy l10n (2026-06-19, ветка design-kai):** Kai в шапке Today увеличен до 104dp и стал центральным якорем экрана (был 56dp в углу). Добавлена `_KaiHeaderSection`: Kai сверху по центру, под ним `KaiSpeechBubble` с текущим сообщением (контекст-зависимое), ниже — приветствие + тумблер тона в строке. Новый виджет `app/lib/features/mascot/kai_speech_bubble.dart` — `KaiSpeechBubble` (surface-карточка + хвостик-треугольник, fade+rise 280ms, reduce-motion safe, `KaiBubbleTail.bottomCenter/rightCenter`). Анимация внимания в `_KaiHeader`: bounce −8px каждые 6–10 с (elasticOut 420ms, отменяется при reduce-motion). Emotion `away` теперь тригерится на пустой день (allItems.isEmpty + данные загрузились). `ToneCopy` сохранён для BC; добавлен `KaiCopy` с методами morningReview / allDone / eveningReview / emptyDay / idle (принимают BuildContext, резолвят через S.of). L10n: 18 новых ключей `kai.*` в `strings/today.dart` (en+ru+de). `celebration_overlay.dart`: Kai вырос до 96dp; harsh-тон — нейтральная эмоция без spring-scale (сдержанный кивок, MASCOT.md §6). `flutter analyze` 0 ошибок.

- [x] **Health profile (2026-06-19, ветка design-kai):** Профиль здоровья пользователя — 3 вопроса (аллергии/заживление/дефициты) с голосовым вводом. Новые файлы: `core/settings/health_profile_provider.dart` (класс `HealthProfile`, `HealthProfileNotifier`, `healthProfileProvider`; prefs-ключи `health_allergies`, `health_healing`, `health_deficiencies`), `core/widgets/voice_text_field.dart` (`VoiceTextField` — ConsumerStatefulWidget, STT как в food_screen.dart, mic скрыт на вебе). Онбординг: новый шаг 7 «Health profile» (после нормы воды; `_pageCount` 6→7; сохраняется в `_finish`). Профиль: секция `_HealthProfileSection` (inline-редактор с 3 VoiceTextField + Save, просмотр уже заполненных значений). API: `aiMenuBuild` получил опциональный параметр `healthProfile: Map<String, String>?`; включается в тело POST как `health_profile: {allergies, healing, deficiencies}` только если непустой. `ai_menu_sheet.dart` читает `healthProfileProvider` и передаёт в `aiMenuBuild`. L10n: 10 ключей `health_profile.*` (en+ru+de) в `strings/health_a.dart`. `flutter analyze` 0.

- [x] **Локализация: исправление калорий AI-меню + sweep EN→l10n (2026-06-19, ветка design-kai):** JOB 1 — `ai_menu_sheet.dart` теперь читает `nutritionTargetsProvider.kcal/.proteinG` вместо устаревших `calorieGoalProvider`/`proteinGoalProvider`; AI-меню получает реальные ~2500–3000 ккал пользователя. JOB 2 — sweep пользовательских EN-строк: добавлены 51 ключ (en+ru+de) в `strings/{common,today,health_a,plan_diary,profile_paywall,food}.dart`; устранены хардкод-строки в 11 файлах: `profile_screen.dart` (text_size опции, заголовок «чужого плана», «Copy to my plan», «N events copied»), `add_task_sheet.dart` (тип-чипы, приоритет-чипы), `today_screen.dart`/`plan_screen.dart` (FAB «+ Add»), `health_screen.dart` (+250/+500 ml, snackbar ночи), `diary_screen.dart`/`diary_insight.dart` (недельный инсайт локализован через `WeeklyInsightData.resolve(context)` — строки резолвятся в виджете с BuildContext), `food_screen.dart`/`recipe_editor_screen.dart`/`ai_menu_sheet.dart` (KaiLoader-метки, snackbar рецепта, snackbar «нужно продуктов», название приёма пищи). `buildWeeklyInsight` сохранён как совместимый shim для unit-тестов. `flutter analyze` 0.

- [x] **Персональные нормы питания (2026-06-19):** Онбординг (шаг «нормы»): добавлены поля **Age** и **Sex** (Male/Female/Other) рядом с весом/ростом/активностью; сохраняются в SharedPreferences (`kUserAgeKey='user_age'`, `kUserSexKey='user_sex'`). `recommendedWaterMl` получил опциональный параметр `int? age` — мягкая поправка для возраста >30 лет (`clamp(1-(age-30)*0.001, 0.95, 1.0)`). Новый файл `core/settings/nutrition_targets.dart`: класс `NutritionTargets`, чистая функция `computeNutritionTargets` (Мифлина–Сан-Жеор; активность low/medium/high; макросы protein=1.6g/kg, fat=25%/9, carbs=оставшееся, fiber=14g/1000kcal, sugarMax=10%kcal/4; clamp kcal [1200,4000]), провайдер `nutritionTargetsProvider` (читает префы, fallback kcal=2000). `_BalanceCard` и `_TotalsCard` (теперь ConsumerWidget) используют `nutritionTargetsProvider` вместо захардкоженных констант; `_TotalsCard` показывает «съедено / норма» для каждой метрики. `evaluateDayBalance` сигнатура не изменена — все существующие тесты проходят. `nutrition_targets_test.dart` — 15 тестов (male/female/other, clamp min/max, fallback, activity ranking). `flutter analyze` 0, `flutter test ...` 34/34.

- [x] **Tap-to-module (2026-06-19):** Drift v12 — колонка `moduleLink` (nullable text) в `ItemsTable`; миграция `addColumn`. Кодогенерация `database.g.dart` обновлена. Пикер «Open in module» (DropdownButton: None / Workout / Breakfast / Lunch / Dinner / Sleep) в `add_task_sheet.dart` — сохраняет значение в локальную БД, не попадает в синк. `task_list.dart`, `day_timeline.dart`, `week_agenda.dart`: иконка-аффорданс (`fitness_center` / `restaurant` / `bedtime`, textMuted) и тап → `/workouts` / `/food` / `/sleep-report`; долгий тап → редактирование; свайп-гесты и обычное поведение без moduleLink не затронуты. 7 l10n-ключей в `strings/today.dart` (en+ru+de). `flutter analyze` 0, tests 115/118 (3 pre-existing failures: PaywallScreen / DiaryScreen / ShoppingListScreen — не связаны с этой задачей).

- [x] **Android-виджет Фаза 2 — адаптивные раскладки, task-focused, темизация, Kai-peek, away-по-таймеру (2026-06-19, ветка design-kai):** Три XML-раскладки: `kaizen_widget_small.xml` (2×2: 1 пункт + X/Y + стрик + Kai в нижнем правом углу), `kaizen_widget_medium.xml` (4×2: 2 пункта + X/Y + стрик + Kai справа-сверху), `kaizen_widget_large.xml` (4×4: до 4 строк row1..row4 GONE/VISIBLE + X/Y + стрик + Kai + кнопка «+»). Выбор раскладки: API 31+ — `RemoteViews(Map<SizeF, RemoteViews>)` responsive; < API 31 — по `OPTION_APPWIDGET_MIN_WIDTH/HEIGHT`. `KaizenWidgetProvider.kt` полностью переписан: парсинг next_items (JSONArray, до 4 пунктов), иконки типов (event◆/exam★/deadline⚑/task●), темизация цветов из SharedPreferences (`safeColor`+`Color.parseColor`), фоновый цвет `setBackgroundColor(theme_surface)`, акцент глаз Kai `setInt("setColorFilter", theme_accent)`, ресурс выбирается через `getIdentifier("kai_<emotion>[_harsh]", "drawable")`. Away-логика: если `last_opened_at` старше ≥2 дней (`ChronoUnit.DAYS.between(Instant.parse(…), Instant.now())`) — emotion переопределяется в "away" (API 26+). `onAppWidgetOptionsChanged` переопределён для перерисовки при ресайзе. `kaizen_widget_info.xml`: `updatePeriodMillis=1800000` (30 мин), `targetCellWidth=4/targetCellHeight=2`, `previewLayout=kaizen_widget_medium`, `minWidth=110dp/minHeight=110dp`. `MainActivity.kt` расширен: сохраняет все 12 ключей payload (next_items, main_done, main_total, streak, kai_emotion, is_harsh, theme_*, last_opened_at). Стрик везде нейтральным `theme_text_muted`, accent — только глаза Kai. `./gradlew assembleDebug` BUILD SUCCESSFUL, `flutter analyze` 0 ошибок.

- [x] **Единый паттерн безопасного удаления — SharedComponents + Recipe + Workout (2026-06-19, ветка design-kai):** Создан переиспользуемый API для всех экранов: `core/widgets/swipe_to_delete.dart` — `SwipeToDelete` (обёртка над Dismissible, direction endToStart, ember-фон, key обязателен, onDelete-колбэк); `core/widgets/undo_snack_bar.dart` — `showUndoSnackBar(context, {message, onUndo})` (floating SnackBar, 4 сек, border из темы, `hideCurrentSnackBar` перед показом, кнопка Undo с accent-цветом). DAO-методы восстановления: `RecipesDao.restoreIngredient(snapshot)` и `WorkoutsDao.restoreExercise(snapshot)` — insertOnConflictUpdate по оригинальному id, обновляют updatedAt родителя. `recipe_editor_screen.dart` переведён на ConsumerStatefulWidget, единый метод `_deleteIngredient` (снапшот → delete → showUndoSnackBar → Undo→restoreIngredient) + кнопка-корзина trailing рядом с граммами. `workout_editor_screen.dart` аналогично: `_deleteExercise` + корзина trailing в `_ExerciseCard`. L10n: добавлены `common.undo` (en/ru/de), `food.ingredient_removed` (en/ru/de), `workout.exercise_removed` (en/ru/de). `flutter analyze` 0 ошибок.

- [x] **Widget data-bridge расширен §8 WIDGET.md (2026-06-19, ветка design-kai):** Data-bridge Flutter→виджет расширен под новый дизайн. DAO: добавлены `ItemsDao.upcomingTodayItems(now)` (до 4 ближайших pending-пунктов сегодняшнего дня от now, limit 4) и `ItemsDao.hasOverdueItems(now)` (bool, есть ли pending со scheduledAt < now). Новый файл `app/lib/services/widget/kai_widget_emotion.dart`: чистая функция `computeKaiWidgetEmotion` → 'away'|'anxious'|'success'|'neutral' (lastOpenedAt==null ≠ away). `saveLastOpenedAt()` пишет ISO timestamp в `last_opened_at` при старте и onResume. `refreshHomeWidget` расширен: `next_items` (JSON '[{time:HH:mm, title, type}]'), `main_done`/`main_total` (int), `kai_emotion`, `is_harsh` (bool), цвета темы hex `#RRGGBB` (`theme_accent`/`theme_bg`/`theme_surface`/`theme_text`/`theme_text_muted`), `last_opened_at` (ISO). Старые `main_progress`/`streak` сохранены. 11 юнит-тестов в `test/kai_widget_emotion_test.dart` — все зелёные. `flutter analyze` 0.

- [x] Смелый редизайн дизайн-системы (2026-06-19, ветка `design-kai`): блюпринт `docs/design/01-05` (палитры с проверкой WCAG AA, типошкала, компоненты, Kai 2.0, редактор тем). Центральная тема `app_theme.dart`: новые роли (surfaceElevated/textFaint/accentMuted/success/borderStrong во всех 5 темах), типошкала (display 56 / headline 40, заголовки фирменным серив-шрифтом), темизация компонентов (кнопки 12dp/52px, карточки/поля/чипы/навбар M3 NavigationBar, нулевые тени, hairline-границы). Раскатка по ВСЕМ экранам (Стадия 5b, 3 волны): Today/Plan/Health/Food/Diary/Profile/Paywall/Onboarding/Auth/Focus/Import + под-экраны Health — замена хардкод-цветов/шрифтов на токены темы, акцент-дисциплина (убрана «стена лайма», нейтральные иконки), 24dp поля. Kai: размер 56dp, harsh композится с эмоцией, моргание/взгляд, `KaiLoader` (зверёк думает вместо спиннеров), присутствие на онбординге/входе/celebration/фокусе/разборе. `flutter analyze` 0 ошибок, web-сборка проходит. **Ждёт ревью пользователя** (мердж в main или откат на `9b1c75f`).

- [x] Custom Theme Editor (2026-06-19): 6-я тема «My Theme» — редактор `/profile/custom-theme` (переключатель dark/light, сетка 16 свотчей, HSV-пикер, слайдер тепла фона ±30°, живой превью AnimatedContainer kDurationNormal). Алгоритм вывода палитры: `CustomThemePalette.derive` (part-файл в `app_theme.dart`) реализует WCAG §2–§3: фон из `(accentHue, 0.08, 0.07)`, surface/elevated +0.06/+0.11 тёмный, бинарный поиск светлоты 32-итерации для text/textMuted/textFaint (CR≥4.5/4.5/3.0), авто-выбор onAccent (чёрный/белый CR≥4.5), коррекция акцента 20 шагами, откат на `#D9F24B`/`#2B6CB0`, ember с hue-shift при конфликте с акцентом, success с CR≥3.0. Персистенция: `CustomThemeNotifier` (Notifier, SharedPreferences, ключи `custom_theme_*`), холодный старт синхронный. `themeDataProvider` обновлён: `AppTheme.forKeyWithCustom(key, config)` — наблюдает оба провайдера. Профиль: 6-й чип + IconButton редактирования, тап без конфига → редактор, тап с конфигом → активация. Роут `/profile/custom-theme` зарегистрирован в `app_router.dart`. `flutter analyze` — 0 ошибок.

- [x] Локализация Health sub-screens (2026-06-19): 10 файлов (`workouts_screen.dart`, `workout_editor_screen.dart`, `workout_trainer_screen.dart`, `breathing_screen.dart`, `posture_screen.dart`, `meditation_screen.dart`, `screen_time_screen.dart`, `sleep_report_screen.dart`, `water_fullscreen_screen.dart`, `water_report_screen.dart`) локализованы через `context.s(...)`. `strings/health_b.dart` заполнен 66 ключами (en+ru+de) в пространствах `workout.*`, `breathing.*`, `posture.*`, `meditation.*`, `screentime.*`, `sleep.*`, `water.*`. Фазы дыхания (Inhale/Hold/Exhale) из `breathing_engine.dart` — switch-ключи остались на EN для логики цвета, отдельный `_localizePhaseLabel()` для отображения. `_exerciseSubtitle` получил `BuildContext` для «Отдых Ns». Пропущено (обоснованно): `'$count exercise${count == 1 ? '' : 's'}'` в `_WorkoutTile` (русские падежи множ. числа — рискованно без plural-библиотеки), названия/описания/шаги сессий медитации (данные в `const _sessions` — compile-time константы без доступа к context), имена категорий Screen Time (в `screen_time_provider.dart` — файл не принадлежит агенту), числовые метки длительности дыхания (`'1 min'`/`'3 min'`/`'5 min'`), `'+$ml ml'` кнопки воды, `'$mins min'` итоговое время тренировки, `'Error: $err'` debug-строки.

- [x] Локализация Today + BottomNav (2026-06-18): 72 строки в 8 файлах заменены на `context.s('today.*')` и `context.s('nav.*')`. `strings/today.dart` заполнен 53 ключами (en+ru+de). Охват: `scaffold_with_nav_bar.dart` (nav-метки BottomNav + NavigationRail + AppBar через `nav.*`), `today_screen.dart` (_Header приветствие, _ToneToggle), `task_list.dart` (пустое состояние, секции, shield-tooltip, toast), `add_task_sheet.dart` (все метки, хинты, кнопки, диалоги, picker-меню), `morning_review_card.dart`, `evening_review_card.dart`, `review_variant_card.dart`, `celebration_overlay.dart`, `progress_ring.dart`, `streak_row.dart`. Переиспользованы existing common-ключи: `nav.*`, `today.greeting_*`, `today.main_tasks`, `btn.cancel`, `btn.delete`, `btn.add`. Пропущено обоснованно: `ToneCopy.*` строки (`tone_provider.dart` — не назначен файл), template-titles (`'Study session'` и др. в `_TemplatesRow` — технические id шаблонов), `"${item.title}" will be removed.` → заменено на показ только названия без prose-обёртки, `"${item.title}" marked as done` → split на `'"${item.title}" ${context.s('today.marked_done')}'`.

- [x] Локализация Profile + Paywall (2026-06-18): все пользовательские строки в `profile_screen.dart`, `terms_screen.dart`, `paywall_screen.dart` заменены на `context.s(...)`. `strings/profile_paywall.dart` заполнен 68 ключами (en+ru+de) в пространствах `profile.*` и `paywall.*`. Переиспользованы existing common-ключи: `profile.title`, `profile.language`, `profile.notifications`, `profile.text_size`, `settings.gentle`, `settings.harsh`, `streak.freeze`, `btn.sign_out`, `btn.sign_in`, `btn.cancel`. `_benefits` список преобразован из `title/subtitle` в `titleKey/subtitleKey`. Пропущено обоснованно: 2 plural-интерполяции (`$copied events...`, `Copy to my plan (N events)`), feature-интерполяция в `showPremiumUpsell`, debug-строки в `kDebugMode`-блоке, языковые эндонимы в Language-picker, строка версии, цена `$10`. Логика `_SharedWithMeCard` (TextEditingController lifecycle) и Kai-toggle не тронуты.

- [x] Локализация Food-модуля (2026-06-18): все пользовательские строки (`Text(...)`, `hintText`, `labelText`, `tooltip`, `AppBar`-заголовки, `SnackBar`, кнопки, макро-метки, балансовые подсказки, пустые состояния) в 6 файлах заменены на `context.s('food.*')`; `strings/food.dart` заполнен 52 ключами (en+ru+de). Баланс-подсказки вынесены в ключи (`food.hint_*`) — `evaluateDayBalance` теперь кладёт ключи в `hints`, `_BalanceCard` резолвит через `context.s()`. Пропущено (обоснованно): 6 интерполированных строк с динамическими данными (имя продукта/рецепта, код штрихкода, kMenuCandidatesMin, meal в SnackBar).

- [x] Локализация Plan + Diary (2026-06-18): 80 строк заменены `context.s(...)` в 7 файлах `features/plan/` + `features/diary/`; фрагмент `strings/plan_diary.dart` заполнен (ключи `plan.*` / `diary.*`, en + ru + de); `_issueLabels` в diary_screen + diary_history_screen заменены на l10n-ключи; `_horizonLabel` + `_countdownLabel` получили context-параметр; `const Text(...)` → `Text(context.s(...))` по всем 7 файлам. Пропущено: динамические инсайт-строки в `diary_insight.dart` (сложные интерполяции + русские падежи — слишком рискованно без plural-библиотеки) и строки `_LifeInsightsCard` (sleep/water, аналогично). `DateFormat` паттерны и маршруты не тронуты.

- [x] Маскот «Kai» — pure-Flutter реализация (2026-06-18): `KaiMascot` CustomPainter (6 выражений: neutral/success/thinking/harsh/anxious/away, squircle-тело, dash-глаза с асимметрией, морфинг через AnimationController, idle-дыхание ±2%, reduce-motion-safe); `showKaiProvider` (Riverpod+SharedPreferences, default true); Today-шапка: Kai рядом с _ToneToggle, эмоция по прогрессу main-задач, isHarsh от toneProvider; Profile: SwitchListTile «Show Kai» в Preferences.

- [x] Дизайн-слой: маскот «Kai» + раскладка «по науке» (2026-06-18) — зафиксированы как контракты `docs/MASCOT.md` (ADR-032: AI-присутствие, морфящийся squircle, глаза = акцент темы, тон gentle/harsh, Rive, off-toggle) и `docs/UX-LAYOUT.md` (ADR-033: навигация подтверждена по UX-законам + список шлифовки поверх готовых экранов). Подключено из SPEC §B4/§C, CLAUDE.md (таблица источников истины), app/CLAUDE.md (read-order + Rules). Реализация — в дизайн-бэклоге, ждёт Rive-ассет + живую проверку.

- [x] Аудит всего проекта (2026-06-10): сводка вынесена наверх этого файла (раздел «Сводка для пользователя») — реализовано/в процессе/не начато/баги/техдолг
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
- [x] C4 — долгосрочные цели (2026-06-11): Drift v9 (goals + goal_steps) + GoalsDao (10 юнитов) + /goals (горизонты Месяц/Год/5/10 лет, прогресс по шагам, чек-листы) + «Plan today» — шаг цели становится задачей на сегодня (связь с дневным планом из ТЗ) + флажок на Plan. Локально, без синка. flutter test 113/113
- [x] Ф3 — «поделились со мной» + копирование (SPEC C7, 2026-06-11): карточка в профиле → вставить ссылку/токен (extractShareToken, 9 юнитов) → GET /api/v1/share/:token → шит с планом по дням → «Copy to my plan» пишет события в локальные items (новые uuid, medium/pending → уйдут в синк). flutter test 103/103
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

## Ревью 2026-06-27 (фидбек пользователя — тестовая сессия, телефон + веб)

Контекст: тест после эпика «план как позвоночник». Веб на GitHub Pages показывает СТАРУЮ версию,
т.к. собран из `main`, а эпик живёт на ветке `night/...` (не мержена) — это ожидаемо, не баг.

### ⭐ ЯДРО КОНЦЕПЦИИ — повторяющийся вопрос пользователя (поднимался много раз)

- [ ] **Как планер относится к «размытым» задачам (важные, но без времени/дедлайна/оценки):** напр.
  «разобраться со сном» — важная, но нет времени, нет дедлайна, непонятно сколько тратить и как она
  вписывается в план. Сейчас такие задачи висят без связи с расписанием. Спроектировать явную модель
  «форм» задачи:
  • **конкретная** (есть время/длительность) → на таймлайн;
  • **с дедлайном** (гибкое время) → раскладывает движок;
  • **размытая/открытая** → помочь УТОЧНИТЬ: предложить грубый тайм-бокс, ИЛИ «когда сделать», ИЛИ
    разбить на конкретные шаги / перевести в Цель (Goals: «разобраться со сном» → «почитать 20 мин про
    гигиену сна», «отбой в 23:00»). Не оставлять аморфные задачи плавать без отношения к плану.
  Это ЦЕНТРАЛЬНЫЙ вопрос концепции «план как позвоночник», не баг. Высокий приоритет на проектирование.

### Бизнес / монетизация — пересмотреть

- [ ] **Пересмотреть модель подписки / как приложение зарабатывает:** сейчас freemium, $10/мес, без
  рекламы (ADR-052), ИИ только в платной. Продумать заново: цена (для РФ vs зарубеж — см. гибридный
  биллинг), что именно в платной vs бесплатной, годовой/месячный, триал, оценка выручки (сколько может
  приносить при N пользователей и конверсии), что мотивирует платить. Связать с реальной ценностью
  (умный перенос ИИ — главный платный hook). Не код, а стратегия — продумать и зафиксировать ADR.

### Авторизация / 406-ФЗ — решение (2026-06-27)

Контекст: РФ-закон 406-ФЗ запрещает российскому владельцу ресурса использовать иностранные
сервисы авторизации (Google/Apple OAuth и т.п.) как способ входа. Наш кейс: владелец — гражданин
РФ, аудитория РФ + (по позиционированию) зарубеж. Текущий код УЖЕ compliant: вход = телефон/почта
+ пароль на своём бэкенде (bcrypt+JWT), иностранный OAuth удалён (`auth_screen.dart:4`).
- [x] **СДЕЛАНО (5ebe968→main 1c90b2c): разрешён ЛЮБОЙ домен почты.** `email-domains.ts` по умолчанию
  пускает любой валидный домен (gmail и т.д.); ограничить — опц. через env ALLOWED_EMAIL_DOMAINS.
  Тесты обновлены (gmail/example.com → 201). Задеплоено на main→Render. Было ниже:
- [ ] ~~Разрешить ЛЮБОЙ домен почты (снять RU-only аллоулист).~~ Сейчас `backend/src/lib/email-domains.ts`
  пускает только российские провайдеры (mail.ru/yandex/vk.com/…), **gmail/outlook/icloud
  ЗАБЛОКИРОВАНЫ**. Это НЕ требование закона (закон про OAuth-сервисы, а не про почтовый адрес как
  строку — `user@gmail.com` с проверкой пароля нашим бэкендом легален) и РЕЖЕТ охват + противоречит
  «English first»/гибридному биллингу. Решение: по умолчанию разрешать любой валидный домен (env
  `ALLOWED_EMAIL_DOMAINS` оставить как опц. ограничитель; при пустом — пускать все). Обновить
  сообщение об ошибке. Деплой на main→Render. ADR в decisions.md.
- [x] **VK ID / Яндекс ID — НЕ добавляем** (решение пользователя 2026-06-27): лишние, непривычные,
  плодят кнопки. Минимализм.
- [x] **СМС-OTP — НЕ добавляем сейчас** (решение): телефон остаётся «телефон + пароль». СМС платный
  (нужен шлюз) и усложняет — не нужен.
- [ ] **Иностранный OAuth (Google/Apple) — НЕУВЕРЕННО, пока НЕ делаем, тему НЕ закрываем.** (Решение
  пользователя 2026-06-27.) Спорная зона 406-ФЗ: «доп-кнопка при наличии РФ-метода» по одному прочтению
  можно, по строгому — российскому владельцу иностранный OAuth лучше не использовать. При реальных
  штрафах — пока не подключаем, но и не вычёркиваем: держим как открытый вопрос на проработку (юрист +
  возможный сценарий «только для зарубежной аудитории/сборки», где закон не действует). Сейчас в коде
  иностранного OAuth нет. (Anthropic/Claude может — иностранная компания, закон на неё не
  распространяется; нам копировать нельзя.) Финал сверить с юристом под орг-форму (особенно ИП).
- [x] **Текущий метод входа:** email(любой, после снятия аллоулиста)+пароль и телефон+пароль, всё на
  своём бэкенде. Без СМС-OTP (платно), без VK/Яндекс, без иностранного OAuth (пока).
- [x] **Восстановление пароля — доставка email реализована (2026-06-30, ADR-059).** `backend/src/lib/email.ts`
  отправляет письмо с кодом через Resend HTTP API; `auth-reset.ts` forgot-password: если задан
  `RESEND_API_KEY` — письмо уходит реально и `dev_code` в ответе больше не раскрывается; без ключа —
  старое dev-поведение не сломано. Тесты замокали `lib/email` (не ходят в реальный Resend), `npm test`
  зелёный. **СДЕЛАНО (2026-07-02):** `RESEND_API_KEY` и `RESEND_FROM` заданы пользователем на Render —
  письмо уходит реально. Осталось проверить только «verified sender»: домен из `RESEND_FROM` должен
  быть подтверждён в дашборде Resend (DNS SPF/DKIM), иначе спам/отказ. (Устаревший текст ниже про
  «завести аккаунт Resend» оставлен для истории — не актуален.) Без ключей код работал бы в dev-режиме
  пользователи не получат письмо, пока ключ не выдан.
- [ ] **Пробел восстановления для телефонных аккаунтов.** forgot-password принимает только email;
  кто вошёл по «телефон+пароль» и забыл пароль — без email и без СМС восстановиться НЕ может.
  Рекоменд.: сделать email единым каналом сброса — просить/предлагать почту даже при регистрации по
  телефону (как контакт для восстановления). Решить вместе с подключением email выше.

### Баги (живые, с теста)

- [ ] **Plan — переключатель промежутка ломается:** плашка «День / 3 дня / Неделя / Месяц / Год»
  не влезает по ширине, подписи переносятся ВЕРТИКАЛЬНО по буквам (Д-е-н-ь в 4 строки). Переделать
  компактно: горизонтальный скролл / короткие подписи или иконки / выпадающий список. Это главный
  визуальный баг раздела Плана. (опровергает «адаптивная вёрстка готова» — см. ниже)
- [x] ~~Периодическая задача «не отображается»~~ — **НЕ баг (2026-06-27):** задача создана на будни,
  а проверяли в выходной → корректно не показывалась. Повторяющиеся задачи работают.
- [ ] **Plan — overflow 27px на 6-недельном месяце + пустой день:** когда развёрнутый месяц
  занимает 6 строк (напр. март: 1-е в 1-й строке, 30/31 в 6-й) И в выбранном дне нет задач (показан
  блок «импорт»), низ не помещается → «BOTTOM OVERFLOWED BY 27 PIXELS». Воспроизв.: режим день,
  месяц раскрыт полностью, день без задач (напр. 19 марта). Причина: высота 6-рядного календаря +
  пустое состояние/импорт не влезают в колонку. Фикс: сделать область скроллящейся / уменьшить
  фикс-высоту календаря / Expanded+SingleChildScrollView. Анти-регрессия gate B.
- [ ] **Телефон — смещение кнопки «+»:** в строке с кнопкой «+» рядом есть иконка-плюс, которая
  немного съехала с выравнивания (misalignment на ~несколько px). Нужен скриншот + точный экран
  (Today FAB? строка добавления в Plan?), чтобы починить выравнивание (вероятно Row без правильного
  alignment/Spacer или padding).
- [ ] **Plan (веб) — пустые серые плашки:** область дня/сетки рисуется серым прямоугольником вместо
  контента/лоадера (вероятно локальная БД Drift на вебе не отдаёт данные + необработанный loading).
  В работе.

### UX / логика — продумать (ТЗ)

- [ ] **ИИ: наружу торчит бесполезный nudge вместо умного переноса (ядро продукта!):** на вебе ИИ-
  подсказка выдала ободряющую фразу («не переживай, осталась 1 задача, сделаешь завтра») вместо
  предложения КАК перенести оставшиеся задачи с учётом приоритетов/типов/времени. Это две разные
  фичи: `/ai/morning-message` (nudge, сработал) vs `/ai/redistribute` (умный перенос — главная
  ценность). Рекоменд.: вынести умное перераспределение на первый план; когда переносить почти нечего
  (1 задача) — всё равно давать осмысленное предложение (куда/почему по типу-времени), не «не переживай».
  Проверить промпты backend/src/ai/ (redistribute реально учитывает priority/type/time?). ХОРОШО: сама
  цепочка ИИ (бэкенд→Gemini) РАБОТАЕТ — ответ пришёл. ВЫСОКИЙ приоритет — это hook продукта.
- [ ] **ИИ-инсайт дневника: обрезан + непонятен охват:** инсайт (`/ai/diary-insight`) выдал обрезанный
  текст («…отлич.» — оборвалось; в тесте 2026-06-27 выдал ВСЕГО «Замечательно, что» — оборвалось на
  2 словах) и непонятно, ЧТО он анализирует (похоже, 1 день). Фикс: (1) поднять лимит токенов ответа
  (maxTokens) / убрать обрезку при рендере — главное, текст рвётся на середине фразы; (2) анализировать
  тренды за период (настроение/сон/вода/выполнение за неделю-месяц), не одну запись; (3) подписать, на
  чём основан инсайт. NB: бэкенд на Render собран из main — проверить промпт и лимит токенов.
- [ ] **БАГ: главный недельный показатель воды = СУММА, а не среднее/день (НЕсогласованность).**
  За неделю записано 4750 мл (тест) — крупная цифра недельного вида показывает 4750, ХОТЯ в блоке
  «наблюдения» ниже верно написано «в среднем ты выпивал 679 мл в день». Т.е. среднее уже считается
  правильно — баг только в headline-числе. Фикс: главный недельный показатель = среднее/день (как в
  наблюдениях), подписать «в среднем/день». Файлы: `health/water_report_screen.dart` /
  `health_screen.dart` (weekWaterProvider). Сверить так же сон/выполнение — недельные сводки везде
  средние, а не суммы. Войдёт во флаттер-батч.
- [ ] **ИИ-итоги недели (Wrapped) просто пересказывают цифры.** `/ai/wrapped-summary` перечисляет то,
  что пользователь и так видит в «последние 7 дней» (задачи/вода/настроение), без вывода. Нужен
  ИНСАЙТ, а не дамп: что изменилось vs прошлая неделя, паттерн/корреляция (напр. «в дни без воды
  ниже выполнение»), 1 конкретная рекомендация на след. неделю, тёплый тон. Переписать промпт
  generateWrappedSummary (backend/src/ai/): дать тренды/сравнение, запретить простое перечисление
  входных чисел. Общая болезнь ИИ-текстов (см. nudge, diary-insight) — модель дублирует данные
  вместо смысла. Единый принцип: «ИИ говорит то, чего пользователь сам не видит».
- [x] **СДЕЛАНО (промпты; деплой на main pending): ИИ-тексты — выводы вместо пересказа.** diaryInsight /
  wrappedSummary / morningMessage переписаны (явный запрет пересказа входных чисел, требовать тренд/
  совет), maxTokens подняты: инсайт 200→450, wrapped 120→350 (+ убран лимит «60 слов» — он и резал
  текст на середине), morning 120→180. FOLLOW-UP: для реальных трендов роут `/ai/diary-insight` должен
  слать 7-14 дней дневника, а не 1 — доработать запрос логов на стороне роута/клиента.
- [x] **СДЕЛАНО (eb4db98): ИИ-фото еды — выбор распознанного совпадения.** Сфоткал черничный йогурт →
  показалось «AI: blueberry yogurt (90%) — pick a match», но тапнуть не по чему. Причина в
  `food_screen.dart`: цепочка отрисовки `else if (_controller.text.trim().isEmpty && _recentLoaded)
  → «Недавнее»` срабатывает РАНЬШЕ ветки `else → ListView(_results)`. После фото поле поиска пустое →
  показывается «Недавнее», а список совпадений `_results` не рисуется. Фикс: добавить в условие
  «Недавнее» `&& _results.isEmpty` (или `&& _aiNote == null`), чтобы при наличии результатов фото
  показывался тапабельный список совпадений. Тривиально, войдёт в флаттер-батч.
- [ ] **Хардкод англ. строк в экране еды:** «pick a match» (`food_screen.dart:1202`), «$kcal kcal /
  100g» (стр.1127). Перевести через `context.s()` + plMacro/format. Анти-регресс правило A.
- [ ] **Food-DB: язык результатов.** Пользователь ожидает поиск/выдачу ТОЛЬКО на своём языке, но в
  базе попадаются блюда на других языках, а названия часто английские (food-DB англо-первая, ADR).
  Это причина «почему по-английски» в распознавании и поиске. Задача (большая, проектная): локализовать
  food-DB (мультиязычные имена) ИЛИ фильтровать выдачу по языку пользователя (Accept-Language) +
  убрать смешение языков в результатах. Развязать с распознаванием (dish name на языке пользователя).
- [x] **СДЕЛАНО (food-1): тап по блюду в дневнике еды → детальный шит с ручной правкой КБЖУ/сахара/
  клетчатки.** Новый `food_log_detail_sheet.dart`: тап по строке `_FoodRow` (food_screen.dart, обёрнута
  в `Material+InkWell`) открывает шит — название, граммы порции, 6 редактируемых полей (калории/Б/Ж/У/
  сахар/клетчатка) с числовой клавиатурой, рядом живая подпись «на 100 г» (пересчёт на лету из текущего
  значения поля / grams). [Save] пишет правку ИМЕННО этой записи через новый
  `FoodLogsDao.updateLogMacros` (date/meal/name/grams не трогает, глобальную food-DB не меняет). Шит
  скроллится внутри `ConstrainedBox(maxHeight: 60% экрана)` — без этого `SingleChildScrollView` внутри
  `Column(mainAxisSize: min)` не скроллится и переполняется на 320px+textScale 1.5 (найдено и исправлено
  виджет-тестом). Новые l10n-ключи в `food.dart` (en+ru+9 др. языков): `food.macro_calories/sugar/fiber`,
  `food.unit_kcal/unit_g`, `food.per100_g_val`, `food.log_detail_scope_hint`, `food.log_updated`. Тесты:
  `test/food_log_detail_sheet_test.dart` (5 тестов: начальные значения, живой пересчёт per-100g, Save
  пишет в DAO без побочных правок name/grams/meal, открытие тапом из FoodScreen, overflow на 320px+1.5×).
- [ ] **Список покупок — авто-сборка из утверждённого меню.** Хочу: собрал меню на день/неделю →
  приложение предлагает список продуктов к покупке (агрегировать ингредиенты/продукты меню, свести
  дубли, прикинуть количества) → пользователь утверждает / редактирует / отклоняет. Сейчас список
  покупок ручной, не связан с меню. Связать ai-menu/меню дня→неделю с генерацией shopping-list.
- [ ] **UX: в списке покупок кнопка «убрать отмеченные» НЕЗАМЕТНА.** Отметил «протеиновый батончик»
  (купил) — висит зачёркнутым; кнопка очистки отмеченных есть, но пользователь её не нашёл. Сделать
  заметной: вынести в видную позицию (app-bar action с подписью / заметная кнопка над списком, когда
  есть отмеченные) + рассмотреть свайп-удаление пункта как альтернативу. Файл
  `food/shopping_list_screen.dart`. Войдёт во флаттер-батч.
- [ ] **Список покупок — «рекомендация» непонятна.** В экране есть блок рекомендации, но неясно, как
  он работает / на чём основан / что с ним делать. Прояснить: подписать источник (на основе чего
  предлагается), сделать действие очевидным (добавить в список / скрыть), или убрать, если бесполезен.
  Связать с авто-сборкой списка из меню (см. выше). Файл `food/shopping_list_screen.dart`.
- [ ] **Мои рецепты — расширить редактор: описание, пошаговые фото, видео/ссылка.** Сейчас в рецепте
  можно выбрать продукты и день, но нельзя: (1) написать текстовое описание/шаги приготовления;
  (2) приложить фото по шагам; (3) прикрепить видео или ссылку на видео (YouTube/Reels и т.п.).
  Добавить в `food/recipe_editor_screen.dart`: поле описания, список шагов (текст + опц. фото на шаг),
  поле видео-URL (с превью/кнопкой открыть) и/или загрузка видео. Хранение медиа — локально (путь),
  синк — позже. Учесть размер/кадрирование фото.
- [ ] **Дневник — История: год-календарь по настроению + просмотр записи дня.** (Повторный запрос
  пользователя.) Хочу зайти в «Историю» дневника и видеть КАЛЕНДАРЬ за всё время (год/heatmap),
  где каждый день ОКРАШЕН по настроению того дня; тап по дню → открыть запись (описание + «что пошло
  не так» + настроение), что я тогда писал. Данные есть: day_logs (mood/note) + mood_logs (Drift).
  Сделать экран истории: год-вид (цвет=mood, легенда), переход к дню, read-режим записи с кнопкой
  «изменить». Перекликается с правом редактировать прошлую запись. Файл: новый `diary/diary_history*`
  + day_logs DAO (запросы за период). НЕ во флаттер-батч багов — это новая фича (отдельно).
- [ ] **Дневник — состояние после сохранения дня неочевидно.** Сохранил день (описание + «что пошло
  не так») — непонятно: обнулилось или сохранилось? Пользователь не уверен, чего хочет. Рекоменд.:
  после сохранения форма показывает СЕГОДНЯШНЮЮ запись в режиме «уже записано сегодня: …» с кнопкой
  «изменить» (а не пустые поля). При повторном открытии дня — подтягивать существующую запись из
  day_logs (DAO) и давать редактировать/перезаписать, не плодя дубликаты. Файл `diary/diary_screen.dart`.
  Связать с ИИ-инсайтом дневника (что он анализирует).

- [ ] **Plan — несогласованный разворот календаря между режимами:** в режиме «День» мини-календарь
  (иконка-сетка) разворачивается неделя→месяц, а в других режимах (3 дня/неделя/месяц/год) так нельзя.
  Поведение разворота даты должно быть единым во всех режимах. Варианты:
  (A) сделать мини-календарь-пикер доступным одинаково во ВСЕХ режимах, отдельно от переключателя
  промежутка (переключатель = гранулярность ленты, календарь = выбор даты); рекоменд.
  (B) единый жест «развернуть на уровень выше» в каждом режиме (день→неделя→месяц);
  (C) убрать дублирующий мини-календарь совсем и оставить только переключатель промежутка (меньше
  кнопок — в духе фидбека «слишком много кнопок»). Решить вместе с редизайном переключателя выше.
- [ ] **Today — шапка забирает слишком много внимания:** приветствие + Kai + стрик занимают весь
  верх экрана, а задачи (главное) уезжают вниз. Пересмотреть иерархию: задачи должны быть в фокусе
  сразу, шапку — ужать/свернуть (компактная строка вместо крупных блоков, стрик мельче, Kai скромнее
  на этом экране или сворачивается при скролле). Цель: открыл «Сегодня» — сразу видишь, что делать.
  (перекликается с «task 10 hero», но на деле верх всё ещё перегружен)
- [ ] **Стрик не засчитывается в день без «главных» задач:** стрик растёт только за выполнение
  главных (main) задач. Если в дне нет ни одной главной, но всё выполнено — стрик не возобновляется.
  Фикс: либо стрик засчитывает день как «удержан», когда выполнены ВСЕ запланированные задачи (а при
  отсутствии главных — fallback на любые выполненные), либо не допускать день без хотя бы одной главной
  (утренний разбор предлагает выбрать главную). Рекоменд.: первый вариант (не наказывать за день без main).
- [ ] **Анимация завершения блокирует быстрое закрытие нескольких задач:** из-за анимации нельзя
  быстро подряд закрыть несколько задач. НЕ критично (нет потери данных/краша), но бьёт по основному
  сценарию. Фикс: анимация не должна блокировать ввод — разрешить ставить завершения в очередь /
  не ждать конца анимации перед следующим свайпом / укоротить лок. Средний приоритет.
- [ ] **БАГ (ВЫСОКИЙ): «Undo» после выполнения задачи в «Сегодня» не возвращает задачу.** Пользователь
  жмёт Undo в тосте — ничего не происходит. Ожидание: снять выполнение, задача снова в списке.
  Код: `task_list.dart::_doDone` показывает `showAppToast(variant: done, onUndo: → updateItem(status:
  pending))`. Тост `core/animations/app_toast.dart` — кастомный OverlayEntry; в комментарии (стр.212)
  упомянут `IgnorePointer`, но в коде его НЕТ (устаревший коммент). Гипотезы: (1) нажатие не доходит
  до TextButton (наложение bottom-nav / tap-target shrinkWrap / позиционирование `bottomOffset`);
  (2) для повторяющейся (virtual) задачи Undo целит в материализованную строку, а список рисует
  виртуальное вхождение → визуально «не вернулось». Фикс + виджет-тест: complete → tap Undo →
  задача снова pending и видна. Проверить и обычные, и повторяющиеся задачи.
- [ ] **Текст кнопки Undo в тосте захардкожен `'Undo'`** (`app_toast.dart:274`) — не переводится.
  Должно быть `context.s('common.undo')` (нарушение анти-регресс правила A — англ. хардкод). Починить заодно.
- [ ] **Звук выполнения задачи — поменять:** текущий звук при завершении задачи не нравится, подобрать
  другой (проверить `core/animations`/haptics + где проигрывается completion-звук).
- [ ] **Условия использования + конфиденциальность — продумать:** ревизия Terms & Privacy
  (экран есть, но требует продумывания содержания: что собираем, хранение локально/синк, ИИ-данные,
  возрастные ограничения, согласие). Сверить с реальными потоками данных.
- [ ] **«Оценить приложение» → магазин:** кнопка должна вести на страницу приложения в магазине
  (Google Play / App Store / RuStore), куда зальём. Площадки пока нет → сделать заглушку: либо
  конфиг-URL (легко поменять при релизе), либо диалог «скоро в магазинах». Сейчас кнопка-стаб.
- [ ] **Профиль — менять имя и аватар.** Дать пользователю: (1) редактировать отображаемое имя
  профиля; (2) аватар — либо своя картинка из галереи (image_picker), либо выбор из нескольких
  безобидных пресетов. Имя сейчас берётся из аккаунта/онбординга и не редактируется в профиле.
  Хранить локально (Drift/prefs) + синк имени на бэкенд (поле user). Аватар-картинку — локально
  (путь/байты), пресеты — ассеты. Учесть пустое состояние и кадрирование своей картинки.
- [ ] **Внутренняя поддержка:** сделать канал связи с поддержкой прямо в приложении — либо почта
  (mailto/форма обратной связи), либо чат внутри. Сейчас в профиле есть «Send feedback» — расширить
  до полноценной поддержки.
- [ ] **Премиум для девелоперов (dev-разблокировка) + связка ИИ:** дать возможность включить премиум
  для теста; ИИ работает через бэкенд (Render/Frankfurt → обходит гео-блокировку Gemini в РФ). Условия
  работы ИИ: app→Render URL (не localhost), GEMINI_API_KEY на Render, премиум вкл. См. задачу #8.

### ИИ-тренировки — доработки опросника + поведение (фидбек 2026-06-27)

Контекст: ИИ-программа тренировок собирается, но опросник беден и часть пользовательских
настроек игнорируется. Нужны и UI (поля опросника), и промпт (`backend/src/ai/workout*.ts`),
и, возможно, расширение `workoutBuildSchema` + api-spec. НЕ хотфикс — отдельная задача.
- [ ] **Выбор схемы программы:** спрашивать тип — **сплит / фулбоди / тяни-толкай (push-pull-legs)**.
  Сейчас модель сама решает. Передавать выбор в промпт как жёсткое ограничение структуры дней.
- [ ] **Техники интенсивности:** спрашивать про **дропсеты** (и при желании суперсеты/др.) — включать
  ли. Если да — модель помечает соответствующие подходы.
- [ ] **Любимые / обязательные упражнения:** поле «упражнения, которые точно хочу включить» —
  модель обязана их вставить (с учётом инвентаря/цели). Аналог dislikes, но «must-include».
- [ ] **Недельный объём по мышцам:** спрашивать **сколько подходов на мышечную группу в неделю**
  хочет пользователь — модель распределяет объём под это число.
- [ ] **БАГ/поведение: модель игнорирует мой отдых из настроек.** В программе проставляется СВОЙ
  rest_seconds, а не тот, что пользователь задал в настройках тренировок. Передавать пользовательский
  rest в промпт и заставлять модель его использовать (или хотя бы как дефолт/ограничение).
- [ ] **БАГ: Undo-снэкбар после удаления упражнения висит бесконечно.** Удалил «гиперэкстензию» —
  уведомление с «Отмена» не исчезает само. Ожидание: авто-скрытие через 4с. Удаление упражнения
  идёт через `workout_editor_screen.dart::_deleteExercise` → `showUndoSnackBar` (core/widgets/
  undo_snack_bar.dart, duration: 4s). Снэкбаров с большой длительностью/`MaterialBanner` в коде нет,
  значит причина: либо перестройка списка (Drift-стрим) переоткрывает снэкбар, либо особенность
  устройства. Проверить виджет-тестом: pump редактора → удалить упражнение → проматать 5с →
  assert снэкбар скрыт. Если в тесте скрывается — копать рендер на устройстве (свайп + rebuild).
- [ ] **Подсказка по технике (`note` упражнения) — бесполезна.** Сейчас в note пишется вроде
  «6-10, отличное упражнение для спины» (повтор диапазона + общая похвала). Должно быть КАК ВЫПОЛНЯТЬ
  это конкретное упражнение — форм-кью (для подтягиваний: хват/ширина, полный вис, сведение лопаток,
  контролируемое опускание, без раскачки). Переписать инструкцию в промпте workout-build: note =
  2-3 коротких технических указания именно под name упражнения, без повторения sets/reps.
- [ ] **Показывать общую длительность тренировки (с отдыхом).** После создания программы (своей или
  ИИ) выводить суммарное время = время на подходы + отдых между ними. Считать из sets×reps (оценка
  темпа) + rest_seconds×(кол-во пауз) по всем упражнениям дня. Показать в карточке дня программы
  (и в превью ИИ-сборки, и в редакторе своей).
- [x] **Надёжность ИИ (мигает «AI service unavailable»):** и меню, и тренировка иногда падали,
  иногда собирались — временные сбои Gemini (rate-limit/битый JSON) пробрасывались без ретрая;
  меню падало всегда из-за строгого сравнения имён продуктов. Фикс: терпимое сравнение имён +
  ретрай при временных сбоях + понятная ошибка (в работе 2026-06-27, деплой на main→Render).
- [ ] **Health — пересобрать структуру модулей (группировка):** сейчас Вода+Сон включены всегда,
  остальное за флагами — обоснование слабое/произвольное (противоречит онбордингу, который включает
  модули по целям). Предложение пользователя + рекоменд. группировка, меньше модулей:
  • **Питание** = Еда + **Вода** (вода — это intake, к еде)
  • **Осознанность** = Медитация + **Дыхание** (объединить)
  • **Движение** = Тренировки + Разминка + Осанка
  • **Сон** — отдельно
  И убрать «по умолчанию включённые вода+сон» — состав модулей определяется ТОЛЬКО целями онбординга
  + тумблерами (единое правило, без магических дефолтов). Обновить feature_modes_provider + Health-сводку.
- [ ] **Щит на главной задаче — нужен ли:** индикатор «protected» (перепланирование не двигает
  задачу) всё ещё на main-задачах. Пользователь сомневается в необходимости. Решить: оставить / убрать
  / сделать понятнее (тултип уже есть). NB: возможно увидено на СТАРОМ вебе (main) — проверить на night.
- [ ] **Маркер версии/сборки для тестов:** пользователь не понимает, новую ли версию видит (веб собран
  из main=старое, эпик на ветке night). Добавить видимый идентификатор сборки (ветка + короткий commit
  + дата) в Профиль рядом с версией — чтобы при тесте было однозначно, какая версия запущена. И/или
  одноразово задеплоить night на веб (Actions → Deploy web → ветка night), чтобы веб стал актуальным.
- [ ] **Kai + тон — слишком много кнопок, пересобрать логику:** сейчас три пересекающиеся настройки —
  тон (мягкий/строгий), личность Kai (спокойный/обычный/жёсткий/своё), частота подсказок Kai
  (выкл/слегка/полная). Пользователю непонятно и избыточно. Продумать и свести к одной-двум понятным
  настройкам. (связано с MASCOT.md / тон gentle-harsh)
- [ ] **Адаптивная устойчивость на ВСЕХ размерах (общее требование):** вёрстка должна быть
  ПРЕДСКАЗУЕМОЙ при любом размере окна и ориентации — поворот экрана, веб в НЕполноэкранном окне
  (resizable), планшеты, разные телефоны. Никаких элементов, которые «непонятно как выглядят».
  Провести реальный ре-аудит на 320px / поворот / узкое окно браузера / планшет по КАЖДОМУ экрану
  (не доверять старой отметке «адаптив готов» — переключатель Плана её опровергает). Усилить
  anti-regression gate B (overflow) до полноценной проверки ресайза окна.

## Ревью 2026-06-11 (утро) — фидбек пользователя после ночной сессии

### Отложенный бэклог (делаем сейчас)

- [x] Онбординг: норма воды по весу/росту (+активность) с возможностью править вручную (2026-06-11)
- [x] Онбординг: кнопка «Назад» на каждом шаге (2026-06-11)
- [x] Тайминги: UI-переходы ≤300мс, slow 400→300, вода 500→300, шит 320→300, ANIMATIONS.md/токены обновлены (b882992)

### Баги

- [x] add_task_sheet: артефакты при клавиатуре — сплошной фон+clip на всех темах (06e79ad)
- [x] Duration: ручной ввод минут + выбор времени окончания (06e79ad)
- [x] Щит: tooltip + подпись «Protected: replanning never moves it» (06e79ad)
- [x] Клон недели: копировал только type=event — теперь всё запланированное (b882992)
- [x] Сканер: mobile_scanner 6+ требовал ручной start() — починено; фонарик следит за состоянием; CAMERA в манифесте (b882992)
- [x] Голос: привязан к системной локали (b882992)
- [x] Голос: привязан к языку приложения (localeNotifierProvider → ru-RU/de-DE/en-US) (2026-06-16, 89a4593)
- [x] Отчёт сна: полный экран SleepReportScreen (история ночей, статистика, выбор даты) (2026-06-16, 7b6ee9f)
- [x] Water: полный отчёт WaterReportScreen (история по дням, прогресс к норме, выбор даты) (2026-06-16, 7b6ee9f)
- [x] Дневник: история записей DiaryHistoryScreen (настроение/заметка/issues за любой день, кнопка View History) (2026-06-16, 7b6ee9f)
- [x] Food search «connection refused» — причина: запуск без LAN IP; fix: run-phone.ps1 с device ID (2026-06-16)
- [x] Восстановление пароля — бэкенд (in-memory tokens, dev_code) + Flutter 2-step screen + «Forgot password?» на auth (2026-06-16, b445c81)

### Новые функции (бэклог, по приоритету после багов)

- [x] Просмотр истории за прошлые даты: Дневник (настроения/оценки) и Календарь/план (задачи/события) — аналогично Water/Sleep отчётам с выбором даты (2026-06-16: diary 7b6ee9f, plan 342ca3c)
- [x] Co-study (Ф3, 2026-06-16): друзья по email · статус «в сессии/X мин» · сессия по коду · общий таймер · лидерборд недели · уведомление «X учится»; jest 99/99; миграция costudy применена в Neon
- [x] Полноэкранный Water /water (2026-06-16): большой анимированный стакан, кнопки +150/200/250/350 мл, напоминания каждые 2 ч
- [x] Медитации: 5 текстовых guided-сессий + countdown (2026-06-16, 3e1b45e): Body Scan/Focus Reset/Exam Calm/Sleep Prep/Stress Relief; аудио/видео — без CDN
- [x] Дыхание: авто-переключение фаз с текстом + цвет по фазе + счётчик секунд (2026-06-16)
- [x] Заморозка стрика: копирайт «Give yourself a day off 😌» + tooltip в Profile (2026-06-16, f8e50f0)
- [x] Трекер привычек: Drift v10 + HabitsScreen (хорошие/прогресс + плохие/счётчик) + карточка в Health (2026-06-16, 8b8e2e9)
- [x] Реферальная программа: карточка «Invite a friend» в Profile (2026-06-16, e8d3043)
- [x] Лимит 3 main-задачи: hint «3 main tasks max» в add_task_sheet (2026-06-16, b445c81)
- [x] Кнопка «Сообщить об ошибке / отзыв»: Rate the app + Send feedback в Profile (2026-06-16, f8e50f0)
- [x] Задачи из шаблонов/готовых примеров: 10 студенческих пресетов (2026-06-16, b445c81)
- [x] Глобальный undo: undo завершения задачи + поиск в Plan (2026-06-16, 0627153)
- [x] Хештеги + поиск по задачам: SearchBar в Plan с фильтром по title (2026-06-16, 0627153)
- [x] Фото/видео к задачам — локально (2026-06-16): Drift v11 ItemAttachmentsTable + image_picker + video_player, миниатюры в add_task_sheet
- [x] Адаптивная вёрстка (все размеры/ориентации): ScaffoldWithNavBar NavigationRail + HealthScreen 2-col (cfc5029); Plan + Diary 2-col (dc5a059); TodayScreen 2-col (e621fba) — все 4 главных таба (2026-06-16)
- [x] Аналитика образа жизни: _LifeInsightsCard в Diary (сон/вода rule-based) (2026-06-16, e8d3043)
- [x] Пользовательское соглашение + дисклеймер: Terms&Privacy screen (2026-06-16, b445c81)
- [x] Выбор даты тапом через календарь (2026-06-16): DatePicker в Water/Sleep/Diary-history
- [x] Просмотр задач/записей за прошлые даты (2026-06-16, 342ca3c)
- [x] Лимит времени в сторонних приложениях (2026-06-16, b4cc9d3): ScreenTimeScreen — лимиты по категориям (SharedPreferences), слайдер в боттом-шите; реальный UsageStats — позже (нужны платформ-разрешения)
- [x] **Импорт из популярных планнеров (2026-06-17):** ICS-файл (Google Calendar / Apple Calendar / Outlook) + Todoist CSV → события/задачи в Plan; кнопка в ImportSheet (feat: ICS + Todoist CSV import in ImportSheet)
- [x] **Локализация: Health hub + Co-study + Habits (2026-06-18):** все пользовательские строки в `health_screen.dart`, `costudy_screen.dart`, `habits_screen.dart` переведены через `context.s()` (54 ключа в `strings/health_a.dart`, en+ru+de). Пропущено 3 строки с русскими множественными числами (Night logged/«X is studying»/«studying for N min»).
- [ ] **[Ф4]** Умные часы: Wear OS tile + watchOS complication — кольцо задач, стрик, старт/стоп фокус-сессии, вибро-напоминание воды (SPEC C9). Требует: Apple Developer Account + физические часы.
- Отложено пользователем: Health Connect (устройств нет). OAuth Google/Apple — **убран по закону РФ 406-ФЗ** (ADR-031), заменён входом по телефону + РФ-почте

## Бэклог доработок дизайна / UX (нужна живая проверка на устройстве)

- [ ] **Маскот «Kai» (ADR-032, `docs/MASCOT.md`):** фирменная ИИ-сущность — мягкий морфящийся squircle, два глаза-тире без рта, глаза = акцент темы, поведение по тону gentle/harsh, отключаемый в Профиле. Реализация на Rive. Порядок: Rive-ассет (дизайнер) → Today-шапка + тумблер → виджет/celebration/фокус → Health/Water. Концепт утверждён пользователем (база squircle + ситуативная деформация).
- [ ] **Раскладка/UX «по науке» (ADR-033, `docs/UX-LAYOUT.md`):** навигация подтверждена (4 таба + аватар + FAB). Шлифовка (поверх готовых экранов, не переписывание): (1) FAB — зазор от таб-бара + collapse-on-scroll + проверка 360px; (2) Plan — закрепить ember-карточку экзамена вверху ленты; (3) Food — убрать «стену лайма» (акцент только на главную метрику + отметки); (4) свайпы — видимый аффорданс-хинт при первом использовании; (5) ~~создание задачи — умные дефолты~~ **[готово 2026-06-19]** `_defaultScheduledAt()` в `add_task_sheet.dart`: новая задача = date сегодня, время = ближайший 30-мин слот (+1мин буфер, не прошедшее); после 23:30 → завтра 09:00; будущий день → 09:00; приоритет = medium; NL-парсер перекрывает дефолт, ручной выбор блокирует NL.
- [~] **Виджет — редизайн (дизайн зафиксирован: `docs/WIDGET.md`, ADR-042, 2026-06-19):** task-focused (ближайшие пары/дела), стрик нейтрально, Kai выглядывает с эмоцией по частоте захода, адаптивный на все размеры + выбор, читает активную тему, само-обновление по таймеру, Kai = PNG-рендер из CustomPainter. Платформы: Android (сборка), iOS WidgetKit (код; проверка — нужен Mac). Сборка по фазам §10 WIDGET.md.
- [ ] **Онбординг — доработка UX:** потенциальные улучшения после живой проверки: анимации между слайдами, иллюстрации/скриншоты продукта на слайдах ценности, прогресс-бар шагов настройки, A/B текста копирайта.
- [ ] **Дизайн и темы — доработка:** Calm-тема требует проверки всех экранов (создавалась как stub); тайминги и лаги анимаций на реальном устройстве (конфетти, переходы); иконки приложения под каждую тему (premium фича по ТЗ); пройтись по всем экранам на маленьком экране (360px) и планшете.

## Ревью MVP (2026-06-10) — фидбек пользователя

Починено сразу:

- [x] add_task_sheet: «BOTTOM OVERFLOWED BY 112 PIXELS» с клавиатурой → SingleChildScrollView
- [x] Размер текста: «Larger» → «Extra large»
- [x] Поиск еды не находил ничего: легаси OFF cgi/search.pl стабильно 503 → переехали на search.openfoodfacts.org (search-a-licious; hits[], brands массивом)
- [x] Версия приложения в профиле (package_info_plus, «Version 1.0.0 (2) · debug»); build bumped до +2
- [x] run-phone.ps1: UTF-8 BOM (PS 5.1 ломал кириллицу без BOM)

Бэклог по указанию пользователя (НЕ делать до закрытия остального ТЗ):

- [x] Онбординг-настройка «поработать в начале»: норма воды из параметров пользователя (не вручную), стрелка «назад» между шагами (2026-06-11)
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

## Backend

- [x] SETUP-01 Project scaffolding (Fastify + TS)
- [x] SETUP-02 Prisma schema + migration
- [x] SETUP-03 Fastify server + health check
- [x] AUTH-01..04 Register / Login / JWT middleware / Me
- [x] ITEMS-01..04 CRUD + ownership
- [x] STREAK-01..02 Get streak + update helper
- [x] SYNC-01 Sync endpoint (last-write-wins); recomputes streak when a main item transitions to done (regression fix — previously only PATCH /items did); + water_logs sync + deleted_item_ids (server deletes owned items) + day_logs sync (upsert by user+date, LWW; DayLog.updatedAt migration on Neon); also syncs water logs (append-only, ADR-017)
- [x] ENGINE-01 Rule redistribution (POST /api/v1/redistribute)

## Flutter

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

## QA

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
- [x] RU/EN language switcher (2026-07-02): full bilingual coverage — 84 unique `data-i18n`
  keys (91 tagged nodes incl. 4 reused keys) + 5 `data-i18n-aria` keys (7 nodes) span every
  visible string (header, hero incl. phone mockup, problem/solution, features, both pricing
  cards, footer). EN dictionary is captured live from the DOM at load (innerHTML, preserves
  nested `<em>`/`<br>`/`<span>`); RU dictionary is hand-translated (product referred to as
  «Главное» in RU copy per /CLAUDE.md naming note; price stays "399 ₽ / 31 день, разовый
  платёж, без автопродления"). `setLang(lang)` swaps content, `<html lang>`, persists to
  `localStorage('landing_lang')`, highlights the active RU/EN pill, repoints footer
  Privacy/Terms links to `privacy.html#<lang>`/`terms.html#<lang>`, and syncs the Alpine
  `i18n` store (registered via `alpine:init`) so reactive `x-text` bindings (smart download
  button, Free/Premium CTAs) follow along. Auto-detect: `localStorage` → `navigator.language`
  → `en`. Also fixed a pre-existing bug where the Premium CTA's `x-text="'Go Premium'"` never
  reacted to language. Verified via a headless jsdom run (zero runtime errors, full EN↔RU
  round-trip) since no browser is available in this environment. Header also got a
  `sm:hidden`/`hidden sm:inline-flex` pair of download buttons (short "Get App"/"Скачать"
  label under 640px, full platform-specific label above) so the RU/EN pills + download CTA
  keep fitting a 360px header without overflow.

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
