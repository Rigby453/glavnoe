// Настройка после онбординга и входа (SPEC C1, единый поток):
// интересы → импорт расписания → время разборов → тон → тема → нормы.
// Каждый шаг можно пропустить; всё сохраняется в SharedPreferences/провайдеры.
// Флаг 'setup_done' держит пользователя на /setup через redirect роутера.
//
// Редизайн (design-kai): headlineSmall + bodyLarge на каждом шаге, 24dp поля,
// одна FilledButton-кнопка Continue/Start внизу, Back — OutlinedButton.
// Accent только в активных чипах, FilledButton и активных карточках-выборах.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/health_profile_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider, themeProvider
import '../../core/widgets/voice_text_field.dart';
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
  static const _pageCount = 7;

  // Локальное состояние шагов (сохраняется при Finish)
  final Set<String> _selectedInterests = {};
  int _morningHour = kMorningHour; // 8
  int _eveningHour = kEveningHour; // 20
  int _waterGoal = kDefaultWaterGoalMl;

  // Антропометрия — шаг «нормы»
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  String _activity = 'medium'; // 'low' | 'medium' | 'high'
  String _sex = 'other'; // 'male' | 'female' | 'other'

  // Профиль здоровья — шаг 7 (опциональный)
  final _allergiesController = TextEditingController();
  final _healingController = TextEditingController();
  final _deficienciesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _waterGoal = ref.read(waterGoalProvider);
    // Слушаем изменения полей — пересчитываем рекомендацию на лету.
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
    _allergiesController.dispose();
    _healingController.dispose();
    _deficienciesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Пересчитывает рекомендацию воды при изменении веса, роста, возраста или активности.
  /// Если поле веса пустое или невалидное — ничего не делаем.
  void _recalcWater() {
    final weightText = _weightController.text.trim();
    final weight = double.tryParse(weightText);
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

  Future<void> _finish() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(interestsKey, _selectedInterests.toList());
    await prefs.setInt(reviewMorningHourKey, _morningHour);
    await prefs.setInt(reviewEveningHourKey, _eveningHour);
    await ref.read(waterGoalProvider.notifier).set(_waterGoal);

    // Сохраняем антропометрию для расчёта норм питания и аналитики.
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

    // Сохраняем профиль здоровья (только если хоть одно поле непустое).
    final hp = HealthProfile(
      allergies: _allergiesController.text,
      healing: _healingController.text,
      deficiencies: _deficienciesController.text,
    );
    if (!hp.isEmpty) {
      await ref.read(healthProfileProvider.notifier).save(hp);
    }

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
        duration: effectiveDuration(context, kDurationFast),
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
        duration: effectiveDuration(context, kDurationFast),
        curve: kCurveSnap,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final isLast = _page == _pageCount - 1;
    final isFirst = _page == 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя строка: прогресс + «Skip all»
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                children: [
                  // Линейный прогресс (accent цвет, нейтральный трек)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (_page + 1) / _pageCount,
                        backgroundColor: ext.border,
                        color: colorScheme.primary,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_page + 1}/$_pageCount',
                    style: textTheme.labelMedium,
                  ),
                  const SizedBox(width: 4),
                  // Skip all — TextButton, минимальный вес
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      context.s('onboarding.skip_all'),
                      style: textTheme.labelLarge?.copyWith(
                        color: ext.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _interestsStep(textTheme, ext),
                  _importStep(textTheme, ext),
                  _reviewTimeStep(textTheme, ext),
                  _toneStep(textTheme),
                  _themeStep(textTheme, colorScheme),
                  _normsStep(textTheme, colorScheme, ext),
                  _healthProfileStep(textTheme, ext),
                ],
              ),
            ),

            // Нижние кнопки: Back (OutlinedButton icon) + Continue/Start (FilledButton)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Row(
                children: [
                  if (!isFirst) ...[
                    // Back — outlined icon-only, не перетягивает фокус
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
                  // Continue / Start — единственный FilledButton на экране
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

  /// Обёртка каждого шага: заголовок headlineSmall + bodyMedium + контент.
  Widget _step({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок шага: headlineSmall (display-font через тему)
          Text(title, style: textTheme.headlineSmall),
          const SizedBox(height: 10),
          // Описание шага: bodyLarge, textMuted для вторичности
          Text(
            subtitle,
            style: textTheme.bodyLarge?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }

  // --- Шаг 1: интересы ---
  Widget _interestsStep(TextTheme textTheme, FocusThemeExtension ext) {
    return _step(
      title: context.s('onboarding.interests_title'),
      subtitle: context.s('onboarding.interests_subtitle'),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
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
  Widget _importStep(TextTheme textTheme, FocusThemeExtension ext) {
    return _step(
      title: context.s('onboarding.import_title'),
      subtitle: context.s('onboarding.import_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.content_paste_go, size: 18),
            label: Text(context.s('onboarding.import_now')),
            onPressed: () => showImportSheet(context, day: DateTime.now()),
          ),
          const SizedBox(height: 12),
          Text(
            context.s('onboarding.import_premium_hint'),
            style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
          ),
        ],
      ),
    );
  }

  // --- Шаг 3: время разборов ---
  Widget _reviewTimeStep(TextTheme textTheme, FocusThemeExtension ext) {
    Future<void> pick(bool morning) async {
      final initial = TimeOfDay(
        hour: morning ? _morningHour : _eveningHour,
        minute: 0,
      );
      final picked = await showTimePicker(context: context, initialTime: initial);
      if (picked != null) {
        setState(() {
          if (morning) {
            _morningHour = picked.hour;
          } else {
            _eveningHour = picked.hour;
          }
        });
      }
    }

    // ListTile с OutlinedButton для выбора времени
    Widget tile(String label, int hour, bool morning) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: textTheme.bodyLarge),
          trailing: OutlinedButton(
            onPressed: () => pick(morning),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: textTheme.labelLarge,
            ),
          ),
        );

    return _step(
      title: context.s('onboarding.review_title'),
      subtitle: context.s('onboarding.review_subtitle'),
      child: Column(
        children: [
          tile(context.s('onboarding.review_morning'), _morningHour, true),
          const SizedBox(height: 8),
          tile(context.s('onboarding.review_evening'), _eveningHour, false),
        ],
      ),
    );
  }

  /// Карточка-выбор: accent-граница и иконка проверки только для активного.
  Widget _choiceTile({
    required bool selected,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // Accent только у выбранной карточки — дисциплина акцента
        side: BorderSide(
          color: selected ? colorScheme.primary : ext.border,
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title, style: textTheme.titleSmall),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              )
            : null,
        trailing: AnimatedSwitcher(
          duration: kDurationSnap,
          child: selected
              ? Icon(
                  Icons.check_circle_rounded,
                  key: const ValueKey('checked'),
                  color: colorScheme.primary,
                  size: 20,
                )
              : Icon(
                  Icons.circle_outlined,
                  key: const ValueKey('unchecked'),
                  color: ext.border,
                  size: 20,
                ),
        ),
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

  // --- Шаг 7: профиль здоровья (опциональный) ---
  // Три текстовых поля с диктовкой. Данные сохраняются в _finish.
  Widget _healthProfileStep(TextTheme textTheme, FocusThemeExtension ext) {
    return _step(
      title: context.s('health_profile.onboarding_title'),
      subtitle: context.s('health_profile.onboarding_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoiceTextField(
            controller: _allergiesController,
            labelText: context.s('health_profile.q_allergies'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          VoiceTextField(
            controller: _healingController,
            labelText: context.s('health_profile.q_healing'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          VoiceTextField(
            controller: _deficienciesController,
            labelText: context.s('health_profile.q_deficiencies'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          // Дисклеймер: не медицинская рекомендация
          Text(
            context.s('health_profile.disclaimer'),
            style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
          ),
        ],
      ),
    );
  }

  // --- Шаг 6: нормы ---
  // Поля вес и рост → расчёт нормы воды + слайдер для ручной корректировки.
  // Рост собирается для будущей аналитики, в формуле воды НЕ участвует.
  Widget _normsStep(
      TextTheme textTheme, ColorScheme colorScheme, FocusThemeExtension ext) {
    // Показываем рекомендацию, только если вес заполнен корректно
    final weightText = _weightController.text.trim();
    final weightVal = double.tryParse(weightText);
    final hasValidWeight = weightVal != null && weightVal > 0;

    final recommended = hasValidWeight
        ? recommendedWaterMl(
            weightKg: weightVal,
            activity: _activity,
            heightCm: double.tryParse(_heightController.text.trim()),
            age: int.tryParse(_ageController.text.trim()),
          )
        : null;

    return _step(
      title: context.s('onboarding.norms_title'),
      subtitle: context.s('onboarding.norms_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Поля антропометрии: вес + рост ---
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
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Возраст + пол ---
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: context.s('onboarding.norms_age'),
                  ),
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.s('onboarding.norms_sex'),
                      style: textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
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
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- Уровень активности ---
          Text(
            context.s('onboarding.norms_activity'),
            style: textTheme.labelMedium,
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 24),

          // --- Рекомендация (живая): success-цвет, не accent ---
          if (recommended != null) ...[
            Row(
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  size: 16,
                  color: ext.success,
                ),
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

          // --- Текущее значение + слайдер ---
          Text('$_waterGoal ml', style: textTheme.headlineSmall),
          const SizedBox(height: 4),
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
}
