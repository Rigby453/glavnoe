// Экран «Еда» (Health → Food, Phase 1, C5).
// Поиск продукта (Open Food Facts через бэкенд) / штрихкод / ИИ-фото (premium)
// → выбрать граммы/приём → запись. Итоги дня считаются локально из food_logs.
// Числа КБЖУ — из базы (на 100 г), масштабируются под порцию (food_nutrition).

import 'dart:async';
import 'dart:convert' show base64Encode;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/animations/ai_insight_reveal.dart';
import '../../core/widgets/collapsing_fab.dart';
import '../../core/animations/ai_pulse_dot.dart';
import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/settings/nutrition_targets.dart';
import '../../core/utils/id.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
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
/// Каждая запись создаётся через addLog-совместимый путь (новый id, дата = today).
/// После успеха показывает Undo-snackbar; по Undo удаляет только эту партию.
Future<void> _repeatLastWeek(
  BuildContext context,
  WidgetRef ref, {
  DateTime? targetDate,
}) async {
  final now = targetDate ?? DateTime.now();
  // День-источник: тот же день недели 7 дней назад
  final sourceDate = now.subtract(const Duration(days: 7));

  final dao = ref.read(foodLogsDaoProvider);
  final sourceLogs = await dao.logsForDay(sourceDate);

  if (!context.mounted) return;

  if (sourceLogs.isEmpty) {
    // Мягкое сообщение — нет данных за тот день
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

  // Строим companions с новыми id и датой = сегодня
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
  // Показываем Undo-snackbar; по Undo — удаляем ровно эту партию
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

class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final logs = ref.watch(_todayFoodProvider).valueOrNull ??
        const <FoodLogsTableData>[];
    final totals = sumNutrition(logs.map(_logToNutrition));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('health.food')),
        actions: [
          IconButton(
            tooltip: context.s('food.my_recipes_tooltip'),
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/recipes'),
          ),
          IconButton(
            tooltip: context.s('food.shopping_list_tooltip'),
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => context.push('/shopping'),
          ),
        ],
      ),
      floatingActionButton: CollapsingFab(
        heroTag: 'food_add_fab',
        onPressed: () => _showSearchSheet(context),
        icon: const Icon(Icons.add),
        label: Text(context.s('food.add')),
      ),
      body: ListView(
        // 24dp экранный отступ по spec (02-type-space.md §4.1)
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
        children: [
          _TotalsCard(totals: totals),
          const SizedBox(height: 16),
          // Баланс рациона (SPEC C5, rule-based) — только если что-то съедено
          if (logs.isNotEmpty) ...[
            _BalanceCard(totals: totals),
            const SizedBox(height: 16),
          ],
          // «Собрать ИИ» (SPEC C5, premium): меню дня из рецептов и недавних
          // продуктов; числа пересчитывает код, пользователь подтверждает.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(context.s('food.ai_menu_btn')),
              onPressed: () => showAiMenuSheet(context, ref),
            ),
          ),
          // «Повторить прошлую неделю»: копирует рацион того же дня недели -7 дней.
          // Акцент не используется — вторичное действие (UX-LAYOUT §6.3).
          Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: context.s('food.repeat_week_tooltip'),
              child: TextButton.icon(
                icon: const Icon(Icons.history, size: 18),
                label: Text(context.s('food.repeat_week')),
                onPressed: () => _repeatLastWeek(context, ref),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  context.s('food.nothing_today'),
                  textAlign: TextAlign.center,
                  // Пустое состояние — bodyMedium из темы (цвет text по умолчанию)
                  style: textTheme.bodyMedium,
                ),
              ),
            )
          else
            ..._buildMealSections(context, logs),
        ],
      ),
    );
  }

  /// Группирует дневной лог по слотам приёмов пищи и рендерит секции в
  /// каноническом порядке (kMealSlotOrder). Пустые группы пропускаются.
  /// Записи с meal, которого нет в kMealSlotOrder, собираются в «прочее»
  /// и показываются в конце под лейблом food.meal_snack (ничего не теряем).
  List<Widget> _buildMealSections(
    BuildContext context,
    List<FoodLogsTableData> logs,
  ) {
    // Группируем сохраняя порядок вставки внутри каждой группы.
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
      sections.add(_MealSectionHeader(slot: slot));
      sections.addAll(group.map((l) => _FoodRow(log: l)));
    }
    // «Прочее» — записи с неизвестным/легаси-приёмом — в конец под «перекус».
    if (other.isNotEmpty) {
      sections.add(const _MealSectionHeader(slot: 'snack'));
      sections.addAll(other.map((l) => _FoodRow(log: l)));
    }
    return sections;
  }
}

/// Маленький заголовок-секция приёма пищи над группой записей.
/// Лейбл локализуется через `food.meal_<slot>`; первая буква — в верхний регистр.
class _MealSectionHeader extends StatelessWidget {
  const _MealSectionHeader({required this.slot});
  final String slot;

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

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
      child: Text(
        display,
        style: textTheme.titleSmall?.copyWith(color: mutedColor),
      ),
    );
  }
}

/// Карточка «Баланс рациона» — мягкий вердикт + конкретные подсказки (C5).
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.totals});
  final Nutrition totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    // success — из ThemeExtension (01-color.md)
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final successColor = ext?.success ?? Theme.of(context).colorScheme.primary;
    final mutedColor = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(153);

    // Персонализированные нормы из антропометрии (или дефолт, если не заполнено)
    final targets = ref.watch(nutritionTargetsProvider);
    final balance = evaluateDayBalance(
      totals,
      calorieGoal: targets.kcal,
      proteinGoalG: targets.proteinG,
    );

    // Сид дня: целые дни с эпохи. Стабилен в течение дня → текст не «прыгает»
    // при ребилдах, но меняется день ото дня. Локаль/таймзона не важны.
    final daySeed =
        DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  balance.balanced
                      ? Icons.check_circle_outline
                      : Icons.tips_and_updates_outlined,
                  size: 20,
                  // Сбалансировано → success (зелёный); совет → нейтральный мутед
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
              // hints содержат id категорий — выбираем вариант текста по daySeed.
              // Смещаем сид на индекс категории (i), чтобы разные категории не
              // упирались в один и тот же индекс массива.
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

// Карточка «Итоги дня» — применяет правило «акцент = дефицитный ресурс» (UX-LAYOUT §6.3):
// • Акцент (primary/лайм): только заголовочная цифра калорий.
// • Вторичные бары (Б/Ж/У): нейтральный textMuted, формат «X / target g».
// • Сахар: ember/urgent (семантика «следи»), формат «X / max g».
// • Клетчатка: нейтральный мутед, формат «X / goal g».
class _TotalsCard extends ConsumerWidget {
  const _TotalsCard({required this.totals});
  final Nutrition totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // textMuted — из ThemeExtension; fallback на onSurface.withAlpha
    final mutedColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(153);
    // ember — семантика «срочное/следи», используется для Сахара
    final emberColor = ext?.ember ?? colorScheme.secondary;

    // Персональные нормы для отображения «съедено / норма»
    final targets = ref.watch(nutritionTargetsProvider);

    String g(double? v) => v == null ? '—' : v.round().toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок карточки — titleSmall (чуть менее тяжёлый чем titleMedium)
            Text(context.s('food.totals_today'), style: textTheme.titleSmall),
            const SizedBox(height: 12),
            // Калории — единственная метрика с акцентом (лайм = «главное»).
            // headlineMedium (32sp, display font) из type scale.
            // Flexible на вторичном тексте — при scale 1.5× строка '/ 2000 kcal' усекается.
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
                    '/ ${targets.kcal} kcal',
                    style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Вторичные макросы (Б/Ж/У) — mutedColor: важны, но не «главная» метрика.
            // Expanded делит ширину поровну — не даёт overflow при крупном тексте (1.5×).
            Row(
              children: [
                Expanded(
                  child: _Macro(
                    label: context.s('food.macro_protein'),
                    value: '${g(totals.protein)} / ${targets.proteinG} g',
                    color: mutedColor,
                  ),
                ),
                Expanded(
                  child: _Macro(
                    label: context.s('food.macro_fat'),
                    value: '${g(totals.fat)} / ${targets.fatG} g',
                    color: mutedColor,
                  ),
                ),
                Expanded(
                  child: _Macro(
                    label: context.s('food.macro_carbs'),
                    value: '${g(totals.carbs)} / ${targets.carbsG} g',
                    color: mutedColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Следящие метрики: Сахар — ember (семантика «следи»), Клетчатка — мутед.
            // Wrap переносит метрики на новую строку при нехватке ширины (320px / 1.5×).
            // Flexible внутри каждой мини-Row — защита от overflow если обе не влезают в строку.
            Row(
              children: [
                Icon(Icons.cookie_outlined, size: 16, color: emberColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Sugar ${g(totals.sugar)} / ${targets.sugarMaxG} g',
                    style: textTheme.bodySmall?.copyWith(color: emberColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.grass_outlined, size: 16, color: mutedColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Fiber ${g(totals.fiber)} / ${targets.fiberG} g',
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
  // Цвет цифры и подписи — передаётся снаружи (мутед для вторичных макросов)
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        // titleSmall (14sp w600) — достаточно веса без конкуренции с headline калорий.
        // maxLines+ellipsis: в Expanded-ячейке при scale 1.5× длинные значения усекаются.
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

class _FoodRow extends ConsumerWidget {
  const _FoodRow({required this.log});
  final FoodLogsTableData log;

  /// Снапшот → удалить → показать Undo (единый паттерн безопасного удаления).
  Future<void> _deleteWithUndo(BuildContext context, WidgetRef ref) async {
    final dao = ref.read(foodLogsDaoProvider);
    // Снапшот строки до удаления — для восстановления через Undo
    final snapshot = log;
    await dao.deleteLog(log.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      // «"Банан" removed» — имя продукта + ключ food.log_removed
      message: '"${log.name}" ${context.s('food.log_removed')}',
      onUndo: () => dao.restoreLog(snapshot),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(153);
    final kcal = log.calories == null ? '—' : '${log.calories!.round()} kcal';

    // SwipeToDelete обёртка: свайп влево = удалить с Undo
    return SwipeToDelete(
      key: ValueKey('food_log_${log.id}'),
      onDelete: () => _deleteWithUndo(context, ref),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          // Название продукта — bodyLarge из темы (titleText style уже задан в ListTileTheme)
          title: Text(log.name),
          subtitle: Text(
            // Приём пищи показан в заголовке секции — здесь только граммы и ккал.
            '${log.grams.round()} g · $kcal',
            style: textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          trailing: IconButton(
            tooltip: context.s('food.remove_tooltip'),
            // Иконка удаления — нейтральный textFaint (не акцент, не ember)
            icon: Icon(
              Icons.close,
              size: 18,
              color: ext?.textFaint,
            ),
            // Кнопка-корзина: тот же снапшот-паттерн, что и свайп
            onPressed: () => _deleteWithUndo(context, ref),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Поиск продукта (нижний лист)
// ---------------------------------------------------------------------------

Future<void> _showSearchSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => const _FoodSearchSheet(),
  );
}

class _FoodSearchSheet extends ConsumerStatefulWidget {
  const _FoodSearchSheet();
  @override
  ConsumerState<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

// ---------------------------------------------------------------------------
// Кэш поискового запроса (в памяти, на время жизни листа).
// Ключ — нормализованный запрос (trim+lowercase).
// Значение — результаты + метка времени для TTL.
// ---------------------------------------------------------------------------

class _CacheEntry {
  _CacheEntry(this.results) : timestamp = DateTime.now();
  final List<Map<String, dynamic>> results;
  final DateTime timestamp;
}

/// TTL кэша — 5 минут.
const _kCacheTtl = Duration(minutes: 5);

/// Максимум записей в кэше (по принципу LRU-приближения: при переполнении
/// удаляем первый вошедший ключ).
const _kCacheMaxEntries = 20;

class _FoodSearchSheetState extends ConsumerState<_FoodSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  // Подпись от ИИ-фото: «AI: greek salad (86%)» — показывается над результатами
  String? _aiNote;

  // Голосовой ввод (SPEC C5): локальное распознавание речи → строка поиска.
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;

  // --- Кэш поиска и защита от устаревших ответов ---
  final Map<String, _CacheEntry> _searchCache = {};

  /// Монотонно растущий счётчик запросов — чтобы игнорировать устаревшие ответы.
  int _requestSeq = 0;

  // --- Недавние продукты (Task 2) ---
  // Загружаются один раз при открытии листа; обновляются если нужно.
  List<FoodLogsTableData> _recentLogs = [];
  bool _recentLoaded = false;

  @override
  void initState() {
    super.initState();
    // Загружаем недавние продукты в фоне сразу при открытии листа
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
        // Распознавание закончилось само (пауза/таймаут) — гасим индикатор.
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
        SnackBar(
          content: Text(context.s('food.speech_unavailable')),
        ),
      );
      return;
    }
    // Привязка к языку приложения (а не системному), чтобы STT совпадал
    // с выбранным пользователем языком интерфейса.
    final appLocale = ref.read(localeNotifierProvider);
    final localeId = switch (appLocale.languageCode) {
      'ru' => 'ru-RU',
      'de' => 'de-DE',
      _ => 'en-US',
    };

    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
      ),
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

  /// Повторно залогировать недавний продукт одним тапом (Task 2).
  /// Берём те же граммы и приём что были в последней записи этого продукта.
  /// КБЖУ — из сохранённой записи, сеть не нужна.
  Future<void> _relogRecent(FoodLogsTableData recent) async {
    final dao = ref.read(foodLogsDaoProvider);
    // Определяем приём по текущему времени суток, если хочется;
    // но используем meal из записи — студент обычно ест в одно и то же время.
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

  /// Нормализованный запрос: без лишних пробелов, в нижнем регистре.
  String _normalizeQuery(String q) => q.trim().toLowerCase();

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    final key = _normalizeQuery(q);

    // --- Проверка кэша ---
    final cached = _searchCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _kCacheTtl) {
      // Попадание в кэш — мгновенный ответ, сеть не нужна.
      if (!mounted) return;
      setState(() {
        _results = cached.results;
        _error = _results.isEmpty ? 'food.nothing_found' : null;
        _loading = false;
      });
      return;
    }

    // --- Присваиваем токен этому запросу ---
    final seq = ++_requestSeq;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref.read(apiClientProvider).foodSearch(q);
      // Защита от устаревших ответов: если пришёл ответ на старый запрос — игнорируем.
      if (!mounted || seq != _requestSeq) return;

      final results = raw.whereType<Map<String, dynamic>>().toList();

      // --- Сохраняем в кэш ---
      if (_searchCache.length >= _kCacheMaxEntries) {
        // Удаляем самую старую запись (первый ключ в порядке вставки)
        _searchCache.remove(_searchCache.keys.first);
      }
      _searchCache[key] = _CacheEntry(results);

      setState(() {
        _results = results;
        // Сохраняем ключ локализации; резолвится в build через context.s()
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
          // 24dp экранный отступ (02-type-space.md §4.1)
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок листа — headlineSmall (22sp, display font)
            Text(context.s('food.add'), style: textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (value) {
                _debounce?.cancel();
                if (value.trim().isEmpty) {
                  // Запрос очищен — сбрасываем результаты, покажем «Недавнее»
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
                    IconButton(
                      tooltip: _listening
                          ? context.s('food.voice_stop')
                          : context.s('food.voice_input'),
                      icon: Icon(
                        _listening ? Icons.mic : Icons.mic_none,
                        // Активный микрофон — ember (urgent), не акцент
                        color: _listening
                            ? (ext?.ember ?? colorScheme.error)
                            : null,
                      ),
                      onPressed: _voiceSearch,
                    ),
                    IconButton(
                      tooltip: context.s('food.scan_barcode_tooltip'),
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanBarcode,
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ИИ-фото (premium): модель называет блюдо, КБЖУ — из базы
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                // Во время запроса AI — пульс вместо иконки (§7.1)
                icon: _loading
                    ? const AiPulseDot(size: 10)
                    : const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(context.s('food.ai_photo_btn')),
                onPressed: _loading ? null : _aiPhoto,
              ),
            ),
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
            // Загрузка: KaiLoader («Kai is finding food») вместо спиннера
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
                // _error может быть ключом локализации или сырым сообщением API
                child: Text(
                  context.s(_error!),
                  style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                ),
              )
            // Когда запрос пустой — показываем «Недавнее» (Task 2)
            else if (_controller.text.trim().isEmpty && _recentLoaded)
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
                                final kcal = r.calories == null
                                    ? null
                                    : '${r.calories!.round()} kcal';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: FoodIconTile(name: r.name),
                                  title: Text(r.name),
                                  subtitle: Text(
                                    [
                                      '${r.grams.round()} g',
                                      ?kcal,
                                    ].join(' · '),
                                    style: textTheme.bodySmall
                                        ?.copyWith(color: mutedColor),
                                  ),
                                  // 1 тап — залогировать повторно без ввода граммов
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
                      // Название продукта — titleSmall (из темы ListTile)
                      title: Text(
                        (p['name'] as String?) ?? context.s('food.unknown_product'),
                      ),
                      subtitle: Text(
                        [
                          if (p['brand'] != null) p['brand'] as String,
                          if (kcal != null) '$kcal kcal / 100g',
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

  /// ИИ-фото еды (premium, AI-03): снимок → /ai/food-recognize → модель
  /// называет блюдо, бэкенд подбирает продукты с КБЖУ из food DB.
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

    // Камера предпочтительнее для еды; на платформах без камеры — галерея.
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
          _aiNote = 'AI: $dish (${(confidence * 100).round()}%) — pick a match';
          _results = products;
        });
      } else if (dish.isNotEmpty) {
        // База не нашла соответствий — подставляем блюдо в поиск
        _controller.text = dish;
        setState(() =>
            _aiNote = 'AI: $dish (${(confidence * 100).round()}%)');
        await _search();
      } else {
        // Ключ локализации; резолвится в build через context.s()
        setState(() => _error = 'food.ai_photo_fail');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Скан штрихкода → /food/barcode → тот же диалог порции, что и поиск.
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
        setState(() => _error = 'Product not found for barcode $code');
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
    if (mounted) Navigator.of(context).pop(); // закрываем лист поиска
  }
}

/// Диалог выбора граммов и приёма пищи.
class _PortionDialog extends ConsumerStatefulWidget {
  const _PortionDialog({required this.name});
  final String name;
  @override
  ConsumerState<_PortionDialog> createState() => _PortionDialogState();
}

class _PortionDialogState extends ConsumerState<_PortionDialog> {
  final _grams = TextEditingController(text: '100');
  // Слоты приёмов пищи зависят от mealsPerDay (классическая схема).
  late final List<String> _meals;
  // По умолчанию — первый слот (обычно breakfast).
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
      // Без лишних рамок: elevation 0, CardTheme уже задан в теме
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
              // Локализуем название приёма пищи через ключ food.meal_*
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
        // Единственный FilledButton — первичное действие (03-components §2)
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
