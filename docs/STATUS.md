﻿# Kaizen («Главное») — Статус проекта

> Единственный файл «где мы сейчас / что осталось». Оркестратор обновляет его после каждого блока.
> *Что обещали* (продукт) — в `docs/SPEC.md`. Архитектурные решения — в `docs/decisions.md`.
> Статусы задач в журнале ниже: `[ ]` todo · `[~]` в работе · `[x]` сделано · `[!]` заблокировано.

## Сводка для пользователя (обновлено 2026-06-19)

### ✅ Готово (работает, под тестами)
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
- **iOS-сборка и iOS-виджет** — нужен Mac.
- **Реальные платежи — пейвол ни к чему НЕ подключён (важно, ADR-039).** Экран `/paywall` и кнопка «Start free» сейчас зовут `StubPurchaseService` — это заглушка: в debug она просто включает premium (`dev-upgrade`), в release возвращает «недоступно». **Настоящего списания нет ни на одной платформе.** Реальный путь: iOS → App Store IAP, Android → Google Play Billing (оба через **RevenueCat**, замена одной строки в `purchase_service.dart`); **веб → отдельный процессор (Stripe / RevenueCat Web Billing) — для веба RevenueCat сторовый биллинг не работает**. Нужны: аккаунты Apple/Google, проект RevenueCat + ключи, (для веба) Stripe-аккаунт. Это твоя зона — код-абстракция готова, подключение = ключи.
- **Умные часы [Ф4]** — Wear OS / watchOS; нужны часы + Apple Developer Account.
- **Реклама на free-тарифе** — нужны рекламные аккаунты (осознанно отложено).
- **Живые проверки на телефоне** — голос, сканер, уведомления, диагностика «connection refused»/премиум через `scripts/run-phone.ps1`.
- **Онбординг quiz-flow (2026-06-19)** — `setup_flow.dart` переписан: 16 экранов (Hello→Problem→Solution→Language→Goals→PlanTime→Horizon→Projection→Age→HeightWeight→Activity→FirstTask→RescheduleDemo→Timing→Summary→Paywall). Честные данные, Kai на каждом экране, первая задача вставляется в Drift, демо переноса — интерактивный sandbox, locale устанавливается live, все провайдеры reused, `flutter analyze` 0. Новые prefs keys: `onboarding_goals` (StringList), `onboarding_plan_minutes` (int), `onboarding_horizon` (String). Строки: `core/l10n/strings/onboarding_quiz.dart` (83 ключа en/ru/de).
- **Дизайн-полиш (нужна проверка на устройстве)** — виджет Android (больше данных, оформление под темы, размеры), Calm-тема по всем экранам, тайминги конфетти/переходов вживую, прогон на 360px и планшете.

### 🐞 Баги / техдолг (мелочь, не блокирует)
- ~~Лимит AI-фото (3/день) хранился в памяти процесса~~ → **закрыто 2026-06-18:** таблица `AiUsage` (устойчиво к рестарту/мультиинстансу), ADR-034, jest 111/111.
- ~~RenderFlex overflow в тулбаре Plan на ~390px~~ → **закрыто 2026-06-18:** `SegmentedButton` обёрнут в `Flexible` + `SingleChildScrollView(Axis.horizontal)`; overflow на 360px устранён, поведение не изменилось.
- ~~«Shared with me» краш с красным экраном~~ → **закрыто 2026-06-18:** `TextEditingController` перенесён в поле `_SharedWithMeCardState` (initState/dispose), больше не утилизируется синхронно после `await showDialog` — каскад ошибок (duplicate GlobalKey / multiple heroes / wrong build scope) устранён.
- Шрифт Geist — временная замена, ждём пакет (`app/.../app_theme.dart`).
- Ссылки сторов / Privacy / Terms на лендинге — плейсхолдеры (`landing/index.html`).
- `widget_test.dart` — пустышка (реальные тесты в `screens_smoke_test.dart`).
- **Перевод RU — остаток (2026-06-19):** основные пропуски устранены sweep-ом (51 ключ, см. блок выше). Обоснованно пропущено: `ToneCopy.*` строки в `tone_provider.dart` (нет BuildContext, строки tone-aware — риск рефактора), `screen_time_provider.dart` (данные провайдера без context), числовые plural-формы («$n min», «$missed workout(s)», счётчик упражнений) — без plural-библиотеки опасно для RU падежей, `'$type'` лейбл в shared-plan viewer, debug-строки `'Error: $err'`.

### 🙋 Нужна твоя помощь (без тебя не двинется)
1. **Телефон + `run-phone.ps1`** — проверить голос, сканер, уведомления, премиум.
2. **Аккаунты** — Google Play / App Store (OAuth, RevenueCat, публикация), Firebase (пуши), рекламная сеть (free).
3. **Правки ТЗ** — если хочешь что-то поменять: пиши списком, внесу в `SPEC.md` через ADR и пересоберу бэклог.
4. **Контент** — видео техник упражнений, аудио медитаций; подключу, когда появится.

### Тесты
На 2026-06-19 зелёные (`flutter analyze` — 0). Backend: 120/120 jest (11 сьютов, --runInBand). +10 новых тестов в `entitlement.test.ts` (ADR-041): вебхуки billing × 5 каналов, expired premiumUntil, dev-upgrade, AI-гейт с активным premiumUntil, free-блок, /status без auth, /auth/me содержит is_premium.

---

## Журнал работ (хронология сделанного по блокам)

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
