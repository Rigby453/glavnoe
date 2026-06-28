// Экран «Мои данные» — единая точка редактирования всех персональных данных:
// тело (вес/рост/возраст/пол/активность), цель питания, вода, макросы КБЖУ,
// пищевые предпочтения, профиль здоровья и расписание сна.
//
// Переименован из EditGoalsScreen (было /profile/edit-goals →
// теперь /profile/my-data). Класс: MyDataScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/settings/food_preferences_provider.dart';
import '../../core/settings/nutrition_targets.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import 'widgets/food_preferences_section.dart';
import 'widgets/health_profile_section.dart';
import 'widgets/macro_editor.dart';

class MyDataScreen extends ConsumerStatefulWidget {
  const MyDataScreen({super.key});

  @override
  ConsumerState<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends ConsumerState<MyDataScreen> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _ageCtrl;

  late String _sex;      // 'male'|'female'|'other'
  late String _activity; // 'low'|'medium'|'high'
  late String _goal;     // 'maintain'|'lose'|'gain'
  late int _waterGoal;

  // Live-превью норм КБЖУ из текущих (ещё не сохранённых) полей экрана.
  // Передаётся в MacroEditor, чтобы калории/макросы реагировали мгновенно,
  // как норма воды (пересчитывается в _recalc).
  NutritionTargets _macroPreview = NutritionTargets.fallback;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);

    final weightVal = prefs.getDouble(kUserWeightKgKey);
    final heightVal = prefs.getInt(kUserHeightCmKey);
    final ageVal = prefs.getInt(kUserAgeKey);

    _weightCtrl = TextEditingController(
      text: weightVal != null && weightVal > 0
          ? weightVal == weightVal.floorToDouble()
              ? weightVal.toInt().toString()
              : weightVal.toString()
          : '',
    );
    _heightCtrl = TextEditingController(
      text: heightVal != null && heightVal > 0 ? '$heightVal' : '',
    );
    _ageCtrl = TextEditingController(
      text: ageVal != null && ageVal > 0 ? '$ageVal' : '',
    );

    _sex = prefs.getString(kUserSexKey) ?? 'other';
    _activity = prefs.getString(kUserActivityKey) ?? 'medium';
    _goal = prefs.getString(kFoodGoalKey) ?? 'maintain';
    _waterGoal = ref.read(waterGoalProvider);

    _weightCtrl.addListener(_recalc);
    _heightCtrl.addListener(_recalc);
    _ageCtrl.addListener(_recalc);

    _recalc();
  }

  @override
  void dispose() {
    _weightCtrl.removeListener(_recalc);
    _heightCtrl.removeListener(_recalc);
    _ageCtrl.removeListener(_recalc);
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Пересчёт live-норм воды и КБЖУ из текущих полей (до Save)
  // ---------------------------------------------------------------------------

  void _recalc() {
    final weight = double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'));
    final height = double.tryParse(_heightCtrl.text.trim());
    final age = int.tryParse(_ageCtrl.text.trim());

    // Норма воды (нужен только корректный вес).
    final int? recommendedWater = (weight != null && weight > 0)
        ? recommendedWaterMl(
            weightKg: weight,
            activity: _activity,
            heightCm: height,
            age: age,
          )
        : null;

    // Превью КБЖУ — повторяем логику nutritionTargetsProvider: если антропометрия
    // неполна, отдаём fallback; иначе считаем по той же чистой функции, что и при
    // Save, поэтому превью совпадает с тем, что сохранится.
    final NutritionTargets macroPreview = (weight != null &&
            weight > 0 &&
            height != null &&
            height > 0 &&
            age != null &&
            age > 0)
        ? computeNutritionTargets(
            weightKg: weight,
            heightCm: height,
            age: age,
            sex: _sex,
            activity: _activity,
            goal: _goal,
          )
        : NutritionTargets.fallback;

    setState(() {
      if (recommendedWater != null) _waterGoal = recommendedWater;
      _macroPreview = macroPreview;
    });
  }

  // ---------------------------------------------------------------------------
  // Сохранение основных данных тела + воды
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);

    final weight = double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'));
    final height = int.tryParse(_heightCtrl.text.trim());
    final age = int.tryParse(_ageCtrl.text.trim());

    if (weight != null && weight > 0) {
      await prefs.setDouble(kUserWeightKgKey, weight);
    }
    if (height != null && height > 0) {
      await prefs.setInt(kUserHeightCmKey, height);
    }
    if (age != null && age > 0) {
      await prefs.setInt(kUserAgeKey, age);
    }
    await prefs.setString(kUserSexKey, _sex);
    await prefs.setString(kUserActivityKey, _activity);

    // Цель питания — пишем в ключ nutritionTargetsProvider + FoodPreferences
    await prefs.setString(kFoodGoalKey, _goal);
    final fp = ref.read(foodPreferencesProvider);
    await ref.read(foodPreferencesProvider.notifier).save(fp.copyWith(goal: _goal));

    // Норма воды
    await ref.read(waterGoalProvider.notifier).set(_waterGoal);

    // Invalidate nutritionTargetsProvider — провайдер пересчитает нормы
    ref.invalidate(nutritionTargetsProvider);

    if (!mounted) return;

    // Остаёмся на экране: пользователь может продолжить править нижние блоки
    // (Макросы, Пищевые привычки, Профиль здоровья) в один заход. Закрытие —
    // кнопкой «назад». Снэкбар подтверждает сохранение.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.s('edit_goals.saved_snack'))),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('profile.my_data')),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================================================================
            // Секция: Параметры тела
            // ================================================================
            Text(
              context.s('edit_goals.body_params'),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // ---- Возраст ----
            Text(
              context.s('onboarding.norms_age'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            _AgeField(controller: _ageCtrl),
            const SizedBox(height: 20),

            // ---- Пол ----
            Text(
              context.s('onboarding.norms_sex'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ('male', context.s('onboarding.sex_male')),
                ('female', context.s('onboarding.sex_female')),
                ('other', context.s('onboarding.sex_other')),
              ].map((pair) {
                final (val, label) = pair;
                return ChoiceChip(
                  label: Text(label),
                  selected: _sex == val,
                  onSelected: (_) => setState(() {
                    _sex = val;
                    _recalc();
                  }),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ---- Рост и вес ----
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
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
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: context.s('onboarding.norms_height'),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ---- Активность ----
            Text(
              context.s('onboarding.norms_activity'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            _ActivityChips(
              selected: _activity,
              onChanged: (val) => setState(() {
                _activity = val;
                _recalc();
              }),
            ),

            const SizedBox(height: 24),

            // ================================================================
            // Секция: Цель питания
            // ================================================================
            Text(
              context.s('food_prefs.goal_label'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'lose',
                  label: Text(
                    context.s('food_prefs.goal_lose'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                ButtonSegment(
                  value: 'maintain',
                  label: Text(
                    context.s('food_prefs.goal_maintain'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                ButtonSegment(
                  value: 'gain',
                  label: Text(
                    context.s('food_prefs.goal_gain'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
              selected: {_goal},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _goal = s.first;
                _recalc();
              }),
            ),

            const SizedBox(height: 24),

            // ================================================================
            // Секция: Норма воды
            // ================================================================
            Text(
              context.s('edit_goals.water_goal_label'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(PhosphorIcons.drop(PhosphorIconsStyle.fill), size: 18, color: ext.success),
                const SizedBox(width: 6),
                Text(
                  '$_waterGoal ml',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ext.success,
                  ),
                ),
              ],
            ),
            Slider(
              value: _waterGoal.toDouble(),
              min: 1000,
              max: 3000,
              divisions: 20,
              label: '$_waterGoal ml',
              onChanged: (v) => setState(() => _waterGoal = v.round()),
            ),
            Text(
              context.s('onboarding.norms_adjust_hint'),
              style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
            ),

            const SizedBox(height: 28),

            // ---- Кнопка сохранения основных данных ----
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _save,
                child: Text(context.s('edit_goals.save_btn')),
              ),
            ),

            // ================================================================
            // Секция: Макросы КБЖУ (MacroEditor)
            // ================================================================
            const SizedBox(height: 32),
            Divider(color: ext.border, height: 1, thickness: 0.5),
            const SizedBox(height: 20),
            MacroEditor(previewTargets: _macroPreview),

            // ================================================================
            // Секция: Пищевые предпочтения
            // ================================================================
            const SizedBox(height: 32),
            Divider(color: ext.border, height: 1, thickness: 0.5),
            const SizedBox(height: 20),
            const FoodPreferencesSection(),

            // ================================================================
            // Секция: Профиль здоровья + Расписание сна
            // ================================================================
            const SizedBox(height: 32),
            Divider(color: ext.border, height: 1, thickness: 0.5),
            const SizedBox(height: 20),
            const HealthProfileSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вспомогательные виджеты
// ---------------------------------------------------------------------------

/// Поле ввода возраста (только цифры).
class _AgeField extends StatelessWidget {
  const _AgeField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: context.s('onboarding.norms_age'),
      ),
      textInputAction: TextInputAction.next,
    );
  }
}

/// Чипы выбора уровня активности (three-way choice).
class _ActivityChips extends StatelessWidget {
  const _ActivityChips({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        'low',
        context.s('onboarding_quiz.activity_low_label'),
        context.s('onboarding_quiz.activity_low_sub'),
      ),
      (
        'medium',
        context.s('onboarding_quiz.activity_medium_label'),
        context.s('onboarding_quiz.activity_medium_sub'),
      ),
      (
        'high',
        context.s('onboarding_quiz.activity_high_label'),
        context.s('onboarding_quiz.activity_high_sub'),
      ),
    ];

    return Column(
      children: options.map((opt) {
        final (val, label, subtitle) = opt;
        final isSelected = selected == val;
        final colorScheme = Theme.of(context).colorScheme;
        final ext = Theme.of(context).extension<FocusThemeExtension>()!;
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => onChanged(val),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : ext.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
                color: isSelected
                    ? colorScheme.primary.withAlpha(18)
                    : Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: ext.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                        : PhosphorIcons.circle(),
                    color: isSelected ? colorScheme.primary : ext.border,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
