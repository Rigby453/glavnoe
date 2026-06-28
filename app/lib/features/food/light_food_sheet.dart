// Лёгкая шторка приёма пищи (nutritionMode = off).
//
// Показывает, что добавлено в [mealSlot] за день [day] — БЕЗ КБЖУ/ккал/граммов в UI.
// Добавление: поиск по имени (API, только название в результатах) + 1-тап из недавнего.
// Ввод голосом не добавлен: speech_to_text встроен в полный экран, не вынесен в хелпер.
//
// При добавлении пишем: grams = 100.0, все поля КБЖУ = null.
// Запись попадает в дневник еды как обычный приём — тот же DAO, тот же стол.
//
// Навигация: вызывается из block_tool_router когда kind == BlockToolKind.foodLight.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import '../../services/api/api_client.dart';
import 'food_icons.dart';

// ---------------------------------------------------------------------------
// Провайдер: поток всех записей еды за конкретный день.
// Фильтрация по слоту (meal) — в build, не в провайдере.
// Ключ семейства нормализуется до полуночи UTC в showLightFoodSheet.
// ---------------------------------------------------------------------------
final _lightDayLogsProvider =
    StreamProvider.autoDispose.family<List<FoodLogsTableData>, DateTime>(
  (ref, day) => ref.watch(foodLogsDaoProvider).watchForDay(day),
);

// ---------------------------------------------------------------------------
// Публичный API
// ---------------------------------------------------------------------------

/// Показывает лёгкую шторку приёма пищи для [mealSlot] за [day].
///
/// [mealSlot] — канонический английский идентификатор слота (например 'breakfast').
/// [day] — любая DateTime, нормализуется внутри до полуночи UTC.
///
/// Используется из block_tool_router при nutritionMode = false.
Future<void> showLightFoodSheet(
  BuildContext context, {
  required String mealSlot,
  required DateTime day,
}) {
  // Нормализуем дату до начала дня UTC — это ключ провайдера и DAO.
  final normalizedDay = DateTime.utc(day.year, day.month, day.day);
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    builder: (_) => _LightFoodSheet(mealSlot: mealSlot, day: normalizedDay),
  );
}

// ---------------------------------------------------------------------------
// Виджет шторки
// ---------------------------------------------------------------------------

class _LightFoodSheet extends ConsumerStatefulWidget {
  const _LightFoodSheet({required this.mealSlot, required this.day});

  final String mealSlot;

  /// Нормализованная дата (полночь UTC), используется как ключ провайдера и DAO.
  final DateTime day;

  @override
  ConsumerState<_LightFoodSheet> createState() => _LightFoodSheetState();
}

class _LightFoodSheetState extends ConsumerState<_LightFoodSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;

  // Результаты поиска через API (только имена — числа никогда не показываем)
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  // true = поиск уже был выполнен (чтобы показать «Ничего не найдено»)
  bool _hasSearched = false;

  // Недавние уникальные продукты (кэш на время жизни шторки)
  List<FoodLogsTableData> _recentLogs = [];
  bool _recentLoaded = false;

  // Монотонный счётчик запросов — защита от устаревших ответов
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Загрузка недавних
  // ---------------------------------------------------------------------------

  Future<void> _loadRecent() async {
    final logs =
        await ref.read(foodLogsDaoProvider).recentDistinctLogs(limit: 8);
    if (mounted) {
      setState(() {
        _recentLogs = logs;
        _recentLoaded = true;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Поиск (API) — в результатах скрываем все числа, показываем только имя/бренд
  // ---------------------------------------------------------------------------

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _loading = false;
      });
      return;
    }

    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _hasSearched = true;
    });

    try {
      final raw = await ref.read(apiClientProvider).foodSearch(q);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        // Сохраняем весь объект продукта (КБЖУ нужны при возможном добавлении),
        // но в UI отображаем ТОЛЬКО name/brand — без per_100g.
        _results = raw.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (_) {
      // Оффлайн или ошибка API — тихо показываем пустой список
      if (mounted && seq == _requestSeq) {
        setState(() {
          _results = [];
          _loading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Добавление
  // ---------------------------------------------------------------------------

  /// Добавить продукт по имени. КБЖУ/граммы не сохраняем.
  /// grams = 100.0 — минимально необходимый дефолт (поле NOT NULL в схеме).
  Future<void> _addByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final dao = ref.read(foodLogsDaoProvider);
    await dao.addLog(
      date: widget.day,
      meal: widget.mealSlot,
      name: trimmed,
      grams: 100.0,
      // calories / protein / fat / carbs / sugar / fiber = null (по умолчанию)
    );

    if (!mounted) return;
    _controller.clear();
    setState(() {
      _results = [];
      _hasSearched = false;
    });
  }

  /// Быстрое добавление из недавних (1 тап).
  /// Имя берём из истории, числа не показываем и не копируем в UI.
  Future<void> _addRecent(FoodLogsTableData recent) async {
    final dao = ref.read(foodLogsDaoProvider);
    await dao.addLog(
      date: widget.day,
      meal: widget.mealSlot,
      name: recent.name,
      grams: 100.0,
      // КБЖУ не копируем: лёгкий режим не оперирует числами
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text('"${recent.name}" ${context.s('food.recent_log_added')}'),
      ),
    );
  }

  /// Удалить с возможностью Undo (паттерн проекта).
  Future<void> _deleteWithUndo(FoodLogsTableData log) async {
    final dao = ref.read(foodLogsDaoProvider);
    final snapshot = log;
    await dao.deleteLog(log.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: '"${log.name}" ${context.s('food.log_removed')}',
      onUndo: () => dao.restoreLog(snapshot),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor =
        ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(153);

    // Реактивный поток записей за день → фильтруем по слоту в build
    final allLogs = ref
        .watch(_lightDayLogsProvider(widget.day))
        .valueOrNull ??
        <FoodLogsTableData>[];
    final slotLogs =
        allLogs.where((l) => l.meal == widget.mealSlot).toList();

    // Локализованное название приёма пищи + первая буква в верхний регистр
    final rawLabel = context.s('food.meal_${widget.mealSlot}');
    final mealLabel = rawLabel.isNotEmpty
        ? rawLabel[0].toUpperCase() + rawLabel.substring(1)
        : widget.mealSlot;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          // Отступ снизу растёт вместе с клавиатурой (стандартный паттерн шторок)
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------------------
            // Заголовок: название приёма + крестик закрытия
            // ----------------------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: Text(
                    mealLabel,
                    style: textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(PhosphorIcons.x()),
                  tooltip: context.s('btn.close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ----------------------------------------------------------------
            // Текущие записи этого приёма за день
            // ----------------------------------------------------------------
            if (slotLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  context.s('food.light_empty'),
                  style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                ),
              )
            else
              // Ограничиваем высоту списка: при длинном логе не занимаем весь экран
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: slotLogs.length,
                  itemBuilder: (_, i) {
                    final log = slotLogs[i];
                    return SwipeToDelete(
                      key: ValueKey('light_log_${log.id}'),
                      onDelete: () => _deleteWithUndo(log),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        // Иконка-эмодзи продукта
                        leading: FoodIconTile(name: log.name),
                        // БЕЗ subtitle — никаких граммов / ккал / КБЖУ
                        title: Text(log.name, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          tooltip: context.s('food.remove_tooltip'),
                          icon: Icon(
                            PhosphorIcons.x(),
                            size: 18,
                            color: ext?.textFaint,
                          ),
                          onPressed: () => _deleteWithUndo(log),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ----------------------------------------------------------------
            // Недавние продукты — горизонтальный скролл ActionChip'ов (1 тап = добавить)
            // ----------------------------------------------------------------
            if (_recentLoaded && _recentLogs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.s('food.recent_title'),
                style: textTheme.labelMedium?.copyWith(color: mutedColor),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _recentLogs.map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        // Только имя — без граммов/ккал/КБЖУ
                        label: Text(
                          r.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        avatar: Icon(
                          PhosphorIcons.plus(),
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () => _addRecent(r),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // ----------------------------------------------------------------
            // Поле ввода: поиск по имени (API) + добавление напрямую
            // ----------------------------------------------------------------
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: _addByName,
              onChanged: (v) {
                _debounce?.cancel();
                if (v.trim().isEmpty) {
                  setState(() {
                    _results = [];
                    _hasSearched = false;
                    _loading = false;
                  });
                  return;
                }
                // Debounce 400 мс — как в полном экране еды
                _debounce =
                    Timer(const Duration(milliseconds: 400), _search);
              },
              decoration: InputDecoration(
                hintText: context.s('food.light_name_hint'),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Индикатор загрузки поиска (маленький, внутри поля)
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(PhosphorIcons.magnifyingGlass()),
                        onPressed: _search,
                      ),
                    // Добавить то, что введено в поле (без поиска)
                    IconButton(
                      icon: Icon(PhosphorIcons.plus()),
                      tooltip: context.s('btn.add'),
                      onPressed: () => _addByName(_controller.text),
                    ),
                  ],
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Результаты поиска — только имя + бренд, без КБЖУ/граммов/ккал
            // ----------------------------------------------------------------
            if (!_loading && _results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    // Только название; per_100g не используется в UI этого листа
                    final name = (p['name'] as String?) ??
                        context.s('food.unknown_product');
                    final brand = p['brand'] as String?;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: FoodIconTile(
                        name: p['name'] as String?,
                        category: p['category'] as String?,
                      ),
                      title: Text(name, overflow: TextOverflow.ellipsis),
                      // Subtitle: только бренд (если есть) — НЕ ккал, НЕ граммы
                      subtitle: brand != null
                          ? Text(
                              brand,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: mutedColor),
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => _addByName(name),
                    );
                  },
                ),
              )
            else if (_hasSearched && !_loading && _results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.s('food.nothing_found'),
                  style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
