// FL-PLAN: Экран Plan — переключатель День/Неделя/Месяц.
// - День: недельная полоса + таймлайн выбранного дня (исходное поведение).
// - Неделя: повестка из 7 дней.
// - Месяц: календарная сетка с точками на днях с задачами.
// AppBar даёт общая оболочка ScaffoldWithNavBar; здесь вложенный Scaffold
// нужен только ради FAB. Добавление задачи переиспользует showAddTaskSheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/widgets/collapsing_fab.dart';
import '../import/import_sheet.dart';
import '../today/widgets/add_task_sheet.dart';
import 'widgets/day_timeline.dart';
import 'widgets/month_view.dart';
import 'widgets/pinned_exam_card.dart';
import 'widgets/plan_providers.dart';
import 'widgets/week_agenda.dart';
import 'widgets/week_strip.dart';

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
    if (date == today) return context.s('plan.today');
    if (date == yesterday) return context.s('plan.yesterday');
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
      ref.read(selectedDayProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch — ВНЕ LayoutBuilder: callbacks LayoutBuilder не регистрируют
    // подписки Riverpod для пересборки (вызываются в layout-фазе, не в build-фазе).
    final selectedDay = ref.watch(selectedDayProvider);
    final view = ref.watch(planViewProvider);
    final searchVisible = ref.watch(planSearchVisibleProvider);

    final isTablet = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    // На планшете — две колонки прокручиваются независимо; CollapsingFab
    // реагировал бы на случайную из них. Используем статичный extended FAB.
    // На мобильном — одна колонка с чётко определённым скроллером → collapse.
    return Scaffold(
      floatingActionButton: isTablet
          ? FloatingActionButton.extended(
              heroTag: 'plan_add_fab_tablet',
              onPressed: () => showAddTaskSheet(context, day: selectedDay),
              icon: const Icon(Icons.add),
              label: Text(context.s('today.fab_add')),
              // Тень для визуальной отдельности FAB от контента (тема: elevation=0)
              elevation: 4,
              focusElevation: 6,
              hoverElevation: 6,
            )
          : CollapsingFab(
              heroTag: 'plan_add_fab_mobile',
              onPressed: () => showAddTaskSheet(context, day: selectedDay),
              icon: const Icon(Icons.add),
              label: Text(context.s('today.fab_add')),
            ),
      body: isTablet
          ? _buildTabletLayout(context, selectedDay, view, searchVisible)
          : _buildMobileLayout(context, selectedDay, view, searchVisible),
    );
  }

  /// Mobile single-column layout (< 600px).
  Widget _buildMobileLayout(
    BuildContext context,
    DateTime selectedDay,
    PlanView view,
    bool searchVisible,
  ) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? Theme.of(context).colorScheme.outline;

    return Column(
      children: [
        // Переключатель вида + поиск + импорт
        _buildToolbar(context, selectedDay, view, searchVisible),
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
        Expanded(child: _bodyContent(view)),
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
                    ButtonSegment(value: PlanView.week, label: Text(context.s('plan.view_week'))),
                    ButtonSegment(value: PlanView.month, label: Text(context.s('plan.view_month'))),
                  ],
                  selected: {view},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      ref.read(planViewProvider.notifier).state = s.first,
                ),
                const SizedBox(height: 16),
                // Выбор даты + Today
                Row(
                  children: [
                    Builder(builder: (ctx) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      if (selectedDay != today) {
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
                // WeekStrip на планшете в левой колонке
                if (view != PlanView.month) const WeekStrip(),
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
                const SizedBox(height: 8),
                // Дополнительные действия — нейтральные иконки (не accent)
                IconButton(
                  icon: Icon(Icons.flag_outlined, color: textMuted),
                  tooltip: context.s('plan.goals_tooltip'),
                  onPressed: () => context.push('/goals'),
                ),
                TextButton.icon(
                  icon: Icon(Icons.upload_file_outlined, size: 18, color: textMuted),
                  label: Text(context.s('plan.import_label')),
                  onPressed: () =>
                      showImportSheet(context, day: selectedDay),
                ),
              ],
            ),
          ),
        ),
        // Вертикальный разделитель — hairline (02-type-space §4.3)
        VerticalDivider(width: 1, thickness: 0.5, color: border),
        // --- Правая колонка: содержимое ---
        Expanded(
          flex: 2,
          child: _bodyContentTablet(view),
        ),
      ],
    );
  }

  /// Строит общую панель инструментов (для mobile).
  Widget _buildToolbar(
    BuildContext context,
    DateTime selectedDay,
    PlanView view,
    bool searchVisible,
  ) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      // 24dp горизонтальный отступ экрана (02-type-space.md §4.1)
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Обёртка Flexible + SingleChildScrollView предотвращает overflow
          // на узких экранах (~360px): сегменты прокручиваются горизонтально,
          // но все три всегда доступны.
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<PlanView>(
                segments: [
                  ButtonSegment(value: PlanView.day, label: Text(context.s('plan.view_day'))),
                  ButtonSegment(value: PlanView.week, label: Text(context.s('plan.view_week'))),
                  ButtonSegment(value: PlanView.month, label: Text(context.s('plan.view_month'))),
                ],
                selected: {view},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    ref.read(planViewProvider.notifier).state = s.first,
              ),
            ),
          ),
          // Правая группа: дата + поиск + иконки.
          // Обёртка Flexible + SingleChildScrollView — на 320px эта группа
          // не помещается по ширине; горизонтальный скролл предотвращает overflow
          // (симметрично левой части с SegmentedButton).
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Кнопка «Today» — видна только когда выбран не сегодня
                  Builder(builder: (ctx) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    if (selectedDay != today) {
                      return TextButton(
                        onPressed: () {
                          ref.read(selectedDayProvider.notifier).state = today;
                        },
                        child: Text(ctx.s('plan.today')),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  // Тап на дату открывает DatePicker
                  GestureDetector(
                    onTap: () => _pickDate(selectedDay),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatSelectedDate(selectedDay),
                            // bodySmall для метаданных (02-type-space §1)
                            style: textTheme.bodySmall?.copyWith(
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            // нейтральный цвет для иконок тулбара (accent discipline)
                            color: textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Иконка поиска (только в режиме Day) — нейтральный цвет
                  if (view == PlanView.day)
                    IconButton(
                      icon: Icon(
                        searchVisible ? Icons.search_off : Icons.search,
                        color: textMuted,
                      ),
                      tooltip: context.s('plan.search_tooltip'),
                      onPressed: () {
                        final notifier =
                            ref.read(planSearchVisibleProvider.notifier);
                        notifier.state = !notifier.state;
                        if (notifier.state == false) {
                          // Сбрасываем запрос при закрытии
                          ref.read(planSearchQueryProvider.notifier).state = '';
                        }
                      },
                    ),
                  // Нейтральные иконки тулбара (не accent — accent discipline)
                  IconButton(
                    icon: Icon(Icons.flag_outlined, color: textMuted),
                    tooltip: context.s('plan.goals_tooltip'),
                    onPressed: () => context.push('/goals'),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.upload_file_outlined, size: 18, color: textMuted),
                    label: Text(context.s('plan.import_label')),
                    onPressed: () => showImportSheet(context, day: selectedDay),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Содержимое тела в mobile (с WeekStrip внутри для Day/Week).
  Widget _bodyContent(PlanView view) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? Theme.of(context).colorScheme.outline;

    switch (view) {
      case PlanView.month:
        return const MonthView();
      case PlanView.week:
        return Column(
          children: [
            const WeekStrip(),
            // Тонкий разделитель (02-type-space §4.3 hairline)
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            const Expanded(child: WeekAgenda()),
          ],
        );
      case PlanView.day:
        return Column(
          children: [
            const WeekStrip(),
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            const Expanded(child: DayTimeline()),
          ],
        );
    }
  }

  /// Содержимое правой колонки на планшете (без WeekStrip — он в левой колонке).
  Widget _bodyContentTablet(PlanView view) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? Theme.of(context).colorScheme.outline;

    switch (view) {
      case PlanView.month:
        return const MonthView();
      case PlanView.week:
        return Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            const Expanded(child: WeekAgenda()),
          ],
        );
      case PlanView.day:
        return Column(
          children: [
            Divider(height: 0.5, thickness: 0.5, color: border),
            // Закреплённая ember-карточка ближайшего экзамена/дедлайна (UX-LAYOUT §5)
            const PinnedExamCard(),
            const Expanded(child: DayTimeline()),
          ],
        );
    }
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
