// Секция «Пищевые предпочтения» — публичный виджет, извлечённый из profile_screen.
// Используется в MyDataScreen. Провайдер foodPreferencesProvider уже хранит данные,
// поэтому секция всегда предзаполнена.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/food_preferences_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/voice_text_field.dart';

// ---------------------------------------------------------------------------
// Пикер числа приёмов пищи
// ---------------------------------------------------------------------------

/// Пикер числа приёмов пищи в день: пресеты 1–6 + «другое» (ввод вручную).
class MealsPerDayPicker extends StatelessWidget {
  const MealsPerDayPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    const presets = [1, 2, 3, 4, 5, 6];
    final isCustom = !presets.contains(value);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...presets.map((n) {
          final selected = value == n;
          return ChoiceChip(
            label: Text('$n'),
            selected: selected,
            onSelected: (_) => onChanged(n),
          );
        }),
        ChoiceChip(
          label: Text(
            isCustom
                ? context.s('food_prefs.meals_custom_value').replaceAll('{n}', '$value')
                : context.s('food_prefs.meals_custom'),
            style: textTheme.bodySmall,
          ),
          selected: isCustom,
          onSelected: (_) async {
            final result = await showDialog<int>(
              context: context,
              builder: (_) => _MealsCustomDialog(initial: isCustom ? value : 7),
            );
            if (result != null && result >= 1) onChanged(result);
          },
          avatar: Icon(
            Icons.edit_outlined,
            size: 14,
            color: isCustom ? colorScheme.onPrimary : ext.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Диалог для ввода произвольного числа приёмов пищи.
class _MealsCustomDialog extends StatefulWidget {
  const _MealsCustomDialog({required this.initial});
  final int initial;

  @override
  State<_MealsCustomDialog> createState() => _MealsCustomDialogState();
}

class _MealsCustomDialogState extends State<_MealsCustomDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.initial}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.s('food_prefs.meals_custom_title')),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(
          labelText: context.s('food_prefs.meals_label'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.s('btn.cancel')),
        ),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(_ctrl.text.trim());
            if (v != null && v >= 1) Navigator.pop(context, v);
          },
          child: Text(context.s('btn.ok')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// FoodPreferencesSection — основной публичный виджет
// ---------------------------------------------------------------------------

/// Секция «Пищевые предпочтения» в профиле / экране «Мои данные».
/// Показывает диету/цель/приёмы пищи/лайки/дизлайки.
/// По нажатию «Изменить» раскрывает inline-редактор.
class FoodPreferencesSection extends ConsumerStatefulWidget {
  const FoodPreferencesSection({super.key});

  @override
  ConsumerState<FoodPreferencesSection> createState() =>
      _FoodPreferencesSectionState();
}

class _FoodPreferencesSectionState
    extends ConsumerState<FoodPreferencesSection> {
  bool _editing = false;

  late String _diet;
  late String _goal;
  late int _mealsPerDay;

  late final TextEditingController _dislikesCtrl;
  late final TextEditingController _likesCtrl;

  @override
  void initState() {
    super.initState();
    final fp = ref.read(foodPreferencesProvider);
    _diet = fp.diet;
    _goal = fp.goal;
    _mealsPerDay = fp.mealsPerDay;
    _dislikesCtrl = TextEditingController(text: fp.dislikes);
    _likesCtrl = TextEditingController(text: fp.likes);
  }

  @override
  void dispose() {
    _dislikesCtrl.dispose();
    _likesCtrl.dispose();
    super.dispose();
  }

  void _startEditing() {
    final fp = ref.read(foodPreferencesProvider);
    _diet = fp.diet;
    _goal = fp.goal;
    _mealsPerDay = fp.mealsPerDay;
    _dislikesCtrl.text = fp.dislikes;
    _likesCtrl.text = fp.likes;
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    await ref.read(foodPreferencesProvider.notifier).save(FoodPreferences(
          diet: _diet,
          goal: _goal,
          dislikes: _dislikesCtrl.text,
          likes: _likesCtrl.text,
          mealsPerDay: _mealsPerDay,
        ));
    if (!mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.s('food_prefs.saved_snack'))),
    );
  }

  /// Маппинг diet-ключей на локализованные метки.
  Map<String, String> _dietOptions(BuildContext context) => {
        'none': context.s('food_prefs.diet_none'),
        'vegetarian': context.s('food_prefs.diet_vegetarian'),
        'vegan': context.s('food_prefs.diet_vegan'),
        'pescatarian': context.s('food_prefs.diet_pescatarian'),
        'halal': context.s('food_prefs.diet_halal'),
        'kosher': context.s('food_prefs.diet_kosher'),
        'keto': context.s('food_prefs.diet_keto'),
        'other': context.s('food_prefs.diet_other'),
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final fp = ref.watch(foodPreferencesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции + кнопка редактирования
        Row(
          children: [
            Expanded(
              child: Text(
                context.s('food_prefs.section_title'),
                style: textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () {
                if (_editing) {
                  setState(() => _editing = false);
                } else {
                  _startEditing();
                }
              },
              child: Text(_editing
                  ? context.s('btn.cancel')
                  : context.s('food_prefs.edit_btn')),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.s('food_prefs.ai_note'),
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 12),

        if (_editing) ...[
          // ---- Диета ----
          Text(
            context.s('food_prefs.diet_label'),
            style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dietOptions(context).entries.map((e) {
              return ChoiceChip(
                label: Text(e.value),
                selected: _diet == e.key,
                onSelected: (_) => setState(() => _diet = e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ---- Цель ----
          // ПРИМЕЧАНИЕ: выбор цели (lose/maintain/gain) намеренно НЕ редактируется
          // здесь — он живёт в секции «Параметры тела» того же экрана (my_data_screen),
          // чтобы не было двух мест редактирования одного хранилища (kFoodGoalKey).
          // Поле `_goal` сохраняется без изменений (round-trip), значение задаётся выше.

          // ---- Приёмы пищи ----
          Text(
            context.s('food_prefs.meals_label'),
            style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 8),
          MealsPerDayPicker(
            value: _mealsPerDay,
            onChanged: (v) => setState(() => _mealsPerDay = v),
          ),
          const SizedBox(height: 16),

          // ---- Не нравится ----
          VoiceTextField(
            controller: _dislikesCtrl,
            labelText: context.s('food_prefs.dislikes_label'),
            hintText: context.s('food_prefs.dislikes_hint'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // ---- Нравится ----
          VoiceTextField(
            controller: _likesCtrl,
            labelText: context.s('food_prefs.likes_label'),
            hintText: context.s('food_prefs.likes_hint'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          FilledButton(
            onPressed: _save,
            child: Text(context.s('food_prefs.btn_save')),
          ),
        ] else ...[
          if (fp.isEmpty)
            Text(
              context.s('food_prefs.empty_hint'),
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
            )
          else
            _FoodPreferencesView(prefs: fp),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _FoodPreferencesView — режим просмотра
// ---------------------------------------------------------------------------

class _FoodPreferencesView extends StatelessWidget {
  const _FoodPreferencesView({required this.prefs});

  final FoodPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    Widget row(String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
              ),
            ),
            Expanded(
              child: Text(value, style: textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }

    String dietLabel() {
      final key = 'food_prefs.diet_${prefs.diet}';
      return context.s(key);
    }

    // Цель (goal) сюда не выводим: она показывается/редактируется в секции
    // «Параметры тела» (my_data_screen). Дубль убран, чтобы не путать.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prefs.diet != 'none') row(context.s('food_prefs.view_diet'), dietLabel()),
        row(context.s('food_prefs.view_meals'), '${prefs.mealsPerDay}'),
        if (prefs.dislikes.trim().isNotEmpty)
          row(context.s('food_prefs.view_dislikes'), prefs.dislikes),
        if (prefs.likes.trim().isNotEmpty)
          row(context.s('food_prefs.view_likes'), prefs.likes),
      ],
    );
  }
}
