// FL-PLAN: Экран Plan — переключатель День/Неделя/Месяц.
// - День: недельная полоса + таймлайн выбранного дня (исходное поведение).
// - Неделя: повестка из 7 дней.
// - Месяц: календарная сетка с точками на днях с задачами.
// AppBar даёт общая оболочка ScaffoldWithNavBar; здесь вложенный Scaffold
// нужен только ради FAB. Добавление задачи переиспользует showAddTaskSheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/settings/fab_position_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';
import '../today/widgets/add_task_sheet.dart';
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
    final searchVisible = ref.watch(planSearchVisibleProvider);
    final layout = ref.watch(planLayoutProvider);

    // Единое главное действие «добавить» — крупный круглый «+» без подписи
    // (как на остальных экранах). heroTag различается для tablet/mobile-веток,
    // чтобы избежать Hero-коллизии при смене раскладки.
    final isTablet = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final fabLocation = ref.watch(fabPositionProvider).fabLocation;
    return Scaffold(
      floatingActionButtonLocation: fabLocation,
      floatingActionButton: isTablet
          ? FloatingActionButton(
              heroTag: 'plan_add_fab_tablet',
              onPressed: () => showAddTaskSheet(context, day: selectedDay),
              tooltip: context.s('today.fab_add'),
              // Тень для визуальной отдельности FAB от контента (тема: elevation=0)
              elevation: 4,
              focusElevation: 6,
              hoverElevation: 6,
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              heroTag: 'plan_add_fab_mobile',
              onPressed: () => showAddTaskSheet(context, day: selectedDay),
              tooltip: context.s('today.fab_add'),
              child: const Icon(Icons.add),
            ),
      body: isTablet
          ? _buildTabletLayout(context, selectedDay, view, searchVisible, layout)
          : _buildMobileLayout(context, selectedDay, view, searchVisible, layout),
    );
  }

  /// Mobile single-column layout (< 600px).
  Widget _buildMobileLayout(
    BuildContext context,
    DateTime selectedDay,
    PlanView view,
    bool searchVisible,
    PlanLayout layout,
  ) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? Theme.of(context).colorScheme.outline;

    return Column(
      children: [
        // Переключатель вида + раскладка + поиск + импорт
        _buildToolbar(context, selectedDay, view, searchVisible, layout),
        // Строка поиска (разворачивается при searchVisible в режиме Day)
        if (view == PlanView.day && searchVisible)
          Padding(
            // 24dp горизонтальный отступ экрана (02-type-space.md §4.1)
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: _SearchField(
              onChanged: (v) =>
                  ref.read(planSearchQueryProvider.notifier).state = v,
            ),
          ),
        // Тонкий разделитель (hairline 0.5dp, убираем лишнюю высоту)
        Divider(height: 0.5, thickness: 0.5, color: border),
        Expanded(child: _bodyContent(view, layout, searchVisible: searchVisible)),
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
    bool searchVisible,
    PlanLayout layout,
  ) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? Theme.of(context).colorScheme.outline;
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Левая колонка: управление ---
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            // 24dp горизонтальный отступ (02-type-space.md §4.1)
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Переключатель вида — SegmentedButton (correct per 03-components §13)
                SegmentedButton<PlanView>(
                  segments: [
                    ButtonSegment(value: PlanView.day, label: Text(context.s('plan.view_day'))),
                    ButtonSegment(value: PlanView.threeDay, label: Text(context.s('plan.view_3day'))),
                    ButtonSegment(value: PlanView.week, label: Text(context.s('plan.view_week'))),
                    ButtonSegment(value: PlanView.month, label: Text(context.s('plan.view_month'))),
                    ButtonSegment(value: PlanView.year, label: Text(context.s('plan.view_year'))),
                  ],
                  selected: {view},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      ref.read(planViewProvider.notifier).state = s.first,
                ),
                // Тумблер раскладки (список ↔ сетка времени) — только Day/Week.
                // Для threeDay и month скрыт (они всегда сетка/календарь).
                if (_supportsLayoutToggle(view)) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _LayoutToggleButton(layout: layout),
                  ),
                ],
                const SizedBox(height: 16),
                // Выбор даты + Today
                Row(
                  children: [
                    Builder(builder: (ctx) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      if (!isSameDate(selectedDay, today)) {
                        return TextButton(
                          onPressed: () {
                            ref.read(selectedDayProvider.notifier).state =
                                today;
                          },
                          child: Text(ctx.s('plan.today')),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    GestureDetector(
                      onTap: () => _pickDate(selectedDay),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
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
                              Icons.arrow_drop_down,
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
                // Поиск (только в режиме Day)
                if (view == PlanView.day)
                  Row(
                    children: [
                      // Нейтральная иконка без акцента (accent discipline)
                      IconButton(
                        icon: Icon(
                          searchVisible
                              ? Icons.search_off
                              : Icons.search,
                          color: textMuted,
                        ),
                        tooltip: context.s('plan.search_tooltip'),
                        onPressed: () {
                          final notifier =
                              ref.read(planSearchVisibleProvider.notifier);
                          notifier.state = !notifier.state;
                          if (notifier.state == false) {
                            ref.read(planSearchQueryProvider.notifier).state =
                                '';
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.s('plan.search_label'),
                        style: textTheme.bodySmall?.copyWith(color: textMuted),
                      ),
                    ],
                  ),
                if (view == PlanView.day && searchVisible)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _SearchField(
                      onChanged: (v) =>
                          ref.read(planSearchQueryProvider.notifier).state = v,
                    ),
                  ),
                // «Цели» и «Импорт» перенесены в постоянные действия AppBar
                // (справа сверху) — одинаково во всех раскладках, чтобы они не
                // «скакали» между мобайл-меню и этой колонкой.
              ],
            ),
          ),
        ),
        // Вертикальный разделитель — hairline (02-type-space §4.3)
        VerticalDivider(width: 1, thickness: 0.5, color: border),
        // --- Правая колонка: содержимое ---
        Expanded(
          flex: 2,
          child: _bodyContentTablet(view, layout),
        ),
      ],
    );
  }

  /// Строит панель инструментов в ОДНУ строку (для mobile).
  /// Слева направо: `[День ▾]` → дата (тап → DatePicker, Expanded с ellipsis)
  /// → «Today» (только если выбран не сегодня, справа рядом с иконками)
  /// → поиск (Day) → тумблер раскладки (Day/Week).
  /// «Today» находится СПРАВА (не между dropdown и датой) — использует пустое
  /// правое пространство и не сталкивается с текстом даты.
  /// Гарантированно влезает на 320px при textScale 1.3 за счёт Flexible/ellipsis
  /// на дате и компактных контролов вместо SegmentedButton.
  Widget _buildToolbar(
    BuildContext context,
    DateTime selectedDay,
    PlanView view,
    bool searchVisible,
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
                      Icons.arrow_drop_down,
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
          // --- Иконка поиска (только в режиме Day) — нейтральный цвет. ---
          if (view == PlanView.day)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                searchVisible ? Icons.search_off : Icons.search,
                color: textMuted,
              ),
              tooltip: context.s('plan.search_tooltip'),
              onPressed: () {
                final notifier = ref.read(planSearchVisibleProvider.notifier);
                notifier.state = !notifier.state;
                if (notifier.state == false) {
                  // Сбрасываем запрос при закрытии
                  ref.read(planSearchQueryProvider.notifier).state = '';
                }
              },
            ),
          // --- Тумблер раскладки (список ↔ сетка времени) — только Day/Week.
          // Для threeDay и month скрыт (всегда сетка/календарь). ---
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
  /// [searchVisible] — когда true и вид Day, прячем ExpandableWeekCalendar,
  /// чтобы клавиатура поиска не вызывала RenderFlex overflow (keyboard rule).
  Widget _bodyContent(PlanView view, PlanLayout layout, {bool searchVisible = false}) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? Theme.of(context).colorScheme.outline;
    final isGrid = layout == PlanLayout.grid;

    switch (view) {
      case PlanView.year:
        return const YearView();
      case PlanView.month:
        return const MonthView();
      case PlanView.threeDay:
        // 3-дневная сетка ВСЕГДА блочная. Полосу дней недели/недельный календарь
        // не показываем — заголовок сетки уже отображает 3 дня.
        return Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            Expanded(child: const ThreeDayTimeGrid()),
          ],
        );
      case PlanView.week:
        return Column(
          children: [
            // Раскрывающийся календарь (полоса дней недели) — только для
            // списочной раскладки. В сетке (WeekTimeGrid) свой заголовок-ряд
            // дней, иначе дни недели дублировались бы (Task D).
            if (!isGrid) const ExpandableWeekCalendar(),
            // Тонкий разделитель (02-type-space §4.3 hairline)
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            Expanded(
              child: isGrid ? const WeekTimeGrid() : const WeekAgenda(),
            ),
          ],
        );
      case PlanView.day:
        return Column(
          children: [
            // Раскрывающийся календарь: потяни вниз — развернётся месяц.
            // Скрываем когда открыт поиск — клавиатура уже занимает нижнюю
            // часть экрана, высокий календарь вызывает RenderFlex overflow.
            if (!searchVisible) const ExpandableWeekCalendar(),
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            Expanded(
              child: isGrid ? const DayTimeGrid() : const DayTimeline(),
            ),
          ],
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
        // 3-дневная сетка ВСЕГДА блочная (список-вариант не нужен).
        return Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            Expanded(child: const ThreeDayTimeGrid()),
          ],
        );
      case PlanView.week:
        return Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            Expanded(
              child: isGrid ? const WeekTimeGrid() : const WeekAgenda(),
            ),
          ],
        );
      case PlanView.day:
        return Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            Expanded(
              child: isGrid ? const DayTimeGrid() : const DayTimeline(),
            ),
          ],
        );
    }
  }
}

/// Поддерживает ли вид тумблер раскладки список↔сетка. Day и Week — да;
/// threeDay и month — нет (они всегда сетка/календарь).
bool _supportsLayoutToggle(PlanView view) =>
    view == PlanView.day || view == PlanView.week;

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
          PopupMenuItem(
            value: v,
            child: Text(_label(ctx, v)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(context, view),
              style: textTheme.bodyMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: textMuted),
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
        isGrid ? Icons.view_agenda_outlined : Icons.grid_on,
        color: textMuted,
      ),
      tooltip: isGrid
          ? context.s('plan.layout_list_tooltip')
          : context.s('plan.layout_grid_tooltip'),
      onPressed: () => ref.read(planLayoutProvider.notifier).toggle(),
    );
  }
}

/// Поле ввода поискового запроса с иконкой очистки.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

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
      autofocus: true,
      decoration: InputDecoration(
        hintText: context.s('plan.search_hint'),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
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
