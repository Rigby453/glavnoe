// Настройка после онбординга и входа (SPEC C1, единый поток):
// интересы → импорт расписания → время разборов → тон → тема → нормы.
// Каждый шаг можно пропустить; всё сохраняется в SharedPreferences/провайдеры.
// Флаг 'setup_done' держит пользователя на /setup через redirect роутера.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider, themeProvider
import '../../services/notifications/notification_service.dart';
import '../import/import_sheet.dart';

const setupDoneKey = 'setup_done';
const reviewMorningHourKey = 'review_morning_hour';
const reviewEveningHourKey = 'review_evening_hour';
const interestsKey = 'interests';

// Ключи интересов (сохраняются как есть — идентификаторы).
// Локализованные подписи берутся из S по ключу 'onboarding.interest_<value>'.
const _interestValues = <String>[
  'University',
  'Exams',
  'Side projects',
  'Fitness',
  'Nutrition',
  'Sleep',
  'Focus',
  'Reading',
];

// Локализационные ключи для интересов (один к одному с _interestValues).
const _interestL10nKeys = <String>[
  'onboarding.interest_university',
  'onboarding.interest_exams',
  'onboarding.interest_side_projects',
  'onboarding.interest_fitness',
  'onboarding.interest_nutrition',
  'onboarding.interest_sleep',
  'onboarding.interest_focus',
  'onboarding.interest_reading',
];

class SetupFlowScreen extends ConsumerStatefulWidget {
  const SetupFlowScreen({super.key});

  @override
  ConsumerState<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends ConsumerState<SetupFlowScreen> {
  final _pageController = PageController();
  int _page = 0;
  static const _pageCount = 6;

  // Локальное состояние шагов (сохраняется при Finish)
  final Set<String> _selectedInterests = {};
  int _morningHour = kMorningHour; // 8
  int _eveningHour = kEveningHour; // 20
  int _waterGoal = kDefaultWaterGoalMl;

  // Антропометрия — шаг «нормы»
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String _activity = 'medium'; // 'low' | 'medium' | 'high'

  @override
  void initState() {
    super.initState();
    _waterGoal = ref.read(waterGoalProvider);
    // Слушаем изменения полей — пересчитываем рекомендацию на лету.
    _weightController.addListener(_recalcWater);
    _heightController.addListener(_recalcWater);
  }

  @override
  void dispose() {
    _weightController.removeListener(_recalcWater);
    _heightController.removeListener(_recalcWater);
    _weightController.dispose();
    _heightController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Пересчитывает рекомендацию воды при изменении веса или активности.
  /// Если поле веса пустое или невалидное — ничего не делаем.
  void _recalcWater() {
    final weightText = _weightController.text.trim();
    final weight = double.tryParse(weightText);
    if (weight == null || weight <= 0) return;
    final recommended = recommendedWaterMl(
      weightKg: weight,
      activity: _activity,
    );
    setState(() => _waterGoal = recommended);
  }

  Future<void> _finish() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(interestsKey, _selectedInterests.toList());
    await prefs.setInt(reviewMorningHourKey, _morningHour);
    await prefs.setInt(reviewEveningHourKey, _eveningHour);
    await ref.read(waterGoalProvider.notifier).set(_waterGoal);

    // Сохраняем антропометрию для будущей аналитики.
    final weight = double.tryParse(_weightController.text.trim());
    final height = int.tryParse(_heightController.text.trim());
    if (weight != null && weight > 0) {
      await prefs.setDouble(kUserWeightKgKey, weight);
    }
    if (height != null && height > 0) {
      await prefs.setInt(kUserHeightCmKey, height);
    }
    await prefs.setString(kUserActivityKey, _activity);

    // Если напоминания уже включены — перепланируем под выбранные часы.
    if (ref.read(notificationsEnabledProvider)) {
      try {
        await ref.read(notificationServiceProvider).scheduleDailyReviews(
              morningHour: _morningHour,
              eveningHour: _eveningHour,
            );
      } catch (_) {
        // Уведомления не должны блокировать завершение настройки.
      }
    }

    await prefs.setBool(setupDoneKey, true);
    if (mounted) context.go('/today');
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _pageController.nextPage(
        duration: kDurationFast,
        curve: kCurveSnap,
      );
    } else {
      _finish();
    }
  }

  /// Возвращается на предыдущий шаг (вызывается с кнопки Back).
  /// На первом шаге кнопка не показывается.
  void _back() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: kDurationFast,
        curve: kCurveSnap,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = _page == _pageCount - 1;
    final isFirst = _page == 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя строка: прогресс + «Skip all»
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text(
                    '${context.s('onboarding.setup_progress')} · ${_page + 1}/$_pageCount',
                    style: textTheme.labelMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(context.s('onboarding.skip_all')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _interestsStep(textTheme),
                  _importStep(textTheme),
                  _reviewTimeStep(textTheme),
                  _toneStep(textTheme),
                  _themeStep(textTheme, colorScheme),
                  _normsStep(textTheme),
                ],
              ),
            ),
            // Нижняя строка с Back (шаги 2..N) и Next/Start
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  // Кнопка «Back» — только не на первом шаге
                  if (!isFirst)
                    IconButton(
                      tooltip: context.s('btn.back'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _back,
                    )
                  else
                    // Заполнитель, чтобы Next не прыгал по ширине
                    const SizedBox(width: 48),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(
                        isLast
                            ? context.s('onboarding.btn_start')
                            : context.s('onboarding.btn_continue'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, style: textTheme.bodyMedium),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  // --- Шаг 1: интересы ---
  Widget _interestsStep(TextTheme textTheme) {
    return _step(
      title: context.s('onboarding.interests_title'),
      subtitle: context.s('onboarding.interests_subtitle'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(_interestValues.length, (i) {
          final value = _interestValues[i];
          final l10nKey = _interestL10nKeys[i];
          final selected = _selectedInterests.contains(value);
          return FilterChip(
            label: Text(context.s(l10nKey)),
            selected: selected,
            onSelected: (v) => setState(() {
              if (v) {
                _selectedInterests.add(value);
              } else {
                _selectedInterests.remove(value);
              }
            }),
          );
        }),
      ),
    );
  }

  // --- Шаг 2: импорт расписания ---
  Widget _importStep(TextTheme textTheme) {
    return _step(
      title: context.s('onboarding.import_title'),
      subtitle: context.s('onboarding.import_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.content_paste_go),
            label: Text(context.s('onboarding.import_now')),
            onPressed: () => showImportSheet(context, day: DateTime.now()),
          ),
          const SizedBox(height: 8),
          Text(
            context.s('onboarding.import_premium_hint'),
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // --- Шаг 3: время разборов ---
  Widget _reviewTimeStep(TextTheme textTheme) {
    Future<void> pick(bool morning) async {
      final initial = TimeOfDay(
        hour: morning ? _morningHour : _eveningHour,
        minute: 0,
      );
      final picked = await showTimePicker(context: context, initialTime: initial);
      if (picked != null) {
        setState(() {
          // Напоминания планируются по часам (inexact) — минуты отбрасываем.
          if (morning) {
            _morningHour = picked.hour;
          } else {
            _eveningHour = picked.hour;
          }
        });
      }
    }

    Widget tile(String label, int hour, bool morning) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          trailing: OutlinedButton(
            onPressed: () => pick(morning),
            child: Text('${hour.toString().padLeft(2, '0')}:00'),
          ),
        );

    return _step(
      title: context.s('onboarding.review_title'),
      subtitle: context.s('onboarding.review_subtitle'),
      child: Column(
        children: [
          tile(context.s('onboarding.review_morning'), _morningHour, true),
          tile(context.s('onboarding.review_evening'), _eveningHour, false),
        ],
      ),
    );
  }

  /// Селектор-плитка (вместо deprecated RadioListTile).
  Widget _choiceTile({
    required bool selected,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.15),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: selected
            ? Icon(Icons.check_circle, color: colorScheme.primary)
            : const Icon(Icons.circle_outlined),
      ),
    );
  }

  // --- Шаг 4: тон ---
  Widget _toneStep(TextTheme textTheme) {
    final tone = ref.watch(toneProvider);
    return _step(
      title: context.s('onboarding.tone_title'),
      subtitle: context.s('onboarding.tone_subtitle'),
      child: Column(
        children: [
          _choiceTile(
            selected: tone == AppTone.gentle,
            title: context.s('settings.gentle'),
            subtitle: context.s('onboarding.tone_gentle_subtitle'),
            onTap: () => ref.read(toneProvider.notifier).set(AppTone.gentle),
          ),
          _choiceTile(
            selected: tone == AppTone.harsh,
            title: context.s('settings.harsh'),
            subtitle: context.s('onboarding.tone_harsh_subtitle'),
            onTap: () => ref.read(toneProvider.notifier).set(AppTone.harsh),
          ),
        ],
      ),
    );
  }

  // --- Шаг 5: тема ---
  Widget _themeStep(TextTheme textTheme, ColorScheme colorScheme) {
    final current = ref.watch(themeNotifierProvider);
    return _step(
      title: context.s('onboarding.theme_title'),
      subtitle: context.s('onboarding.theme_subtitle'),
      child: Column(
        children: AppThemeKey.values.map((key) {
          return _choiceTile(
            selected: current == key,
            title: key.label,
            onTap: () =>
                ref.read(themeNotifierProvider.notifier).setTheme(key),
          );
        }).toList(),
      ),
    );
  }

  // --- Шаг 6: нормы ---
  // Поля вес и рост → расчёт нормы воды + слайдер для ручной корректировки.
  // Рост собирается для будущей аналитики, в формуле воды НЕ участвует.
  Widget _normsStep(TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;

    // Показываем рекомендацию, только если вес заполнен корректно
    final weightText = _weightController.text.trim();
    final weightVal = double.tryParse(weightText);
    final hasValidWeight = weightVal != null && weightVal > 0;

    final recommended = hasValidWeight
        ? recommendedWaterMl(weightKg: weightVal, activity: _activity)
        : null;

    return _step(
      title: context.s('onboarding.norms_title'),
      subtitle: context.s('onboarding.norms_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Поля антропометрии ---
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    // Разрешаем цифры и одну точку/запятую
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: context.s('onboarding.norms_weight'),
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    helperText: context.s('onboarding.norms_height_helper'),
                  ),
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Уровень активности ---
          Text(context.s('onboarding.norms_activity'), style: textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              (context.s('onboarding.activity_low'), 'low'),
              (context.s('onboarding.activity_medium'), 'medium'),
              (context.s('onboarding.activity_high'), 'high'),
            ].map((pair) {
              final label = pair.$1;
              final value = pair.$2;
              return ChoiceChip(
                label: Text(label),
                selected: _activity == value,
                onSelected: (_) {
                  setState(() => _activity = value);
                  _recalcWater();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // --- Рекомендация (живая) ---
          if (recommended != null) ...[
            Row(
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${context.s('onboarding.norms_recommended')}: $recommended ml',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // --- Текущее значение + слайдер (можно поправить вручную) ---
          Text('$_waterGoal ml', style: textTheme.headlineSmall),
          Slider(
            value: _waterGoal.toDouble(),
            min: 1000,
            max: 4000,
            divisions: 30, // шаг 100 мл
            label: '$_waterGoal ml',
            onChanged: (v) => setState(() => _waterGoal = v.round()),
          ),
          Text(
            context.s('onboarding.norms_adjust_hint'),
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
