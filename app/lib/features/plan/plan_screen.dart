// FL-PLAN: Экран Plan — переключатель День/Неделя/Месяц.
// - День: недельная полоса + таймлайн выбранного дня (исходное поведение).
// - Неделя: повестка из 7 дней.
// - Месяц: календарная сетка с точками на днях с задачами.
// AppBar даёт общая оболочка ScaffoldWithNavBar; здесь вложенный Scaffold
// нужен только ради FAB. Добавление задачи переиспользует showAddTaskSheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// intl также экспортирует TextDirection (Bidi) — прячем, чтобы _PlanViewSwitcher
// мог использовать flutter-овский TextDirection.ltr в TextPainter без коллизии.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';
import '../today/widgets/add_task_sheet.dart';
import '../today/widgets/ai_quick_add_sheet.dart';
import 'widgets/day_timeline.dart';
import 'widgets/expandable_week_calendar.dart';
import 'widgets/month_view.dart';
import 'widgets/pinned_exam_card.dart';
import 'widgets/plan_providers.dart';
import 'widgets/time_grid.dart';
import 'widgets/week_agenda.dart';
import 'widgets/week_strip.dart';
import 'widgets/year_view.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  /// Форматирует выбранную дату: «Today», «Yesterday», или «15 Jun».
  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (isSameDate(date, today)) return context.s('plan.today');
    if (isSameDate(date, yesterday)) return context.s('plan.yesterday');
    // Год показываем только если не текущий
    if (date.year == now.year) return DateFormat('d MMM').format(date);
    return DateFormat('d MMM y').format(date);
  }

  /// Открывает DatePicker и переключает выбранный день.
  Future<void> _pickDate(DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked != null && mounted) {
      ref.read(selectedDayProvider.notifier).state = dateOnly(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch — ВНЕ LayoutBuilder: callbacks LayoutBuilder не регистрируют
    // подписки Riverpod для пересборки (вызываются в layout-фазе, не в build-фазе).
    final selectedDay = ref.watch(selectedDayProvider);
    final view = ref.watch(planViewProvider);
    final layout = ref.watch(planLayoutProvider);

    // Единое главное действие «добавить» — крупный круглый «+» без подписи
    // (как на остальных экранах). heroTag различается для tablet/mobile-веток,
    // чтобы избежать Hero-коллизии при смене раскладки.
    final isTablet = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    // ИИ-квик-адд (Волна 6, этап 2) — вторичная кнопка над основным «+»:
    // accent-контур, без заливки, чтобы не спорить с primary FAB.
    Widget aiQuickAddFab(String heroTag) => FloatingActionButton.small(
          heroTag: heroTag,
          onPressed: () => showAiQuickAddSheet(context, ref, day: selectedDay),
          tooltip: context.s('today.ai_quick_add_tooltip'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.primary,
          elevation: 0,
          shape: StadiumBorder(
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.2,
            ),
          ),
          child: PhosphorIcon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill)),
        );

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: isTablet
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                aiQuickAddFab('plan_ai_quick_add_fab_tablet'),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'plan_add_fab_tablet',
                  onPressed: () => showAddTaskSheet(context, day: selectedDay),
                  tooltip: context.s('today.fab_add'),
                  // Тень для визуальной отдельности FAB от контента (тема: elevation=0)
                  elevation: 4,
                  focusElevation: 6,
                  hoverElevation: 6,
                  child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.regular)),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                aiQuickAddFab('plan_ai_quick_add_fab_mobile'),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'plan_add_fab_mobile',
                  onPressed: () => showAddTaskSheet(context, day: selectedDay),
                  tooltip: context.s('today.fab_add'),
                  child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.regular)),
                ),
              ],
            ),
      body: isTablet
          ? _buildTabletLayout(
              context,
              selectedDay,
              view,
              layout,
            )
          : _buildMobileLayout(
              context,
              selectedDay,
              view,
              layout,
            ),
    );
  }

  /// Mobile single-column layout (< 600px).
  Widget _buildMobileLayout(
    BuildContext context,
    DateTime selectedDay,
    PlanView view,
    PlanLayout layout,
  ) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? Theme.of(context).colorScheme.outline;

    return Column(
      children: [
        // Переключатель вида + раскладка + фильтр (B7: единственная точка
        // входа — иконка _FilterButton, текстовый запрос теперь живёт внутри
        // PlanFilterSheet, а не отдельным полем над недельной полосой (это
        // убирает и дублирующий drag-handle, и клавиатурный баг — см. B7).
        _buildToolbar(context, selectedDay, view, layout),
        // Тонкий разделитель (hairline 0.5dp, убираем лишнюю высоту)
        Divider(height: 0.5, thickness: 0.5, color: border),
        Expanded(
          child: _bodyContent(view, layout),
        ),
      ],
    );
  }

  /// Tablet 2-column layout (≥ 600px).
  /// Left column (flex 1): week strip + view toggle buttons.
  /// Right column (flex 2): day timeline / month calendar / week agenda.
  Widget _buildTabletLayout(
    BuildContext context,
    DateTime selectedDay,
    PlanView view,
    PlanLayout layout,
  ) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? Theme.of(context).colorScheme.outline;
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Полноширинная строка переключателя видов ---
        // Раньше SegmentedButton жил в узкой левой колонке (flex:1) и его
        // подписи ужимались FittedBox(scaleDown) в нечитаемую мелочь. Теперь он
        // занимает всю ширину контента, где 5 кнопок помещаются обычным кеглем
        // (labelLarge, без масштабирования). _PlanViewSwitcher адаптивен: при
        // нехватке ширины (узко + крупный textScale) переходит в компактный
        // _ViewDropdown, чтобы текст всегда оставался читаемым и без overflow.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Expanded(child: _PlanViewSwitcher(view: view)),
              // Тумблер раскладки (список ↔ сетка времени) — рядом с
              // переключателем (только Day/3 дня/Week; month/year — календарь).
              if (_supportsLayoutToggle(view)) ...[
                const SizedBox(width: 8),
                _LayoutToggleButton(layout: layout),
              ],
            ],
          ),
        ),
        Divider(height: 0.5, thickness: 0.5, color: border),
        // --- Две колонки под строкой переключателя ---
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Левая колонка: управление (дата, неделя, поиск) ---
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  // 24dp горизонтальный отступ (02-type-space.md §4.1)
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Выбор даты + Today
                      Row(
                        children: [
                          Builder(
                            builder: (ctx) {
                              final now = DateTime.now();
                              final today = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );
                              if (!isSameDate(selectedDay, today)) {
                                return TextButton(
                                  onPressed: () {
                                    ref
                                            .read(selectedDayProvider.notifier)
                                            .state =
                                        today;
                                  },
                                  child: Text(ctx.s('plan.today')),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          GestureDetector(
                            onTap: () => _pickDate(selectedDay),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatSelectedDate(selectedDay),
                                    // bodySmall для метаданных/дат (02-type-space §1)
                                    style: textTheme.bodySmall?.copyWith(
                                      color: textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    PhosphorIcons.caretDown(PhosphorIconsStyle.regular),
                                    size: 18,
                                    color: textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // WeekStrip на планшете в левой колонке.
                      // Для threeDay скрыта — заголовок сетки уже показывает 3 дня.
                      if (_showsWeekStrip(view)) const WeekStrip(),
                      const SizedBox(height: 12),
                      // Единая точка входа в фильтр (B7): бывшая отдельная
                      // иконка-воронка с полем поиска убрана — текстовый
                      // запрос теперь живёт ВНУТРИ PlanFilterSheet вместе с
                      // чипами приоритет/статус/тип (см. PlanFilterSheet
                      // ниже). Здесь остаётся только сама кнопка-фильтр с
                      // бейджем активных фильтров.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              context.s('plan.search_label'),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: textTheme.bodySmall?.copyWith(
                                color: textMuted,
                              ),
                            ),
                          ),
                          // Иконка фильтра (B6/B7)
                          const _FilterButton(),
                        ],
                      ),
                      // «Цели» и «Импорт» перенесены в постоянные действия
                      // AppBar (справа сверху) — одинаково во всех раскладках.
                    ],
                  ),
                ),
              ),
              // Вертикальный разделитель — hairline (02-type-space §4.3)
              VerticalDivider(width: 1, thickness: 0.5, color: border),
              // --- Правая колонка: содержимое ---
              Expanded(flex: 2, child: _bodyContentTablet(view, layout)),
            ],
          ),
        ),
      ],
    );
  }

  /// Строит панель инструментов в ОДНУ строку (для mobile).
  /// Слева направо: `[День ▾]` → дата (тап → DatePicker, Expanded с ellipsis)
  /// → «Today» (только если выбран не сегодня, справа рядом с иконками)
  /// → фильтр (B7: единственная точка входа, текст+чипы внутри
  /// PlanFilterSheet) → тумблер раскладки (Day/Week).
  /// «Today» находится СПРАВА (не между dropdown и датой) — использует пустое
  /// правое пространство и не сталкивается с текстом даты.
  /// Гарантированно влезает на 320px при textScale 1.3 за счёт Flexible/ellipsis
  /// на дате и компактных контролов вместо SegmentedButton.
  Widget _buildToolbar(
    BuildContext context,
    DateTime selectedDay,
    PlanView view,
    PlanLayout layout,
  ) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;
    final textTheme = Theme.of(context).textTheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = isSameDate(selectedDay, today);

    return Padding(
      // 16dp слева, компактно справа под иконки (02-type-space.md §4.1)
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      child: Row(
        children: [
          // --- Компактный выпадающий список вида: [День ▾] ---
          // Заменяет SegmentedButton из 3 кнопок (не влезает в один ряд).
          _ViewDropdown(view: view),
          // --- Дата: тап открывает DatePicker. Expanded забирает всё свободное
          // место (прижимая иконки вправо) и при нехватке ширины ужимает дату
          // с ellipsis вместо RenderFlex overflow. ---
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(selectedDay),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _formatSelectedDate(selectedDay),
                        // bodySmall для метаданных (02-type-space §1)
                        style: textTheme.bodySmall?.copyWith(color: textMuted),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                    Icon(
                      PhosphorIcons.caretDown(PhosphorIconsStyle.regular),
                      size: 16,
                      // нейтральный цвет для иконок тулбара (accent discipline)
                      color: textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // --- Кнопка «Today» справа — только когда выбран не сегодня.
          // Размещена правее даты, рядом с иконками, чтобы не сталкиваться
          // с текстом даты слева и использовать пустое правое пространство. ---
          if (!isToday)
            TextButton(
              onPressed: () {
                ref.read(selectedDayProvider.notifier).state = today;
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(context.s('plan.today')),
            ),
          // --- Иконка фильтра с бейджем активных фильтров (B6/B7).
          // Единственная точка входа: бывшая отдельная воронка-переключатель
          // текстового поиска убрана — текстовый запрос теперь живёт ВНУТРИ
          // PlanFilterSheet вместе с чипами (устраняет дублирующий
          // drag-handle и клавиатурный баг, когда поле поиска сдвигало
          // недельную полосу). ---
          const _FilterButton(),
          // --- Тумблер раскладки (список ↔ сетка времени) — Day/3 дня/Week.
          // Для month/year скрыт (всегда календарь). ---
          if (_supportsLayoutToggle(view)) _LayoutToggleButton(layout: layout),
          // «Цели» и «Импорт» перенесены в постоянные действия AppBar (справа
          // сверху) — одинаково во всех раскладках. Здесь overflow-меню больше
          // не нужно: иных пунктов в нём не было.
        ],
      ),
    );
  }

  /// Содержимое тела в mobile (с WeekStrip внутри для Day/Week).
  /// При [layout] == grid в режимах Day/Week показываем сетку времени
  /// (Google-Calendar-стиль) вместо списка; Month всегда календарь.
  /// Раскрывающийся календарь больше НЕ прячется при открытом поиске (B7):
  /// текстовый фильтр теперь живёт в PlanFilterSheet (модальный шит), а не в
  /// инлайн-поле над недельной полосой — клавиатура фильтра больше не может
  /// сдвинуть/сплющить полосу дней (Plan-search bug, CLAUDE.md §B).
  Widget _bodyContent(
    PlanView view,
    PlanLayout layout,
  ) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? Theme.of(context).colorScheme.outline;
    final isGrid = layout == PlanLayout.grid;

    switch (view) {
      case PlanView.year:
        return const YearView();
      case PlanView.month:
        return const MonthView();
      case PlanView.threeDay:
        // 3 дня: сетка (блочная) ИЛИ агенда-список (3 секции-дня). Полосу дней
        // недели не показываем — и сетка, и агенда сами озаглавливают дни.
        return Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            Expanded(
              child: isGrid ? const ThreeDayTimeGrid() : const ThreeDayAgenda(),
            ),
          ],
        );
      case PlanView.week:
        // LayoutBuilder даёт реальную высоту тела — ограничиваем раскрытый
        // календарь 55% этой высоты (Bug #2: 6-рядный месяц иначе выходит за
        // пределы Column и кидает RenderFlex overflow). Минимум 220px (~3 ряда).
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxCalH = constraints.maxHeight.isFinite
                ? (constraints.maxHeight * 0.55).clamp(220.0, double.infinity)
                : null;
            return Column(
              children: [
                // Раскрывающийся календарь — только для списочной раскладки.
                // В сетке (WeekTimeGrid) свой заголовок-ряд дней, иначе дни
                // недели дублировались бы (Task D).
                if (!isGrid)
                  ExpandableWeekCalendar(maxCalendarHeight: maxCalH),
                // Тонкий разделитель (02-type-space §4.3 hairline)
                Divider(height: 0.5, thickness: 0.5, color: border),
                // Закреплённая ember-карточка ближайшего экзамена/дедлайна
                const PinnedExamCard(),
                Expanded(
                    child: isGrid ? const WeekTimeGrid() : const WeekAgenda()),
              ],
            );
          },
        );
      case PlanView.day:
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxCalH = constraints.maxHeight.isFinite
                ? (constraints.maxHeight * 0.55).clamp(220.0, double.infinity)
                : null;
            return Column(
              children: [
                // Раскрывающийся календарь: потяни вниз — развернётся месяц.
                ExpandableWeekCalendar(maxCalendarHeight: maxCalH),
                Divider(height: 0.5, thickness: 0.5, color: border),
                // Закреплённая ember-карточка ближайшего экзамена/дедлайна
                const PinnedExamCard(),
                Expanded(
                    child: isGrid ? const DayTimeGrid() : const DayTimeline()),
              ],
            );
          },
        );
    }
  }

  /// Содержимое правой колонки на планшете (без WeekStrip — он в левой колонке).
  Widget _bodyContentTablet(PlanView view, PlanLayout layout) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? Theme.of(context).colorScheme.outline;
    final isGrid = layout == PlanLayout.grid;

    switch (view) {
      case PlanView.year:
        return const YearView();
      case PlanView.month:
        return const MonthView();
      case PlanView.threeDay:
        // 3 дня: сетка (блочная) ИЛИ агенда-список — как Day/Week.
        return Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            Expanded(
              child: isGrid ? const ThreeDayTimeGrid() : const ThreeDayAgenda(),
            ),
          ],
        );
      case PlanView.week:
        return Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            Expanded(child: isGrid ? const WeekTimeGrid() : const WeekAgenda()),
          ],
        );
      case PlanView.day:
        return Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            Expanded(child: isGrid ? const DayTimeGrid() : const DayTimeline()),
          ],
        );
    }
  }
}

/// Адаптивный переключатель видов День/3 дня/Неделя/Месяц/Год.
///
/// Когда ширины хватает на 5 сегментов обычным кеглем (labelLarge,
/// текущий textScale) — показывает читаемый [SegmentedButton] БЕЗ
/// FittedBox-сжатия (подписи single-line, на 2 строки не переносятся).
/// Когда ширины мало (узко + крупный textScale) — переходит в компактный
/// [_ViewDropdown] (текущий вид + ▾), чтобы текст оставался нормального
/// кегля и не возникал RenderFlex overflow.
class _PlanViewSwitcher extends ConsumerWidget {
  const _PlanViewSwitcher({required this.view});

  final PlanView view;

  /// Локализованные подписи всех видов в порядке отображения.
  List<String> _labels(BuildContext context) => [
    context.s('plan.view_day'),
    context.s('plan.view_3day'),
    context.s('plan.view_week'),
    context.s('plan.view_month'),
    context.s('plan.view_year'),
  ];

  /// Измеряет ширину текста при заданном стиле и масштабе (single-line).
  static double _measure(String text, TextStyle? style, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  /// Помещаются ли 5 сегментов читаемым кеглем в [available] пикселей.
  /// M3 SegmentedButton: горизонтальный паддинг = 16dp с каждой стороны = 32dp;
  /// плюс разделители и минимальные ограничения. Используем 40dp на сегмент
  /// (достаточно консервативно: реальные кнопки занимают 32dp padding + запас)
  /// и дополнительный запас 24dp на всю строку. При сомнении переходим в
  /// _ViewDropdown, но на планшете 800px+ 5 сегментов уверенно помещаются.
  bool _segmentsFit(BuildContext context, double available) {
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    const perSegmentPadding = 40.0;
    var needed = 0.0;
    for (final label in _labels(context)) {
      needed += _measure(label, style, scaler) + perSegmentPadding;
    }
    // +24dp запас гарантирует: при пограничной ширине выбираем Dropdown, не
    // SegmentedButton (иначе текст рендерится вертикально, Bug #1).
    return available >= needed + 24;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = _labels(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Если ширина не ограничена (редко) — считаем, что место есть.
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        if (!available.isFinite || _segmentsFit(context, available)) {
          return SegmentedButton<PlanView>(
            segments: [
              ButtonSegment(
                value: PlanView.day,
                label: Text(labels[0], maxLines: 1, softWrap: false,
                    overflow: TextOverflow.ellipsis),
              ),
              ButtonSegment(
                value: PlanView.threeDay,
                label: Text(labels[1], maxLines: 1, softWrap: false,
                    overflow: TextOverflow.ellipsis),
              ),
              ButtonSegment(
                value: PlanView.week,
                label: Text(labels[2], maxLines: 1, softWrap: false,
                    overflow: TextOverflow.ellipsis),
              ),
              ButtonSegment(
                value: PlanView.month,
                label: Text(labels[3], maxLines: 1, softWrap: false,
                    overflow: TextOverflow.ellipsis),
              ),
              ButtonSegment(
                value: PlanView.year,
                label: Text(labels[4], maxLines: 1, softWrap: false,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
            selected: {view},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                ref.read(planViewProvider.notifier).state = s.first,
          );
        }
        // Узко: компактный выпадающий список (нормальный кегль, без overflow).
        return Align(
          alignment: Alignment.centerLeft,
          child: _ViewDropdown(view: view),
        );
      },
    );
  }
}

/// Поддерживает ли вид тумблер раскладки список↔сетка. Day, threeDay и Week —
/// да (есть и список, и сетка); month/year — нет (они всегда календарь).
bool _supportsLayoutToggle(PlanView view) =>
    view == PlanView.day || view == PlanView.threeDay || view == PlanView.week;

/// Показывать ли полосу недели (WeekStrip/ExpandableWeekCalendar) для вида.
/// Для threeDay и month — нет (свой заголовок/календарь).
bool _showsWeekStrip(PlanView view) =>
    view == PlanView.day || view == PlanView.week;

/// Компактный выпадающий список вида: `[День ▾]`. Заменяет SegmentedButton
/// из трёх кнопок (не влезает в одну строку тулбара на узких экранах).
/// Показывает текущий вид + стрелку ▾; пункты — day/week/month.
class _ViewDropdown extends ConsumerWidget {
  const _ViewDropdown({required this.view});

  final PlanView view;

  String _label(BuildContext context, PlanView v) {
    switch (v) {
      case PlanView.day:
        return context.s('plan.view_day');
      case PlanView.threeDay:
        return context.s('plan.view_3day');
      case PlanView.week:
        return context.s('plan.view_week');
      case PlanView.month:
        return context.s('plan.view_month');
      case PlanView.year:
        return context.s('plan.view_year');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return PopupMenuButton<PlanView>(
      tooltip: context.s('plan.view_picker_tooltip'),
      initialValue: view,
      onSelected: (v) => ref.read(planViewProvider.notifier).state = v,
      itemBuilder: (ctx) => [
        for (final v in PlanView.values)
          PopupMenuItem(value: v, child: Text(_label(ctx, v))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(context, view),
              // single-line: даже длинные подписи («Неделя») не переносятся
              // на 2 строки в узком тулбаре (mobile, 320px / textScale 1.5).
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: textTheme.bodyMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(PhosphorIcons.caretDown(PhosphorIconsStyle.regular), size: 18, color: textMuted),
          ],
        ),
      ),
    );
  }
}

/// Компактный тумблер раскладки Day/Week: список ↔ сетка времени.
/// Нейтральный цвет (accent discipline), с тултипом. Персистирует выбор.
class _LayoutToggleButton extends ConsumerWidget {
  const _LayoutToggleButton({required this.layout});

  final PlanLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;
    final isGrid = layout == PlanLayout.grid;

    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        // Показываем иконку ЦЕЛЕВОЙ раскладки (на что переключимся).
        isGrid
            ? PhosphorIcons.listBullets(PhosphorIconsStyle.regular)
            : PhosphorIcons.squaresFour(PhosphorIconsStyle.regular),
        color: textMuted,
      ),
      tooltip: isGrid
          ? context.s('plan.layout_list_tooltip')
          : context.s('plan.layout_grid_tooltip'),
      onPressed: () => ref.read(planLayoutProvider.notifier).toggle(),
    );
  }
}

// ---------------------------------------------------------------------------
// B6 — Кнопка-фильтр с бейджем и фильтр-шит
// ---------------------------------------------------------------------------

/// Применяет переключение значения [value] в группе [field] фильтра [current].
/// [selected] — новое состояние чипа (true = добавить, false = убрать).
PlanFilters _applyFilterSet(
  PlanFilters current,
  String field,
  String value, {
  required bool selected,
}) {
  switch (field) {
    case 'priority':
      final s = Set<String>.from(current.priorities);
      selected ? s.add(value) : s.remove(value);
      return current.copyWith(priorities: s);
    case 'status':
      final s = Set<String>.from(current.statuses);
      selected ? s.add(value) : s.remove(value);
      return current.copyWith(statuses: s);
    default: // 'type'
      final s = Set<String>.from(current.types);
      selected ? s.add(value) : s.remove(value);
      return current.copyWith(types: s);
  }
}

/// Компактная иконка-фильтр с бейджем числа активных фильтров.
/// Нейтральный цвет без акцента в покое; primary + fill когда фильтры активны.
class _FilterButton extends ConsumerWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(planFiltersProvider);
    final active = filters.activeCount;
    final isActive = active > 0;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;
    final cs = Theme.of(context).colorScheme;

    return Badge(
      isLabelVisible: isActive,
      label: Text('$active'),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(
          isActive
              ? PhosphorIcons.funnelSimple(PhosphorIconsStyle.fill)
              : PhosphorIcons.funnelSimple(PhosphorIconsStyle.regular),
          color: isActive ? cs.primary : textMuted,
        ),
        tooltip: context.s('plan.filter_tooltip'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const PlanFilterSheet(),
        ),
      ),
    );
  }
}

/// Панель фильтров плана — чипы Приоритет / Статус / Тип.
/// Открывается через showModalBottomSheet из [_FilterButton].
/// Публичный класс (без ведущего _) — доступен для виджет-тестов.
class PlanFilterSheet extends ConsumerWidget {
  const PlanFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(planFiltersProvider);
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Цвет активного чипа: accentTint фон + accentInk текст (Kaname style).
    final chipSelectedBg = ext?.accentTint ?? cs.primaryContainer;
    final chipInk = ext?.accentInk ?? cs.onPrimaryContainer;

    // B7: начальный текст текстового фильтра — читаем ОДИН раз (ref.read, не
    // watch), чтобы ввод не пересобирал весь шит на каждую букву. Нужен,
    // когда шит открывается повторно, а planSearchQueryProvider уже хранит
    // активный запрос (иначе поле визуально казалось бы пустым, хотя
    // фильтрация по факту всё ещё применена).
    final initialQuery = ref.read(planSearchQueryProvider);

    // Строит FilterChip для одного значения в группе [field].
    Widget chip(String field, String value, String label) {
      final selected = switch (field) {
        'priority' => filters.priorities.contains(value),
        'status' => filters.statuses.contains(value),
        _ => filters.types.contains(value),
      };
      return FilterChip(
        label: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: tt.labelMedium?.copyWith(
            color: selected ? chipInk : null,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
        selected: selected,
        selectedColor: chipSelectedBg,
        checkmarkColor: chipInk,
        side: selected
            ? BorderSide(color: chipInk.withValues(alpha: 0.5), width: 1)
            : null,
        onSelected: (s) {
          final cur = ref.read(planFiltersProvider);
          ref.read(planFiltersProvider.notifier).state =
              _applyFilterSet(cur, field, value, selected: s);
        },
      );
    }

    // Заголовок секции фильтра (UPPERCASE labelSmall — Kaname style).
    Widget sectionLabel(String key) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            context.s(key).toUpperCase(),
            style: tt.labelSmall?.copyWith(
              color: ext?.textMuted ?? cs.onSurface,
              letterSpacing: 0.8,
            ),
          ),
        );

    return Padding(
      // Теперь ЕСТЬ текстовое поле (B7 merge) — нижний inset должен расти
      // вместе с клавиатурой, а не только с системным навбаром. Шит живёт в
      // SingleChildScrollView, поэтому клавиатура просто скроллит контент,
      // не вызывая overflow (keyboard rule, CLAUDE.md §B).
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ручной drag handle убран (Bug: «две ручки») — тему уже рисует
              // свою через bottomSheetTheme.showDragHandle (app_theme.dart),
              // дублировать её здесь не нужно.
              // B7: текстовый фильтр (было отдельное поле над недельной
              // полосой, переключаемое воронкой в тулбаре) — теперь ПЕРВЫЙ
              // элемент содержимого шита, единая точка входа вместе с чипами
              // ниже.
              _SearchField(
                initialText: initialQuery,
                onChanged: (v) =>
                    ref.read(planSearchQueryProvider.notifier).state = v,
              ),
              const SizedBox(height: 12),
              // Заголовок + кнопка «Сбросить»
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.s('plan.filter_title'),
                      style: tt.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!filters.isEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(planFiltersProvider.notifier).state =
                            const PlanFilters();
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(context.s('plan.filter_clear')),
                    ),
                ],
              ),
              // Приоритет
              sectionLabel('plan.filter_priority'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  chip('priority', 'main',
                      context.s('today.priority_main')),
                  chip('priority', 'high',
                      context.s('today.priority_high')),
                  chip('priority', 'medium',
                      context.s('today.priority_medium')),
                  chip('priority', 'low',
                      context.s('today.priority_low')),
                ],
              ),
              // Статус
              sectionLabel('plan.filter_status'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  chip('status', 'pending',
                      context.s('plan.filter_status_pending')),
                  chip('status', 'done',
                      context.s('plan.filter_status_done')),
                  chip('status', 'skipped',
                      context.s('plan.filter_status_skipped')),
                ],
              ),
              // Тип
              sectionLabel('plan.filter_type'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  chip('type', 'task', context.s('today.type_task')),
                  chip('type', 'event', context.s('today.type_event')),
                  chip('type', 'exam', context.s('today.type_exam')),
                  chip('type', 'deadline',
                      context.s('today.type_deadline')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Поле ввода поискового запроса с иконкой очистки. Живёт внутри
/// PlanFilterSheet (B7 merge) — единственный текстовый вход фильтра плана.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged, this.initialText = ''});

  final ValueChanged<String> onChanged;

  /// Начальный текст поля. Нужен при повторном открытии шита, когда в
  /// planSearchQueryProvider уже есть активный запрос — иначе поле выглядело
  /// бы пустым, хотя фильтрация по факту всё ещё применена (виджет создаётся
  /// заново при каждом showModalBottomSheet, локальный State не переживает
  /// закрытие шита).
  final String initialText;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Используем InputDecorationTheme из ThemeData — не переопределяем форму
    return TextField(
      controller: _controller,
      // autofocus: false — шит открывается по тапу на иконку, поле не должно
      // сразу выталкивать клавиатуру поверх чипов (B7: раньше funnel-тоггл
      // сразу фокусировал инлайн-поле над недельной полосой, отсюда и
      // клавиатурный баг).
      decoration: InputDecoration(
        hintText: context.s('plan.search_hint'),
        // Воронка (не лупа) — согласовано с иконкой кнопки-переключателя выше:
        // это фильтр текущего вида по тексту/#тегу/типу, не глобальный поиск.
        prefixIcon: Icon(
          PhosphorIcons.funnel(PhosphorIconsStyle.regular),
          size: 20,
        ),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  PhosphorIcons.x(PhosphorIconsStyle.regular),
                  size: 20,
                ),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              )
            : null,
        isDense: true,
      ),
      onChanged: (v) {
        setState(() {}); // обновляем suffixIcon
        widget.onChanged(v);
      },
    );
  }
}
