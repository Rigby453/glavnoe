// Экран «Еда» (Health → Food, Phase 1, C5).
// Поиск продукта (Open Food Facts через бэкенд) / штрихкод / ИИ-фото (premium)
// → выбрать граммы/приём → запись. Итоги дня считаются локально из food_logs.
// Числа КБЖУ — из базы (на 100 г), масштабируются под порцию (food_nutrition).
//
// Kaname redesign (Phase 5):
//   • Карточки: surface1 + 0.5 hairline + R14, без теней
//   • Пустое состояние: KaiMascot(neutral, 64) + FilledButton
//   • Иконки: Phosphor (no Material icons in UI)
//   • Единицы g/kcal — через l10n ключи (food.row_grams_kcal, etc.)
//   • Баланс: нет left-fill-bar — статус через icon + цвет
//   • FAB лист: поиск + голос + штрихкод + ИИ-фото (premium) + из рецепта + недавние

import 'dart:async';
import 'dart:convert' show base64Encode;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/animations/ai_insight_reveal.dart';
import '../../core/animations/constants.dart';
import '../../core/animations/ai_pulse_dot.dart';
import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/nutrition_targets.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/utils/id.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import '../../features/mascot/kai_mascot.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';
import 'ai_menu_sheet.dart';
import 'barcode_scanner_screen.dart';
import 'food_balance.dart';
import 'food_icons.dart';
import 'food_nutrition.dart';
import 'meal_slots.dart';
import '../../core/settings/food_preferences_provider.dart';

// ---------------------------------------------------------------------------
// Вспомогательные таблицы для локализованных названий дней недели.
// DateTime.weekday: 1=Пн ... 7=Вс.
// ---------------------------------------------------------------------------

const _weekdayNamesEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _weekdayNamesRu = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
const _weekdayNamesDe = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];

/// Локализованное название дня недели (DateTime.weekday 1–7).
String _weekdayName(BuildContext context, int weekday) {
  final lang = Localizations.localeOf(context).languageCode;
  final idx = (weekday - 1).clamp(0, 6);
  return switch (lang) {
    'ru' => _weekdayNamesRu[idx],
    'de' => _weekdayNamesDe[idx],
    _ => _weekdayNamesEn[idx],
  };
}

/// «Повторить прошлую неделю»: копирует food_logs за тот же день недели 7 дней назад
/// в текущий/выбранный [targetDate] (по умолчанию — сегодня).
Future<void> _repeatLastWeek(
  BuildContext context,
  WidgetRef ref, {
  DateTime? targetDate,
}) async {
  final now = targetDate ?? DateTime.now();
  final sourceDate = now.subtract(const Duration(days: 7));

  final dao = ref.read(foodLogsDaoProvider);
  final sourceLogs = await dao.logsForDay(sourceDate);

  if (!context.mounted) return;

  if (sourceLogs.isEmpty) {
    final dayName = _weekdayName(context, sourceDate.weekday);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          context.s('food.repeat_week_empty').replaceFirst('{day}', dayName),
        ),
      ),
    );
    return;
  }

  final targetDayStart = DateTime.utc(now.year, now.month, now.day);
  final companions = sourceLogs.map((src) {
    final newId = uuidV4();
    return FoodLogsTableCompanion(
      id: Value(newId),
      date: Value(targetDayStart),
      meal: Value(src.meal),
      name: Value(src.name),
      grams: Value(src.grams),
      calories: Value(src.calories),
      protein: Value(src.protein),
      fat: Value(src.fat),
      carbs: Value(src.carbs),
      sugar: Value(src.sugar),
      fiber: Value(src.fiber),
      createdAt: Value(DateTime.now()),
    );
  }).toList();

  final insertedIds = await dao.addLogsAll(companions);

  if (!context.mounted) return;

  final dayName = _weekdayName(context, sourceDate.weekday);
  final n = insertedIds.length;
  showUndoSnackBar(
    context,
    message: context
        .s('food.repeat_week_done')
        .replaceFirst('{n}', '$n')
        .replaceFirst('{day}', dayName),
    onUndo: () => dao.deleteLogsById(insertedIds),
  );
}

/// Записи о еде за сегодня (реактивно).
final _todayFoodProvider =
    StreamProvider.autoDispose<List<FoodLogsTableData>>((ref) {
  return ref.watch(foodLogsDaoProvider).watchForDay(DateTime.now());
});

Nutrition _logToNutrition(FoodLogsTableData l) => Nutrition(
      calories: l.calories,
      protein: l.protein,
      fat: l.fat,
      carbs: l.carbs,
      sugar: l.sugar,
      fiber: l.fiber,
    );

class FoodScreen extends ConsumerStatefulWidget {
  const FoodScreen({super.key, this.targetMeal});

  /// Приём пищи, к которому надо доскроллить при открытии.
  final String? targetMeal;

  @override
  ConsumerState<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends ConsumerState<FoodScreen> {
  final Map<String, GlobalKey> _mealKeys = {};
  String? _highlightedMeal;
  bool _scrolledToTarget = false;

  GlobalKey _mealKey(String slot) =>
      _mealKeys.putIfAbsent(slot, () => GlobalKey());

  void _maybeScrollToTarget(List<FoodLogsTableData> logs) {
    if (_scrolledToTarget) return;
    final target = widget.targetMeal;
    if (target == null || logs.isEmpty) return;
    if (!logs.any((l) => l.meal == target)) return;
    _scrolledToTarget = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _mealKeys[target];
      final ctx = key?.currentContext;
      if (ctx == null) return;
      final reduce = reduceMotionOf(context);
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.05,
        duration: reduce ? Duration.zero : kDurationNormal,
        curve: kCurveSlide,
      );
      if (!reduce) {
        setState(() => _highlightedMeal = target);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _highlightedMeal = null);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(153);

    final logs = ref.watch(_todayFoodProvider).valueOrNull ??
        const <FoodLogsTableData>[];
    final totals = sumNutrition(logs.map(_logToNutrition));

    // Для пустого состояния — Kai
    final showKai = ref.watch(showKaiProvider);
    final tone = ref.watch(toneProvider);

    _maybeScrollToTarget(logs);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('health.food')),
        actions: [
          IconButton(
            tooltip: context.s('food.my_recipes_tooltip'),
            icon: Icon(PhosphorIcons.notebook()),
            onPressed: () => context.push('/recipes'),
          ),
          IconButton(
            tooltip: context.s('food.shopping_list_tooltip'),
            icon: Icon(PhosphorIcons.shoppingCart()),
            onPressed: () => context.push('/shopping'),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'food_add_fab',
        onPressed: () => _showSearchSheet(context),
        tooltip: context.s('food.add'),
        child: Icon(PhosphorIcons.plus()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
        children: [
          _TotalsCard(totals: totals),
          const SizedBox(height: 12),
          // Вторичные действия: «Собрать ИИ» и «Повторить прошлую неделю»
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                icon: Icon(PhosphorIcons.sparkle(), size: 18),
                label: Text(context.s('food.ai_menu_btn')),
                onPressed: () => showAiMenuSheet(context, ref),
              ),
              Tooltip(
                message: context.s('food.repeat_week_tooltip'),
                child: TextButton.icon(
                  icon: Icon(PhosphorIcons.clockCounterClockwise(), size: 18),
                  label: Text(context.s('food.repeat_week')),
                  onPressed: () => _repeatLastWeek(context, ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            // Пустое состояние: KaiMascot + текст + CTA-кнопка (§4.2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showKai) ...[
                      KaiMascot(
                        size: 64,
                        emotion: KaiEmotion.neutral,
                        isHarsh: tone == AppTone.harsh,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      context.s('food.nothing_today'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: Icon(PhosphorIcons.plus()),
                      label: Text(context.s('food.empty_add_food')),
                      onPressed: () => _showSearchSheet(context),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ..._buildMealSections(context, logs),
            const SizedBox(height: 24),
            _BalanceSectionHeader(),
            const SizedBox(height: 8),
            _BalanceCard(totals: totals),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String slot) => _MealSectionHeader(
        key: _mealKey(slot),
        slot: slot,
        highlighted: _highlightedMeal == slot,
      );

  List<Widget> _buildMealSections(
    BuildContext context,
    List<FoodLogsTableData> logs,
  ) {
    final grouped = <String, List<FoodLogsTableData>>{};
    final other = <FoodLogsTableData>[];
    for (final l in logs) {
      if (kMealSlotOrder.contains(l.meal)) {
        grouped.putIfAbsent(l.meal, () => []).add(l);
      } else {
        other.add(l);
      }
    }

    final sections = <Widget>[];
    for (final slot in kMealSlotOrder) {
      final group = grouped[slot];
      if (group == null || group.isEmpty) continue;
      sections.add(_sectionHeader(slot));
      sections.addAll(group.map((l) => _FoodRow(log: l)));
    }
    if (other.isNotEmpty) {
      sections.add(_sectionHeader('snack'));
      sections.addAll(other.map((l) => _FoodRow(log: l)));
    }
    return sections;
  }
}

// ---------------------------------------------------------------------------
// Заголовок секции приёма пищи
// ---------------------------------------------------------------------------

class _MealSectionHeader extends StatelessWidget {
  const _MealSectionHeader({
    required this.slot,
    this.highlighted = false,
    super.key,
  });
  final String slot;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ??
        Theme.of(context).colorScheme.onSurface.withAlpha(153);

    final label = context.s('food.meal_$slot');
    final display = label.isNotEmpty
        ? label[0].toUpperCase() + label.substring(1)
        : slot;

    final highlightColor = ext?.accentMuted ??
        Theme.of(context).colorScheme.primary.withAlpha(30);

    return AnimatedContainer(
      duration: kDurationNormal,
      curve: kCurveSlide,
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? highlightColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        display,
        style: textTheme.titleSmall?.copyWith(color: mutedColor),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Заголовок секции «Баланс рациона» — Phosphor chartLineUp вместо insights
// ---------------------------------------------------------------------------

class _BalanceSectionHeader extends StatelessWidget {
  const _BalanceSectionHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor =
        ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(153);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(PhosphorIcons.chartLineUp(), size: 16, color: mutedColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.s('food.balance_section_header'),
              style: textTheme.titleSmall?.copyWith(color: mutedColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка «Баланс рациона» — surface1 + hairline + R14, нет left fill-bar
// ---------------------------------------------------------------------------

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.totals});
  final Nutrition totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final successColor = ext?.success ?? colorScheme.primary;
    final mutedColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(153);

    final targets = ref.watch(nutritionTargetsProvider);
    final balance = evaluateDayBalance(
      totals,
      calorieGoal: targets.kcal,
      proteinGoalG: targets.proteinG,
    );

    final daySeed =
        DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

    // §4 card: surface1 + 0.5 hairline + R14, NO shadow, NO left fill-bar
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ext?.border ?? colorScheme.outline,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  balance.balanced
                      ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                      : PhosphorIcons.lightbulb(),
                  size: 20,
                  // Сбалансировано → success; совет → нейтральный мутед
                  color: balance.balanced ? successColor : mutedColor,
                ),
                const SizedBox(width: 8),
                Text(context.s('food.balance_title'), style: textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            if (balance.balanced)
              Text(
                context.s(resolveBalanceOkKey(daySeed)),
                style: textTheme.bodyMedium,
              )
            else
              ...balance.hints.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('· ', style: textTheme.bodyMedium?.copyWith(color: mutedColor)),
                      Expanded(
                        child: Text(
                          context.s(resolveHintKey(e.value, daySeed + e.key)),
                          style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка «Итоги дня» — surface1 + hairline + R14, акцент = калории
// ---------------------------------------------------------------------------

class _TotalsCard extends ConsumerWidget {
  const _TotalsCard({required this.totals});
  final Nutrition totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(153);
    final emberColor = ext?.ember ?? colorScheme.secondary;

    final targets = ref.watch(nutritionTargetsProvider);

    String g(double? v) => v == null ? '—' : v.round().toString();

    // §4 card: surface1 + 0.5 hairline + R14, NO shadow
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ext?.border ?? colorScheme.outline,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.s('food.totals_today'), style: textTheme.titleSmall),
            const SizedBox(height: 12),
            // Калории — единственный акцентный элемент карточки
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  g(totals.calories),
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    context
                        .s('food.totals_kcal_goal')
                        .replaceFirst('{goal}', '${targets.kcal}'),
                    style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Б/Ж/У — вторичные, равные колонки, значения через l10n
            Row(
              children: [
                Expanded(
                  child: _Macro(
                    label: context.s('food.macro_protein'),
                    value: context
                        .s('food.macro_value_of')
                        .replaceFirst('{val}', g(totals.protein))
                        .replaceFirst('{goal}', '${targets.proteinG}'),
                    color: mutedColor,
                  ),
                ),
                Expanded(
                  child: _Macro(
                    label: context.s('food.macro_fat'),
                    value: context
                        .s('food.macro_value_of')
                        .replaceFirst('{val}', g(totals.fat))
                        .replaceFirst('{goal}', '${targets.fatG}'),
                    color: mutedColor,
                  ),
                ),
                Expanded(
                  child: _Macro(
                    label: context.s('food.macro_carbs'),
                    value: context
                        .s('food.macro_value_of')
                        .replaceFirst('{val}', g(totals.carbs))
                        .replaceFirst('{goal}', '${targets.carbsG}'),
                    color: mutedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Сахар (ember = «следи») + Клетчатка (мутед)
            // Phosphor warning → сахар; leaf → клетчатка
            Row(
              children: [
                Icon(PhosphorIcons.warning(), size: 16, color: emberColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    context
                        .s('food.totals_sugar_line')
                        .replaceFirst('{val}', g(totals.sugar))
                        .replaceFirst('{max}', '${targets.sugarMaxG}'),
                    style: textTheme.bodySmall?.copyWith(color: emberColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(PhosphorIcons.leaf(), size: 16, color: mutedColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    context
                        .s('food.totals_fiber_line')
                        .replaceFirst('{val}', g(totals.fiber))
                        .replaceFirst('{max}', '${targets.fiberG}'),
                    style: textTheme.bodySmall?.copyWith(color: mutedColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Строка продукта — surface1 + hairline + R14, dense row, Phosphor x
// ---------------------------------------------------------------------------

class _FoodRow extends ConsumerWidget {
  const _FoodRow({required this.log});
  final FoodLogsTableData log;

  Future<void> _deleteWithUndo(BuildContext context, WidgetRef ref) async {
    final dao = ref.read(foodLogsDaoProvider);
    final snapshot = log;
    await dao.deleteLog(log.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: '"${log.name}" ${context.s('food.log_removed')}',
      onUndo: () => dao.restoreLog(snapshot),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(153);

    // Подзаголовок: «{g} г · {kcal} ккал» через l10n, нет хардкода
    final String rowSubtitle;
    if (log.calories != null) {
      rowSubtitle = context
          .s('food.row_grams_kcal')
          .replaceFirst('{g}', '${log.grams.round()}')
          .replaceFirst('{kcal}', '${log.calories!.round()}');
    } else {
      rowSubtitle = context
          .s('food.grams_val')
          .replaceFirst('{val}', '${log.grams.round()}');
    }

    return SwipeToDelete(
      key: ValueKey('food_log_${log.id}'),
      onDelete: () => _deleteWithUndo(context, ref),
      // §4 card: surface1 + 0.5 hairline + R14, dense row (не ListTile)
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ext?.border ?? colorScheme.outline,
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              FoodIconTile(name: log.name, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.name,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rowSubtitle,
                      style: textTheme.bodySmall?.copyWith(color: mutedColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.s('food.remove_tooltip'),
                icon: Icon(
                  PhosphorIcons.x(),
                  size: 18,
                  color: ext?.textFaint,
                ),
                onPressed: () => _deleteWithUndo(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Поиск продукта (нижний лист) — unified add sheet per spec
// ---------------------------------------------------------------------------

Future<void> _showSearchSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => const _FoodSearchSheet(),
  );
}

/// [ТОЛЬКО ДЛЯ ТЕСТОВ] Открывает лист поиска с предустановленными результатами.
@visibleForTesting
Future<void> showFoodSearchSheetWithPreset(
  BuildContext context, {
  required List<Map<String, dynamic>> presetResults,
  String? presetAiNote,
}) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => _FoodSearchSheet(
      testResults: presetResults,
      testAiNote: presetAiNote,
    ),
  );
}

class _FoodSearchSheet extends ConsumerStatefulWidget {
  const _FoodSearchSheet({
    @visibleForTesting List<Map<String, dynamic>>? testResults,
    @visibleForTesting this.testAiNote,
  }) : testResults = testResults ?? const [];

  @visibleForTesting
  final List<Map<String, dynamic>> testResults;

  @visibleForTesting
  final String? testAiNote;

  @override
  ConsumerState<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

// ---------------------------------------------------------------------------
// Кэш поискового запроса
// ---------------------------------------------------------------------------

class _CacheEntry {
  _CacheEntry(this.results) : timestamp = DateTime.now();
  final List<Map<String, dynamic>> results;
  final DateTime timestamp;
}

const _kCacheTtl = Duration(minutes: 5);
const _kCacheMaxEntries = 20;

class _FoodSearchSheetState extends ConsumerState<_FoodSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  String? _aiNote;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;

  final Map<String, _CacheEntry> _searchCache = {};
  int _requestSeq = 0;

  List<FoodLogsTableData> _recentLogs = [];
  bool _recentLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.testResults.isNotEmpty) {
      _results = List.from(widget.testResults);
      _aiNote = widget.testAiNote;
    }
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final dao = ref.read(foodLogsDaoProvider);
    final logs = await dao.recentDistinctLogs(limit: 10);
    if (mounted) {
      setState(() {
        _recentLogs = logs;
        _recentLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    if (_listening) _speech.stop();
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _voiceSearch() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('food.speech_unavailable'))),
      );
      return;
    }
    final appLocale = ref.read(localeNotifierProvider);
    final localeId = switch (appLocale.languageCode) {
      'ru' => 'ru-RU',
      'de' => 'de-DE',
      _ => 'en-US',
    };

    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: localeId),
      onResult: (result) {
        if (!mounted) return;
        _controller.text = result.recognizedWords;
        if (result.finalResult) {
          setState(() => _listening = false);
          _search();
        }
      },
    );
  }

  /// Повторно залогировать недавний продукт одним тапом.
  Future<void> _relogRecent(FoodLogsTableData recent) async {
    final dao = ref.read(foodLogsDaoProvider);
    await dao.addLog(
      date: DateTime.now(),
      meal: recent.meal,
      name: recent.name,
      grams: recent.grams,
      calories: recent.calories,
      protein: recent.protein,
      fat: recent.fat,
      carbs: recent.carbs,
      sugar: recent.sugar,
      fiber: recent.fiber,
    );
    if (mounted) Navigator.of(context).pop();
  }

  String _normalizeQuery(String q) => q.trim().toLowerCase();

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    final key = _normalizeQuery(q);

    final cached = _searchCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _kCacheTtl) {
      if (!mounted) return;
      setState(() {
        _results = cached.results;
        _error = _results.isEmpty ? 'food.nothing_found' : null;
        _loading = false;
      });
      return;
    }

    final seq = ++_requestSeq;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref.read(apiClientProvider).foodSearch(q);
      if (!mounted || seq != _requestSeq) return;

      final results = raw.whereType<Map<String, dynamic>>().toList();

      if (_searchCache.length >= _kCacheMaxEntries) {
        _searchCache.remove(_searchCache.keys.first);
      }
      _searchCache[key] = _CacheEntry(results);

      setState(() {
        _results = results;
        if (_results.isEmpty) _error = 'food.nothing_found';
      });
    } on ApiException catch (e) {
      if (mounted && seq == _requestSeq) setState(() => _error = e.message);
    } finally {
      if (mounted && seq == _requestSeq) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(153);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок листа: title + ✕
            Row(
              children: [
                Expanded(
                  child: Text(context.s('food.add'), style: textTheme.headlineSmall),
                ),
                IconButton(
                  icon: Icon(PhosphorIcons.x()),
                  tooltip: context.s('btn.close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (value) {
                _debounce?.cancel();
                if (value.trim().isEmpty) {
                  setState(() {
                    _results = [];
                    _error = null;
                  });
                  return;
                }
                _debounce = Timer(const Duration(milliseconds: 400), _search);
              },
              decoration: InputDecoration(
                hintText: context.s('food.search_hint'),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Голос — active=fill, inactive=regular; активный → ember
                    IconButton(
                      tooltip: _listening
                          ? context.s('food.voice_stop')
                          : context.s('food.voice_input'),
                      icon: Icon(
                        _listening
                            ? PhosphorIcons.microphone(PhosphorIconsStyle.fill)
                            : PhosphorIcons.microphone(),
                        color: _listening
                            ? (ext?.ember ?? colorScheme.error)
                            : null,
                      ),
                      onPressed: _voiceSearch,
                    ),
                    // Штрихкод
                    IconButton(
                      tooltip: context.s('food.scan_barcode_tooltip'),
                      icon: Icon(PhosphorIcons.qrCode()),
                      onPressed: _scanBarcode,
                    ),
                    // Поиск
                    IconButton(
                      icon: Icon(PhosphorIcons.magnifyingGlass()),
                      onPressed: _search,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Вторичные действия: ИИ-фото (premium) + из рецепта
            Wrap(
              spacing: 4,
              children: [
                // ИИ-фото: KaiLoader-пульс во время загрузки
                TextButton.icon(
                  icon: _loading
                      ? const AiPulseDot(size: 10)
                      : Icon(PhosphorIcons.camera(), size: 18),
                  label: Text(context.s('food.ai_photo_btn')),
                  onPressed: _loading ? null : _aiPhoto,
                ),
                // Из рецепта: закрываем лист и переходим на /recipes
                TextButton.icon(
                  icon: Icon(PhosphorIcons.notebook(), size: 18),
                  label: Text(context.s('food.from_recipe_btn')),
                  onPressed: () async {
                    await Navigator.of(context).maybePop();
                    if (context.mounted) context.push('/recipes');
                  },
                ),
              ],
            ),
            // Подпись ИИ-распознавания фото
            if (_aiNote != null)
              AiInsightReveal(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _aiNote!,
                    style: textTheme.bodySmall?.copyWith(color: mutedColor),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            // Загрузка: KaiLoader вместо спиннера
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: KaiLoader(label: context.s('loading.kai_food')),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  context.s(_error!),
                  style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                ),
              )
            // Недавние продукты (пустой поиск, 1 тап = повтор)
            else if (_controller.text.trim().isEmpty &&
                _recentLoaded &&
                _results.isEmpty)
              _recentLogs.isEmpty
                  ? const SizedBox.shrink()
                  : Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              context.s('food.recent_title'),
                              style: textTheme.labelMedium
                                  ?.copyWith(color: mutedColor),
                            ),
                          ),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _recentLogs.length,
                              itemBuilder: (context, i) {
                                final r = _recentLogs[i];
                                // l10n: граммы + ккал без хардкода
                                final String recentSubtitle;
                                if (r.calories != null) {
                                  recentSubtitle = context
                                      .s('food.row_grams_kcal')
                                      .replaceFirst('{g}', '${r.grams.round()}')
                                      .replaceFirst('{kcal}', '${r.calories!.round()}');
                                } else {
                                  recentSubtitle = context
                                      .s('food.grams_val')
                                      .replaceFirst('{val}', '${r.grams.round()}');
                                }
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: FoodIconTile(name: r.name),
                                  title: Text(r.name),
                                  subtitle: Text(
                                    recentSubtitle,
                                    style: textTheme.bodySmall
                                        ?.copyWith(color: mutedColor),
                                  ),
                                  onTap: () => _relogRecent(r),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final p = _results[i];
                    final per = p['per_100g'] as Map<String, dynamic>?;
                    final kcal = (per?['calories'] as num?)?.round();
                    return ListTile(
                      leading: FoodIconTile(
                        name: p['name'] as String?,
                        category: p['category'] as String?,
                      ),
                      title: Text(
                        (p['name'] as String?) ?? context.s('food.unknown_product'),
                      ),
                      subtitle: Text(
                        [
                          if (p['brand'] != null) p['brand'] as String,
                          if (kcal != null)
                            context
                                .s('food.kcal_per_100g')
                                .replaceFirst('{kcal}', '$kcal'),
                        ].join(' · '),
                        style: textTheme.bodySmall?.copyWith(color: mutedColor),
                      ),
                      onTap: () => _addProduct(p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ИИ-фото еды (premium, AI-03).
  Future<void> _aiPhoto() async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.s('food.ai_photo_premium_msg')),
          action: SnackBarAction(
            label: context.s('food.upgrade_btn'),
            onPressed: () => context.push('/paywall'),
          ),
        ),
      );
      return;
    }

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        imageQuality: 75,
      );
    } catch (_) {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 75,
      );
    }
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final mediaType =
        picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    setState(() {
      _loading = true;
      _error = null;
      _aiNote = null;
    });
    try {
      final result = await ref.read(apiClientProvider).aiFoodRecognize(
            imageBase64: base64Encode(bytes),
            mediaType: mediaType,
          );
      if (!mounted) return;

      final dish = (result['dish'] as String?) ?? '';
      final confidence =
          ((result['confidence'] as num?) ?? 0).toDouble().clamp(0.0, 1.0);
      final products = ((result['products'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (products.isNotEmpty) {
        setState(() {
          _aiNote = context
              .s('food.ai_photo_match')
              .replaceFirst('{dish}', dish)
              .replaceFirst('{pct}', '${(confidence * 100).round()}');
          _results = products;
        });
      } else if (dish.isNotEmpty) {
        _controller.text = dish;
        setState(() => _aiNote = context
            .s('food.ai_photo_recognized')
            .replaceFirst('{dish}', dish)
            .replaceFirst('{pct}', '${(confidence * 100).round()}'));
        await _search();
      } else {
        setState(() => _error = 'food.ai_photo_fail');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Скан штрихкода.
  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final product = await ref.read(apiClientProvider).foodBarcode(code);
      if (!mounted) return;
      if (product == null) {
        setState(() => _error = 'food.barcode_not_found');
      } else {
        setState(() => _results = [product]);
        await _addProduct(product);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addProduct(Map<String, dynamic> product) async {
    final result = await showDialog<({double grams, String meal})>(
      context: context,
      builder: (_) => _PortionDialog(name: (product['name'] as String?) ?? ''),
    );
    if (result == null) return;

    final per = product['per_100g'] as Map<String, dynamic>?;
    double? d(String k) => (per?[k] as num?)?.toDouble();
    final per100g = Nutrition(
      calories: d('calories'),
      protein: d('protein'),
      fat: d('fat'),
      carbs: d('carbs'),
      sugar: d('sugar'),
      fiber: d('fiber'),
    );
    final scaled = scaleNutrition(per100g, result.grams);

    await ref.read(foodLogsDaoProvider).addLog(
          date: DateTime.now(),
          meal: result.meal,
          name: (product['name'] as String?) ?? 'Food',
          grams: result.grams,
          calories: scaled.calories,
          protein: scaled.protein,
          fat: scaled.fat,
          carbs: scaled.carbs,
          sugar: scaled.sugar,
          fiber: scaled.fiber,
        );
    if (mounted) Navigator.of(context).pop();
  }
}

// ---------------------------------------------------------------------------
// Диалог выбора граммов и приёма пищи
// ---------------------------------------------------------------------------

class _PortionDialog extends ConsumerStatefulWidget {
  const _PortionDialog({required this.name});
  final String name;
  @override
  ConsumerState<_PortionDialog> createState() => _PortionDialogState();
}

class _PortionDialogState extends ConsumerState<_PortionDialog> {
  final _grams = TextEditingController(text: '100');
  late final List<String> _meals;
  late String _meal;

  @override
  void initState() {
    super.initState();
    final mealsPerDay = ref.read(foodPreferencesProvider).mealsPerDay;
    _meals = mealsForCount(mealsPerDay);
    _meal = _meals.isNotEmpty ? _meals.first : 'breakfast';
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _grams,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.s('food.grams_label')),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _meals.map((m) {
              return ChoiceChip(
                label: Text(context.s('food.meal_$m')),
                selected: _meal == m,
                onSelected: (_) => setState(() => _meal = m),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.cancel')),
        ),
        // Единственный FilledButton — первичное действие (§4.3)
        FilledButton(
          onPressed: () {
            final grams = double.tryParse(_grams.text.trim());
            if (grams == null || grams <= 0) return;
            Navigator.of(context).pop((grams: grams, meal: _meal));
          },
          child: Text(context.s('btn.add')),
        ),
      ],
    );
  }
}
