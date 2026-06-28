// Онбординг (quiz-style flow) — персонализация после первого запуска.
// Заменяет прежний 7-шаговый SetupFlowScreen.
//
// Архитектура: единый PageView из 14 «страниц» (индексы 0–13).
// Каждая страница — изолированный _build*() метод.
// Состояние хранится в полях виджета-state; сохранение — в _finish().
//
// Флаг 'setup_done' сохраняется в конце; роутер делает redirect. При входе по
// реальному аккаунту флаг также пушится на сервер (onboarding_done) и читается
// обратно при login/register — см. AuthController.
// Прогресс-индикатор скрыт на демо-экране (индекс 8).
//
// Прим. по экранам (0-based индексы PageView):
//   0  цели · 1 время на планирование · 2 горизонт · 3 проекция (derived)
//   4  возраст+пол · 5 рост+вес · 6 активность
//   7  первая задача (вставляется в Drift) · 8 демо переноса (no progress bar)
//   9  время разборов + расписание сна · 10 уведомления · 11 тон · 12 тема
//   13 саммари (последний; CTA → _finish() → /paywall, отдельного экрана нет)

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/constants.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/settings/feature_modes_provider.dart'; // флаги модулей
import '../../core/settings/health_profile_provider.dart'; // кonstants сна (ITEM B)
import '../../core/settings/nutrition_targets.dart';
import '../../core/settings/tone_provider.dart'; // тон gentle/harsh
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/id.dart';
import '../../core/widgets/voice_text_field.dart';
import '../../services/api/api_client.dart'; // apiClientProvider (sync setup flag)
import '../../services/notifications/notification_service.dart';
import '../auth/auth_controller.dart'; // authControllerProvider (isAuthenticated)
import '../mascot/kai_mascot.dart';
import '../mascot/kai_speech_bubble.dart';
import 'goal_flags_mapper.dart'; // маппинг целей → флаги модулей

// ---------------------------------------------------------------------------
// Константы, прокинутые наружу для роутера
// ---------------------------------------------------------------------------

/// Ключ SharedPreferences — флаг завершения setup.
const setupDoneKey = 'setup_done';

/// Ключи времени разборов (reused в notifications).
const reviewMorningHourKey = 'review_morning_hour';
const reviewEveningHourKey = 'review_evening_hour';

/// Ключ интересов (старый список — сохраняется для совместимости).
const interestsKey = 'interests';

// Новые ключи, вводимые этим файлом.
const _kGoalsKey = 'onboarding_goals';
const _kPlanMinutesKey = 'onboarding_plan_minutes';
const _kHorizonKey = 'onboarding_horizon';

// ---------------------------------------------------------------------------
// Вспомогательные типы
// ---------------------------------------------------------------------------

/// Вариант времени разборов (экран 14).
enum _TimingOption { morning, afternoon, evening, both }

// Числовые минуты за вариант планирования (экран 6).
const _planMinutesMap = {
  'none': 0,
  '10': 10,
  '30': 30,
  'more': 45,
};

// Превью-свотчи тем: (bg, accent). Зеркалят design-tokens.json v4.
// Kaname v4: 4 темы; акцент по умолчанию = indigo.
const _kThemeSwatch = <AppThemeKey, (Color, Color)>{
  AppThemeKey.day: (Color(0xFFF6F5F2), Color(0xFF4B57C9)),   // day bg + indigo light
  AppThemeKey.night: (Color(0xFF16140F), Color(0xFF7E89E0)), // night bg + indigo dark
  AppThemeKey.black: (Color(0xFF000000), Color(0xFF7E89E0)), // black bg + indigo dark
  AppThemeKey.calm: (Color(0xFFEEF3F2), Color(0xFF4B57C9)),  // calm bg + indigo light
};

// ---------------------------------------------------------------------------
// Корневой виджет
// ---------------------------------------------------------------------------

class SetupFlowScreen extends ConsumerStatefulWidget {
  const SetupFlowScreen({super.key});

  @override
  ConsumerState<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends ConsumerState<SetupFlowScreen> {
  final _pageController = PageController();
  int _page = 0;

  // Общее число экранов.
  // 14 экранов: ценность и выбор языка перенесены в /onboarding (первый запуск),
  // здесь — персонализация (цели → тело → первая задача → демо → время разборов →
  // уведомления → тон → тема → саммари). Саммари — последний экран; его CTA ведёт
  // прямо на /paywall через _finish() (отдельного экрана-хендоффа больше нет).
  static const _pageCount = 14;

  // --- Экран 5: цели ---
  final Set<String> _selectedGoals = {};

  // --- Экран 6: время на планирование ---
  String _planOption = 'none'; // 'none'|'10'|'30'|'more'

  // --- Экран 7: горизонт ---
  String _horizon = 'day'; // 'day'|'week'|'months'|'years'

  // --- Экраны 9–11: антропометрия ---
  final _ageController = TextEditingController();
  String _sex = 'other'; // 'male'|'female'|'other'
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _activity = 'medium'; // 'low'|'medium'|'high'
  int _waterGoal = kDefaultWaterGoalMl;

  // --- Экран 12: первая задача ---
  final _firstTaskController = TextEditingController();
  bool _taskError = false;
  bool _taskAdded = false; // true после успешной вставки
  String _addedTaskTitle = '';

  // --- Экран 13: демо переноса ---
  bool _taskMoved = false;

  // --- Экран 14: время разборов ---
  _TimingOption _timing = _TimingOption.both;
  int _morningHour = kMorningHour; // 8
  int _eveningHour = kEveningHour; // 20

  // --- Экран 14 (доп.): расписание сна (ITEM B) ---
  // TODO(sleep-distribution): значения будут читаться планировщиком
  // для создания «ночного окна» без задач/напоминаний.
  int _bedtimeHour = kDefaultBedtimeHour; // 23:00
  int _wakeHour = kDefaultWakeHour;       // 07:00

  // --- Экран 15: саммари (KaiLoader stub) ---
  bool _summaryReady = false;

  // ---------------------------------------------------------------------------
  // Жизненный цикл
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _waterGoal = ref.read(waterGoalProvider);
    _weightController.addListener(_recalcWater);
    _heightController.addListener(_recalcWater);
    _ageController.addListener(_recalcWater);
  }

  @override
  void dispose() {
    _weightController.removeListener(_recalcWater);
    _heightController.removeListener(_recalcWater);
    _ageController.removeListener(_recalcWater);
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _firstTaskController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Пересчёт нормы воды
  // ---------------------------------------------------------------------------

  void _recalcWater() {
    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight <= 0) return;
    final height = double.tryParse(_heightController.text.trim());
    final age = int.tryParse(_ageController.text.trim());
    final recommended = recommendedWaterMl(
      weightKg: weight,
      activity: _activity,
      heightCm: height,
      age: age,
    );
    setState(() => _waterGoal = recommended);
  }

  // ---------------------------------------------------------------------------
  // Навигация между страницами
  // ---------------------------------------------------------------------------

  void _next() {
    if (_page < _pageCount - 1) {
      _pageController.nextPage(
        duration: effectiveDuration(context, kDurationFast),
        curve: kCurveSnap,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: effectiveDuration(context, kDurationFast),
        curve: kCurveSnap,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Финализация
  // ---------------------------------------------------------------------------

  Future<void> _finish() async {
    final prefs = ref.read(sharedPreferencesProvider);

    // Язык — уже установлен live на экране 4.

    // Цели
    await prefs.setStringList(_kGoalsKey, _selectedGoals.toList());

    // Флаги модулей по целям: включаем только то, что пользователь выбрал.
    // goalsToFeatureFlags — чистая функция из goal_flags_mapper.dart.
    final flags = goalsToFeatureFlags(_selectedGoals);
    await ref.read(nutritionModeProvider.notifier).set(flags.nutrition);
    await ref.read(workoutModeProvider.notifier).set(flags.workout);
    await ref
        .read(meditationLibraryModeProvider.notifier)
        .set(flags.meditationLibrary);
    await ref
        .read(breathingEditorModeProvider.notifier)
        .set(flags.breathingEditor);

    // Время на планирование
    final planMinutes = _planMinutesMap[_planOption] ?? 0;
    await prefs.setInt(_kPlanMinutesKey, planMinutes);

    // Горизонт
    await prefs.setString(_kHorizonKey, _horizon);

    // Антропометрия
    final weight = double.tryParse(_weightController.text.trim());
    final height = int.tryParse(_heightController.text.trim());
    final age = int.tryParse(_ageController.text.trim());
    if (weight != null && weight > 0) {
      await prefs.setDouble(kUserWeightKgKey, weight);
    }
    if (height != null && height > 0) {
      await prefs.setInt(kUserHeightCmKey, height);
    }
    if (age != null && age > 0) {
      await prefs.setInt(kUserAgeKey, age);
    }
    await prefs.setString(kUserActivityKey, _activity);
    await prefs.setString(kUserSexKey, _sex);

    // Норма воды
    await ref.read(waterGoalProvider.notifier).set(_waterGoal);

    // Профиль здоровья — не собираем в этом флоу; провайдер остаётся.

    // Время разборов
    await prefs.setInt(reviewMorningHourKey, _morningHour);
    await prefs.setInt(reviewEveningHourKey, _eveningHour);

    // Расписание сна (ITEM B)
    await prefs.setInt(kSleepBedtimeHourKey, _bedtimeHour);
    await prefs.setInt(kSleepWakeHourKey, _wakeHour);

    // Перепланируем уведомления если включены
    if (ref.read(notificationsEnabledProvider)) {
      try {
        await ref.read(notificationServiceProvider).scheduleDailyReviews(
              morningHour: _morningHour,
              eveningHour: _eveningHour,
            );
      } catch (_) {
        // Уведомления не должны блокировать завершение.
      }
    }

    await prefs.setBool(setupDoneKey, true);

    // Синхронизируем флаг онбординга с аккаунтом, чтобы на web/новом устройстве
    // онбординг не показывался снова. Только для реального аккаунта; гость/оффлайн
    // ведут себя как раньше. Не блокируем и гасим ошибки — это второстепенно.
    if (ref.read(authControllerProvider.notifier).isAuthenticated) {
      try {
        await ref.read(apiClientProvider).updateProfile(onboardingDone: true);
      } catch (_) {}
    }

    if (mounted) {
      // Показываем пейволл один раз; после него роутер пустит на /today.
      context.go('/paywall');
    }
  }

  // ---------------------------------------------------------------------------
  // Вставка первой задачи в Drift
  // ---------------------------------------------------------------------------

  Future<bool> _insertFirstTask(String title) async {
    if (title.trim().isEmpty) return false;
    final now = DateTime.now();
    // Локальная полночь: scheduledAt трактуется как «настенное» местное время,
    // согласовано с watchTodayItems/day_window.
    final dayStart = DateTime(now.year, now.month, now.day);
    final companion = ItemsTableCompanion(
      id: Value(uuidV4()),
      userId: const Value('local'),
      title: Value(title.trim()),
      type: const Value('task'),
      priority: const Value('main'),
      status: const Value('pending'),
      scheduledAt: Value(dayStart),
      durationMinutes: const Value(30),
      isProtected: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await ref.read(itemsDaoProvider).insertItem(companion);
    return true;
  }

  // ---------------------------------------------------------------------------
  // UI-helpers
  // ---------------------------------------------------------------------------

  /// Показывать ли прогресс-индикатор (скрываем на демо-экране 8).
  bool get _showProgress => _page != 8;

  /// Карточка-выбор (single select) с accent-границей у выбранной.
  Widget _choiceTile({
    required bool selected,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    double topPad = 5,
    Widget? leading,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: topPad),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: kDurationSnap,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? colorScheme.primary : ext.border,
                width: selected ? 1.5 : 1.0,
              ),
              color: selected
                  ? colorScheme.primary.withAlpha(18)
                  : Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall
                              ?.copyWith(color: ext.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: kDurationSnap,
                  child: selected
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey('chk'),
                          color: colorScheme.primary,
                          size: 20,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          key: const ValueKey('unk'),
                          color: ext.border,
                          size: 20,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Фрейм шага с прокруткой: Kai вверху → заголовок → контент.
  Widget _stepFrame({
    required KaiEmotion kaiEmotion,
    required String title,
    String? subtitle,
    required Widget child,
    String? kaiBubbleText,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kai + речевой пузырь (если есть)
          Center(
            child: Column(
              children: [
                KaiMascot(size: 72, emotion: kaiEmotion),
                if (kaiBubbleText != null) ...[
                  const SizedBox(height: 10),
                  KaiSpeechBubble(
                    message: kaiBubbleText,
                    animate: true,
                    maxWidth: 260,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(title, style: textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: textTheme.bodyLarge?.copyWith(color: ext.textMuted),
            ),
          ],
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // build()
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Последний экран — саммари (индекс 13); его CTA вызывает _finish() → /paywall.
    final isLastPage = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- Верхняя панель: прогресс + ПОСТОЯННЫЙ «Пропустить» (выход в
            //     приложение на любом экране — страховка от «застрял») ---
            _buildProgressRow(textTheme, colorScheme, ext),

            // --- Страницы ---
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() {
                  _page = i;
                  // Сбрасываем демо при возврате на экран демо-пересборки (8)
                  if (i == 8) _taskMoved = false;
                  // Запускаем «расчёт» на экране сводки (13)
                  if (i == 13) _triggerSummaryReady();
                }),
                children: [
                  _buildScreen5(),       // 0  Цели
                  _buildScreen6(),       // 1  Время на планирование
                  _buildScreen7(),       // 2  Горизонт
                  _buildScreen8(),       // 3  Проекция
                  _buildScreen9(),       // 4  Возраст/пол
                  _buildScreen10(),      // 5  Рост/вес
                  _buildScreen11(),      // 6  Активность
                  _buildScreen12(),      // 7  Первая задача
                  _buildScreen13(),      // 8  Демо-пересборка
                  _buildScreen14(),      // 9  Время разборов
                  _buildNotifStep(),     // 10 Разрешение на уведомления
                  _buildToneStep(),      // 11 Тон gentle/harsh
                  _buildThemeStep(),     // 12 Тема оформления
                  _buildScreen15(),      // 13 Сводка (последний; CTA → /paywall)
                ],
              ),
            ),

            // --- Нижние кнопки ---
            _buildBottomButtons(isLastPage, ext),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Прогресс-индикатор (X/14, скрыт на демо-экране 8)
  // ---------------------------------------------------------------------------

  Widget _buildProgressRow(
    TextTheme textTheme,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    // Нумеруем 1-based; на демо-экране 8 прогресс-бар скрыт (_showProgress).
    final displayPage = _page + 1;
    final total = _pageCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
      child: Row(
        children: [
          // Прогресс-бар — только на экранах с прогрессом; иначе пустое место,
          // чтобы «Пропустить» всегда оставался на месте справа.
          if (_showProgress) ...[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: displayPage / total,
                  backgroundColor: ext.border,
                  color: colorScheme.primary,
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Flexible + ellipsis: на крупном textScale двузначный счётчик
            // («11 / 15») вместе с «Пропустить» не должен переполнять строку.
            Flexible(
              child: Text(
                '$displayPage / $total',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(width: 8),
          // ПОСТОЯННЫЙ выход в приложение — на КАЖДОМ экране (страховка).
          TextButton(
            onPressed: _skipAllToApp,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: Text(
              context.s('onboarding_quiz.skip_all'),
              style: textTheme.labelSmall?.copyWith(color: ext.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  /// Аварийный выход из онбординга прямо в приложение (на любом экране).
  /// Сохраняет setup_done, чтобы онбординг больше не показывался.
  Future<void> _skipAllToApp() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(setupDoneKey, true);
    if (mounted) context.go('/today');
  }

  // ---------------------------------------------------------------------------
  // Нижние кнопки
  // ---------------------------------------------------------------------------

  Widget _buildBottomButtons(bool isLast, FocusThemeExtension ext) {
    final isFirst = _page == 0;
    // Кастомный лейбл CTA по странице
    final ctaKey = _ctaKey(_page);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Row(
        children: [
          if (!isFirst) ...[
            SizedBox(
              width: 52,
              height: 52,
              child: OutlinedButton(
                onPressed: _back,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: switch (_page) {
                  7 => _handleAddTask,
                  10 => _handleNotifPermission,
                  _ => _next,
                },
                child: Text(context.s(ctaKey)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ключ строки для CTA по индексу страницы.
  String _ctaKey(int page) => switch (page) {
        0 => 'onboarding_quiz.s5_cta', // Цели
        1 => 'onboarding_quiz.s6_cta', // Время на планирование
        2 => 'onboarding_quiz.s7_cta', // Горизонт
        3 => 'onboarding_quiz.s8_cta', // Проекция
        4 => 'onboarding_quiz.s9_cta', // Возраст/пол
        5 => 'onboarding_quiz.s10_cta', // Рост/вес
        6 => 'onboarding_quiz.s11_cta', // Активность
        7 => 'onboarding_quiz.s12_cta', // Добавить задачу
        8 => 'onboarding_quiz.s13_cta', // Демо-пересборка
        9 => 'onboarding_quiz.s14_cta', // Время разборов
        10 => 'onboarding_quiz.notif_cta', // Уведомления
        11 => 'onboarding_quiz.tone_cta', // Тон
        12 => 'onboarding_quiz.theme_cta', // Тема
        13 => 'onboarding_quiz.s15_cta', // Сводка
        _ => 'onboarding_quiz.s5_cta',
      };

  // ---------------------------------------------------------------------------
  // Добавление первой задачи (экран 12)
  // ---------------------------------------------------------------------------

  Future<void> _handleAddTask() async {
    final title = _firstTaskController.text.trim();
    if (title.isEmpty) {
      setState(() => _taskError = true);
      return;
    }
    setState(() => _taskError = false);
    // Захватываем длительность до async-gap
    final animDelay = effectiveDuration(context, kDurationNormal);
    final ok = await _insertFirstTask(title);
    if (ok) {
      setState(() {
        _taskAdded = true;
        _addedTaskTitle = title;
      });
      // Небольшая задержка для микро-анимации, затем переход
      await Future<void>.delayed(animDelay);
      if (mounted) _next();
    }
  }

  // ---------------------------------------------------------------------------
  // Разрешение на уведомления (экран 11 в общем флоу, индекс 10)
  // ---------------------------------------------------------------------------

  /// Запрашивает системное разрешение на уведомления и включает напоминания.
  /// Сначала фиксирует выбранные на прошлом шаге часы разборов в prefs, чтобы
  /// планировщик использовал именно их. При отказе остаётся выключенным
  /// (`notifications_enabled=false`); не падает — всегда продолжает флоу.
  Future<void> _handleNotifPermission() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(reviewMorningHourKey, _morningHour);
    await prefs.setInt(reviewEveningHourKey, _eveningHour);
    try {
      // setEnabled сам запрашивает разрешение и при отказе оставляет false.
      await ref.read(notificationsEnabledProvider.notifier).setEnabled(true);
    } catch (_) {
      // Уведомления не должны блокировать онбординг.
    }
    if (mounted) _next();
  }

  // ---------------------------------------------------------------------------
  // Фейковый «расчёт» для экрана 15 (KaiLoader не нужен — саммари мгновенный)
  // ---------------------------------------------------------------------------

  void _triggerSummaryReady() {
    setState(() => _summaryReady = false);
    Future<void>.delayed(const Duration(milliseconds: 400))
        .then((_) {
      if (mounted) setState(() => _summaryReady = true);
    });
  }

  // ---------------------------------------------------------------------------
  // Экран 5: Цели (multiselect)
  // ---------------------------------------------------------------------------

  Widget _buildScreen5() {
    final goals = [
      ('study', context.s('onboarding_quiz.goal_study')),
      ('procrastination', context.s('onboarding_quiz.goal_procrastination')),
      ('routine', context.s('onboarding_quiz.goal_routine')),
      ('free_time', context.s('onboarding_quiz.goal_free_time')),
      ('exams', context.s('onboarding_quiz.goal_exams')),
    ];
    return _stepFrame(
      kaiEmotion: KaiEmotion.thinking,
      title: context.s('onboarding_quiz.s5_title'),
      subtitle: context.s('onboarding_quiz.s5_subtitle'),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        children: goals.map((pair) {
          final id = pair.$1;
          final label = pair.$2;
          final selected = _selectedGoals.contains(id);
          return FilterChip(
            label: Text(label),
            selected: selected,
            onSelected: (v) => setState(() {
              if (v) {
                _selectedGoals.add(id);
              } else {
                _selectedGoals.remove(id);
              }
            }),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран 6: Время на планирование (single select)
  // ---------------------------------------------------------------------------

  Widget _buildScreen6() {
    return _stepFrame(
      kaiEmotion: KaiEmotion.thinking,
      title: context.s('onboarding_quiz.s6_title'),
      subtitle: context.s('onboarding_quiz.s6_subtitle'),
      child: Column(
        children: [
          _choiceTile(
            selected: _planOption == 'none',
            title: context.s('onboarding_quiz.plan_none'),
            onTap: () => setState(() => _planOption = 'none'),
          ),
          _choiceTile(
            selected: _planOption == '10',
            title: context.s('onboarding_quiz.plan_10'),
            onTap: () => setState(() => _planOption = '10'),
          ),
          _choiceTile(
            selected: _planOption == '30',
            title: context.s('onboarding_quiz.plan_30'),
            onTap: () => setState(() => _planOption = '30'),
          ),
          _choiceTile(
            selected: _planOption == 'more',
            title: context.s('onboarding_quiz.plan_more'),
            onTap: () => setState(() => _planOption = 'more'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран 7: Горизонт планирования
  // ---------------------------------------------------------------------------

  Widget _buildScreen7() {
    return _stepFrame(
      kaiEmotion: KaiEmotion.neutral,
      title: context.s('onboarding_quiz.s7_title'),
      child: Column(
        children: [
          _choiceTile(
            selected: _horizon == 'day',
            title: context.s('onboarding_quiz.horizon_day'),
            onTap: () => setState(() => _horizon = 'day'),
          ),
          _choiceTile(
            selected: _horizon == 'week',
            title: context.s('onboarding_quiz.horizon_week'),
            onTap: () => setState(() => _horizon = 'week'),
          ),
          _choiceTile(
            selected: _horizon == 'months',
            title: context.s('onboarding_quiz.horizon_months'),
            onTap: () => setState(() => _horizon = 'months'),
          ),
          _choiceTile(
            selected: _horizon == 'years',
            title: context.s('onboarding_quiz.horizon_years'),
            onTap: () => setState(() => _horizon = 'years'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран 8: Проекция (derived)
  // ---------------------------------------------------------------------------

  Widget _buildScreen8() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final minutes = _planMinutesMap[_planOption] ?? 0;

    // Нулевой кейс: «Почти не планирую» → не показываем «~0 часов»,
    // вместо этого мотивирующий текст без числа.
    if (minutes == 0) {
      return _stepFrame(
        kaiEmotion: KaiEmotion.neutral,
        title: context.s('onboarding_quiz.s8_none_headline'),
        child: Column(
          children: [
            Text(
              context.s('onboarding_quiz.s8_none_body'),
              style: textTheme.bodyLarge?.copyWith(color: ext.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Обычный кейс: честный расчёт мин/день × 365 / 60.
    final hoursPerYear = (minutes * 365 / 60).round();

    return _stepFrame(
      kaiEmotion: KaiEmotion.success,
      title: '',
      child: Column(
        children: [
          // Большой акцентный номер
          Text(
            '~$hoursPerYear',
            style: textTheme.displayLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${context.s('onboarding_quiz.s8_title_prefix')} — '
            '${context.s('onboarding_quiz.s8_title_suffix')}',
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            context.s('onboarding_quiz.s8_body'),
            style: textTheme.bodyLarge?.copyWith(color: ext.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран 9: Возраст + пол
  // ---------------------------------------------------------------------------

  Widget _buildScreen9() {
    final textTheme = Theme.of(context).textTheme;
    return _stepFrame(
      kaiEmotion: KaiEmotion.neutral,
      title: context.s('onboarding_quiz.s9_title'),
      subtitle: context.s('onboarding_quiz.s9_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Возраст
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: context.s('onboarding.norms_age'),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),
          // Пол
          Text(context.s('onboarding.norms_sex'),
              style: textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              (context.s('onboarding.sex_male'), 'male'),
              (context.s('onboarding.sex_female'), 'female'),
              (context.s('onboarding.sex_other'), 'other'),
            ].map((pair) {
              final label = pair.$1;
              final value = pair.$2;
              return ChoiceChip(
                label: Text(label),
                selected: _sex == value,
                onSelected: (_) => setState(() => _sex = value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран 10: Рост + вес
  // ---------------------------------------------------------------------------

  Widget _buildScreen10() {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    // Проверяем вес для показа рекомендации
    final weightVal = double.tryParse(_weightController.text.trim());
    final hasValidWeight = weightVal != null && weightVal > 0;
    final recommended = hasValidWeight
        ? recommendedWaterMl(
            weightKg: weightVal,
            activity: _activity,
            heightCm: double.tryParse(_heightController.text.trim()),
            age: int.tryParse(_ageController.text.trim()),
          )
        : null;

    return _stepFrame(
      kaiEmotion: KaiEmotion.neutral,
      title: context.s('onboarding_quiz.s10_title'),
      subtitle: context.s('onboarding_quiz.s10_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: context.s('onboarding.norms_weight'),
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: context.s('onboarding.norms_height'),
                    helperText: context.s('onboarding.norms_height_helper'),
                  ),
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Рекомендация воды (живая)
          if (recommended != null) ...[
            Row(
              children: [
                Icon(Icons.water_drop_outlined,
                    size: 16, color: ext.success),
                const SizedBox(width: 6),
                Text(
                  '${context.s('onboarding.norms_recommended')}: $recommended ml',
                  style: textTheme.bodyMedium?.copyWith(
                    color: ext.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          // Слайдер воды
          Text('$_waterGoal ml', style: textTheme.headlineSmall),
          Slider(
            value: _waterGoal.toDouble(),
            min: 1000,
            max: 4000,
            divisions: 30,
            label: '$_waterGoal ml',
            onChanged: (v) => setState(() => _waterGoal = v.round()),
          ),
          Text(
            context.s('onboarding.norms_adjust_hint'),
            style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран 11: Активность (4 карточки)
  // ---------------------------------------------------------------------------

  Widget _buildScreen11() {
    return _stepFrame(
      kaiEmotion: KaiEmotion.neutral,
      title: context.s('onboarding_quiz.s11_title'),
      subtitle: context.s('onboarding_quiz.s11_subtitle'),
      child: Column(
        children: [
          _choiceTile(
            selected: _activity == 'low',
            title: context.s('onboarding_quiz.activity_low_label'),
            subtitle: context.s('onboarding_quiz.activity_low_sub'),
            onTap: () {
              setState(() => _activity = 'low');
              _recalcWater();
            },
          ),
          _choiceTile(
            selected: _activity == 'medium',
            title: context.s('onboarding_quiz.activity_medium_label'),
            subtitle: context.s('onboarding_quiz.activity_medium_sub'),
            onTap: () {
              setState(() => _activity = 'medium');
              _recalcWater();
            },
          ),
          _choiceTile(
            selected: _activity == 'high',
            title: context.s('onboarding_quiz.activity_high_label'),
            subtitle: context.s('onboarding_quiz.activity_high_sub'),
            onTap: () {
              setState(() => _activity = 'high');
              _recalcWater();
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран 12: Первая задача (NO skip)
  // ---------------------------------------------------------------------------

  Widget _buildScreen12() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                KaiMascot(
                  size: 72,
                  emotion: _taskAdded
                      ? KaiEmotion.success
                      : KaiEmotion.neutral,
                ),
                const SizedBox(height: 10),
                KaiSpeechBubble(
                  message: context.s('onboarding_quiz.s12_kai_line'),
                  animate: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(context.s('onboarding_quiz.s12_title'),
              style: textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            context.s('onboarding_quiz.s12_subtitle'),
            style: textTheme.bodyLarge?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 28),

          // Поле ввода задачи
          VoiceTextField(
            controller: _firstTaskController,
            labelText: context.s('onboarding_quiz.s12_hint'),
            maxLines: 2,
          ),

          // Короткое объяснение приоритетов (врезка). Наименее инвазивно:
          // не добавляет экран, не трогает счётчик шагов.
          const SizedBox(height: 20),
          _PriorityExplainer(),

          // Ошибка
          if (_taskError) ...[
            const SizedBox(height: 8),
            Text(
              context.s('onboarding_quiz.s12_err_empty'),
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.error),
            ),
          ],

          // Микро-праздник после добавления
          if (_taskAdded) ...[
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: kDurationNormal,
              curve: kCurveSpring,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: colorScheme.primary.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"$_addedTaskTitle"',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран 13: Демо переноса (NO progress bar)
  // ---------------------------------------------------------------------------

  Widget _buildScreen13() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        children: [
          Center(
            child: Column(
              children: [
                KaiMascot(
                  size: 80,
                  emotion: _taskMoved
                      ? KaiEmotion.success
                      : KaiEmotion.neutral,
                ),
                const SizedBox(height: 10),
                if (_taskMoved)
                  KaiSpeechBubble(
                    message: context.s('onboarding_quiz.s13_kai_line'),
                    animate: true,
                    maxWidth: 280,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(context.s('onboarding_quiz.s13_title'),
              style: textTheme.headlineSmall),
          const SizedBox(height: 24),

          // Карточка задачи — «живая» sandbox
          AnimatedContainer(
            duration: kDurationNormal,
            curve: kCurveLift,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ext.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        color: colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _addedTaskTitle.isNotEmpty
                            ? _addedTaskTitle
                            : context.s('onboarding_quiz.s13_title'),
                        style: textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                if (_taskMoved) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.s('onboarding_quiz.s13_task_moved'),
                    style: textTheme.bodySmall
                        ?.copyWith(color: ext.success),
                  ),
                ],
              ],
            ),
          ),

          if (!_taskMoved) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.s('onboarding_quiz.s13_question'),
                style:
                    textTheme.bodyLarge?.copyWith(color: ext.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(context.s('onboarding_quiz.s13_move_btn')),
              onPressed: () => setState(() => _taskMoved = true),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран 14: Время разборов
  // ---------------------------------------------------------------------------

  Widget _buildScreen14() {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Форматирование часа для кнопок выбора времени сна
    String formatHour(int h) {
      final period = h < 12 ? 'AM' : 'PM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:00 $period';
    }

    return _stepFrame(
      kaiEmotion: KaiEmotion.neutral,
      title: context.s('onboarding_quiz.s14_title'),
      subtitle: context.s('onboarding_quiz.s14_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Время разборов ---
          _choiceTile(
            selected: _timing == _TimingOption.morning,
            title: context.s('onboarding_quiz.timing_morning'),
            onTap: () {
              setState(() {
                _timing = _TimingOption.morning;
                _morningHour = kMorningHour;
              });
            },
          ),
          _choiceTile(
            selected: _timing == _TimingOption.afternoon,
            title: context.s('onboarding_quiz.timing_afternoon'),
            onTap: () {
              setState(() {
                _timing = _TimingOption.afternoon;
                _morningHour = 13;
                _eveningHour = kEveningHour;
              });
            },
          ),
          _choiceTile(
            selected: _timing == _TimingOption.evening,
            title: context.s('onboarding_quiz.timing_evening'),
            onTap: () {
              setState(() {
                _timing = _TimingOption.evening;
                _eveningHour = kEveningHour;
              });
            },
          ),
          _choiceTile(
            selected: _timing == _TimingOption.both,
            title: context.s('onboarding_quiz.timing_both'),
            onTap: () {
              setState(() {
                _timing = _TimingOption.both;
                _morningHour = kMorningHour;
                _eveningHour = kEveningHour;
              });
            },
          ),

          // --- Расписание сна (ITEM B) ---
          // TODO(sleep-distribution): значения будут читаться планировщиком
          // для «ночного окна» — никаких задач/напоминаний в [bedtime, wake].
          // Крупные карточки вместо тонких OutlinedButton — заметнее и понятнее.
          // Стек вертикально (по карточке на строку), чтобы пережить 320px / 1.5x.
          const SizedBox(height: 28),
          Text(
            context.s('onboarding_quiz.s14_sleep_section_title'),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.s('onboarding_quiz.s14_sleep_hint'),
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 16),
          _sleepTimeCard(
            icon: Icons.bedtime_outlined,
            label: context.s('onboarding_quiz.s14_bedtime_q'),
            time: formatHour(_bedtimeHour),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: _bedtimeHour, minute: 0),
              );
              if (picked != null) {
                setState(() => _bedtimeHour = picked.hour);
              }
            },
          ),
          const SizedBox(height: 12),
          _sleepTimeCard(
            icon: Icons.wb_sunny_outlined,
            label: context.s('onboarding_quiz.s14_wake_q'),
            time: formatHour(_wakeHour),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: _wakeHour, minute: 0),
              );
              if (picked != null) {
                setState(() => _wakeHour = picked.hour);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Крупная карточка выбора времени сна/подъёма (экран 14). Заполненная
  /// поверхность + рамка + иконка в кружке, под вопросом — крупное время.
  /// Текст в Expanded с ellipsis → переживает узкий экран и крупный textScale.
  Widget _sleepTimeCard({
    required IconData icon,
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ext.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style:
                          textTheme.bodySmall?.copyWith(color: ext.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 18, color: ext.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Шаг (индекс 10): Разрешение на уведомления
  // ---------------------------------------------------------------------------
  // Пояснительный экран. Сама кнопка снизу (`notif_cta`) делает системный
  // запрос через _handleNotifPermission; тут — копия + иконка + «Не сейчас».

  Widget _buildNotifStep() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return _stepFrame(
      kaiEmotion: KaiEmotion.neutral,
      title: context.s('onboarding_quiz.notif_title'),
      subtitle: context.s('onboarding_quiz.notif_subtitle'),
      child: Column(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                size: 40,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // «Не сейчас» — пропускаем без включения уведомлений.
          Center(
            child: TextButton(
              onPressed: _next,
              child: Text(
                context.s('onboarding_quiz.notif_skip'),
                style: textTheme.labelLarge?.copyWith(color: ext.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Шаг (индекс 11): Тон общения (gentle / harsh)
  // ---------------------------------------------------------------------------
  // Выбор пишется сразу в toneProvider (живо), выбранный тайл подсвечивается.

  Widget _buildToneStep() {
    final tone = ref.watch(toneProvider);
    return _stepFrame(
      kaiEmotion: KaiEmotion.thinking,
      title: context.s('onboarding_quiz.tone_title'),
      subtitle: context.s('onboarding_quiz.tone_subtitle'),
      child: Column(
        children: [
          _choiceTile(
            selected: tone == AppTone.gentle,
            title: context.s('onboarding_quiz.tone_gentle_label'),
            subtitle: context.s('onboarding_quiz.tone_gentle_sub'),
            leading: const Text('🌿', style: TextStyle(fontSize: 22)),
            onTap: () => ref.read(toneProvider.notifier).set(AppTone.gentle),
          ),
          _choiceTile(
            selected: tone == AppTone.harsh,
            title: context.s('onboarding_quiz.tone_harsh_label'),
            subtitle: context.s('onboarding_quiz.tone_harsh_sub'),
            leading: const Text('🔥', style: TextStyle(fontSize: 22)),
            onTap: () => ref.read(toneProvider.notifier).set(AppTone.harsh),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Шаг (индекс 12): Тема оформления (4 темы Kaname v4)
  // ---------------------------------------------------------------------------
  // Выбор пишется сразу в themeNotifierProvider (живо), с цветным свотчем.

  Widget _buildThemeStep() {
    final current = ref.watch(themeNotifierProvider);
    const themes = [
      AppThemeKey.day,
      AppThemeKey.night,
      AppThemeKey.black,
      AppThemeKey.calm,
    ];
    return _stepFrame(
      kaiEmotion: KaiEmotion.neutral,
      title: context.s('onboarding_quiz.theme_title'),
      subtitle: context.s('onboarding_quiz.theme_subtitle'),
      child: Column(
        children: themes.map((key) {
          return _choiceTile(
            selected: current == key,
            title: context.s(_themeLabelKey(key)),
            leading: _themeSwatchDot(key),
            onTap: () =>
                ref.read(themeNotifierProvider.notifier).setTheme(key),
          );
        }).toList(),
      ),
    );
  }

  /// Ключ локализованного названия темы (Kaname v4: 4 темы).
  String _themeLabelKey(AppThemeKey key) => switch (key) {
        AppThemeKey.day => 'onboarding_quiz.theme_day',
        AppThemeKey.night => 'onboarding_quiz.theme_night',
        AppThemeKey.black => 'onboarding_quiz.theme_black',
        AppThemeKey.calm => 'onboarding_quiz.theme_calm',
      };

  /// Маленький круглый свотч-превью темы (bg + accent-точка). Цвета зеркалят
  /// design-tokens.json, чтобы не строить полный ThemeData (GoogleFonts) на тайл.
  Widget _themeSwatchDot(AppThemeKey key) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final pair = _kThemeSwatch[key] ??
        (const Color(0xFF141009), const Color(0xFFD9F24B));
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: pair.$1,
        shape: BoxShape.circle,
        border: Border.all(color: ext.border),
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: pair.$2,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран 15: Саммари
  // ---------------------------------------------------------------------------

  /// Вычисляет нормы питания локально из введённых данных онбординга.
  /// Если вес/рост/возраст не заполнены — возвращает NutritionTargets.fallback.
  NutritionTargets _computeLocalNutrition() {
    final weight = double.tryParse(_weightController.text.trim());
    final heightCm = double.tryParse(_heightController.text.trim());
    final age = int.tryParse(_ageController.text.trim());
    if (weight == null || weight <= 0 ||
        heightCm == null || heightCm <= 0 ||
        age == null || age <= 0) {
      return NutritionTargets.fallback;
    }
    return computeNutritionTargets(
      weightKg: weight,
      heightCm: heightCm,
      age: age,
      sex: _sex,
      activity: _activity,
      goal: 'maintain', // флоу онбординга не собирает цель питания
    );
  }

  Widget _buildScreen15() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // FIX 2: используем локальное поле _waterGoal (уже пересчитывается
    // через _recalcWater при изменении веса/роста/возраста/активности),
    // а не ref.watch(waterGoalProvider), который читает ещё не записанные prefs.
    //
    // FIX 3: вычисляем калории локально из введённых данных онбординга,
    // а не через nutritionTargetsProvider (читает prefs до того, как _finish()
    // их записал — возвращает дефолт 2000 ккал).
    final waterGoal = _waterGoal;
    final nutrition = _computeLocalNutrition();

    // Язык
    final locale = ref.watch(localeNotifierProvider);
    final langName = localeEntries
            .cast<LocaleEntry?>()
            .firstWhere(
              (e) => localeTag(e!.locale) == localeTag(locale),
              orElse: () => null,
            )
            ?.displayName ??
        locale.languageCode;

    // Первая цель (если есть)
    final firstGoalId = _selectedGoals.isNotEmpty
        ? _selectedGoals.first
        : null;
    final goalLabel = firstGoalId != null
        ? context.s('onboarding_quiz.goal_$firstGoalId')
        : context.s('onboarding_quiz.s15_no_goal');

    // Время разборов
    final timingLabel = switch (_timing) {
      _TimingOption.morning => context.s('onboarding_quiz.timing_morning'),
      _TimingOption.afternoon =>
        context.s('onboarding_quiz.timing_afternoon'),
      _TimingOption.evening => context.s('onboarding_quiz.timing_evening'),
      _TimingOption.both => context.s('onboarding_quiz.timing_both'),
    };

    // Тон общения (выбран на шаге тона; живёт в toneProvider).
    final tone = ref.watch(toneProvider);
    final toneLabel = tone == AppTone.harsh
        ? context.s('onboarding_quiz.tone_harsh_label')
        : context.s('onboarding_quiz.tone_gentle_label');

    // Тема оформления (выбрана на шаге темы; живёт в themeNotifierProvider).
    final themeKey = ref.watch(themeNotifierProvider);
    final themeLabel = context.s(_themeLabelKey(themeKey));

    // Расписание сна (ITEM B)
    String formatHourShort(int h) {
      final period = h < 12 ? 'AM' : 'PM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:00 $period';
    }

    final sleepStr =
        '${context.s('health_profile.bedtime_label')}: ${formatHourShort(_bedtimeHour)} · '
        '${context.s('health_profile.wake_label')}: ${formatHourShort(_wakeHour)}';

    // Вода
    final waterStr = context
        .s('onboarding_quiz.s15_water_value')
        .replaceAll('{n}', '$waterGoal');

    // Калории
    final calStr = context
        .s('onboarding_quiz.s15_cal_value')
        .replaceAll('{n}', '${nutrition.kcal}');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        children: [
          Center(
            child: KaiMascot(size: 80, emotion: KaiEmotion.success),
          ),
          const SizedBox(height: 24),
          Text(context.s('onboarding_quiz.s15_title'),
              style: textTheme.headlineSmall),
          const SizedBox(height: 24),

          // Карточка саммари
          AnimatedOpacity(
            opacity: _summaryReady ? 1.0 : 0.0,
            duration: kDurationNormal,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ext.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryRow(
                    icon: Icons.language_rounded,
                    label: context.s('onboarding_quiz.s15_lang_label'),
                    value: langName,
                    textTheme: textTheme,
                    ext: ext,
                  ),
                  _summaryDivider(ext),
                  _summaryRow(
                    icon: Icons.flag_rounded,
                    label: context.s('onboarding_quiz.s15_goal_label'),
                    value: goalLabel,
                    textTheme: textTheme,
                    ext: ext,
                  ),
                  _summaryDivider(ext),
                  _summaryRow(
                    icon: Icons.water_drop_outlined,
                    label: context.s('onboarding_quiz.s15_water_label'),
                    value: waterStr,
                    textTheme: textTheme,
                    ext: ext,
                  ),
                  _summaryDivider(ext),
                  _summaryRow(
                    icon: Icons.local_fire_department_outlined,
                    label: context.s('onboarding_quiz.s15_cal_label'),
                    value: calStr,
                    textTheme: textTheme,
                    ext: ext,
                  ),
                  _summaryDivider(ext),
                  _summaryRow(
                    icon: Icons.notifications_none_rounded,
                    label:
                        context.s('onboarding_quiz.s15_timing_label'),
                    value: timingLabel,
                    textTheme: textTheme,
                    ext: ext,
                  ),
                  _summaryDivider(ext),
                  _summaryRow(
                    icon: Icons.bedtime_outlined,
                    label: context.s('health_profile.sleep_schedule_label'),
                    value: sleepStr,
                    textTheme: textTheme,
                    ext: ext,
                  ),
                  _summaryDivider(ext),
                  _summaryRow(
                    icon: Icons.record_voice_over_outlined,
                    label: context.s('onboarding_quiz.s15_tone_label'),
                    value: toneLabel,
                    textTheme: textTheme,
                    ext: ext,
                  ),
                  _summaryDivider(ext),
                  _summaryRow(
                    icon: Icons.palette_outlined,
                    label: context.s('onboarding_quiz.s15_theme_label'),
                    value: themeLabel,
                    textTheme: textTheme,
                    ext: ext,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider(FocusThemeExtension ext) => Divider(
        color: ext.border,
        height: 24,
        thickness: 0.5,
      );

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
    required TextTheme textTheme,
    required FocusThemeExtension ext,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      textTheme.labelSmall?.copyWith(color: ext.textMuted)),
              const SizedBox(height: 2),
              Text(value, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Врезка: краткое объяснение приоритетов (экран «первая задача»)
// ---------------------------------------------------------------------------

/// Компактная карточка-объяснение системы приоритетов:
/// «Главное» защищено от авто-переноса и держит серию; «Важная»/«Обычная»
/// влияют только на порядок переноса несделанного.
class _PriorityExplainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.s('onboarding_quiz.priorities_title'),
                  style: textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.s('onboarding_quiz.priorities_main'),
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            context.s('onboarding_quiz.priorities_other'),
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
          ),
        ],
      ),
    );
  }
}
