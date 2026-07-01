// FL-TODAY-01 (Kaname redesign Phase 3): Экран Today.
//
// НОВЫЙ МАКЕТ (§6 REDESIGN-KANAME.md):
//   1. Тихая шапка: дата + одна строка приветствия, иконка настроек + аватар профиля.
//   2. Тонкая строка Kai-разбора (только когда есть просроченные / требующие переноса).
//   3. Счётчик «Главное · X/Y» с тремя точками статуса.
//   4. Единая временная шкала — все задачи/события по времени, now-line, done на месте.
//
// УБРАНО: ProgressRing, StreakRow, большой KaiMascot, тумблер тона,
//         отдельные карточки MorningReview/EveningReview, секция «Главное»,
//         HabitsTodaySection (файлы сохранены, рендер отключён).
// СОХРАНЕНО: CelebrationOverlay, провайдеры, логика свайпов, синк.
//
// UNDO-UNIFICATION (2026-07-01, решение владельца «Вариант 1»): постоянная
// кнопка ↩ (_UndoFab) и её провайдер (undo_provider.dart) УДАЛЕНЫ — они были
// единственной отменой для создания/форм-удаления задачи, а skip/snooze были
// вовсе без отмены. Теперь ЛЮБОЕ обратимое действие Today (done/skip/snooze/
// swipe-delete/создание/форм-удаление) показывает undo-тост (showAppToast,
// core/animations/app_toast.dart) — единый механизм на всё приложение.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/app_toast.dart';
import '../../core/animations/constants.dart';
import '../../core/categories/categories_enabled_provider.dart';
import '../../core/categories/category_dot.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/swipe_action_provider.dart';
import '../../core/settings/swipe_hint_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/tag_parser.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/timeline/timeline_entry.dart';
import '../../features/mascot/kai_mascot.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/rating/rating_service.dart'; // E3: оценка приложения
import '../../services/streak/streak_service.dart';
import '../../services/widget/widget_service.dart';
import '../plan/widgets/recurrence_providers.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/backup_reminder_card.dart';
import 'widgets/celebration_overlay.dart';
import 'widgets/morning_review_card.dart'
    show overduePendingProvider, showMorningReviewSheet;
import 'widgets/review_engine.dart' show moveAllToDay;

// ---------------------------------------------------------------------------
// Провайдеры
// ---------------------------------------------------------------------------

/// Все задачи на сегодня — развёрнутые: конкретные строки + виртуальные повторы.
final todayItemsProvider =
    Provider.autoDispose<AsyncValue<List<ItemsTableData>>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ref.watch(expandedDayItemsProvider(today));
});

/// Только main-задачи на сегодня (для счётчика и streak).
final todayMainItemsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchMainItems(DateTime.now());
});

// ---------------------------------------------------------------------------
// TodayScreen
// ---------------------------------------------------------------------------

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Пересчёт стрика и виджета при изменении main-задач.
    ref.listen(todayMainItemsProvider, (_, _) async {
      await ref.read(streakServiceProvider).recomputeForDay(DateTime.now());
      await refreshHomeWidget(
        itemsDao: ref.read(itemsDaoProvider),
        streakDao: ref.read(streakDaoProvider),
      );
    });

    final now = DateTime.now();
    final itemsAsync = ref.watch(todayItemsProvider);
    final mainItems =
        ref.watch(todayMainItemsProvider).valueOrNull ?? const <ItemsTableData>[];
    final overdueItems =
        ref.watch(overduePendingProvider).valueOrNull ?? const <ItemsTableData>[];

    final showKai = ref.watch(showKaiProvider);
    final morningReviewVisible = overdueItems.isNotEmpty;
    final eveningReviewVisible = now.hour >= 17;
    final pendingMain = mainItems.where((i) => i.status == 'pending').toList();
    final allMainDone = mainItems.isNotEmpty &&
        mainItems.every((i) => i.status == 'done' || i.status == 'skipped');

    // Строка Kai показывается если есть что переносить (morning review)
    // или вечерний разбор нужен (есть pending main).
    final showKaiRow =
        morningReviewVisible || (eveningReviewVisible && pendingMain.isNotEmpty);

    // Эмоция Kai для строки разбора
    final KaiEmotion kaiEmotion;
    if (morningReviewVisible) {
      kaiEmotion = KaiEmotion.thinking;
    } else if (allMainDone) {
      kaiEmotion = KaiEmotion.success;
    } else {
      kaiEmotion = KaiEmotion.neutral;
    }

    return Stack(
      children: [
        Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: FloatingActionButton(
            heroTag: 'today_add_fab',
            onPressed: () => showAddTaskSheet(context, day: now),
            tooltip: context.s('today.add_task_btn'),
            child: PhosphorIcon(PhosphorIcons.plus(PhosphorIconsStyle.regular)),
          ),
          body: itemsAsync.when(
            loading: () =>
                Center(child: KaiLoader(label: context.s('loading.tasks'))),
            error: (err, _) => Center(
              child: Text(
                context.s('today.failed_to_load').replaceFirst('{err}', '$err'),
              ),
            ),
            data: (items) => _TodayBody(
              items: items,
              mainItems: mainItems,
              overdueItems: overdueItems,
              now: now,
              showKai: showKai,
              kaiEmotion: kaiEmotion,
              showKaiRow: showKaiRow,
              morningReviewVisible: morningReviewVisible,
            ),
          ),
        ),
        const Positioned.fill(child: CelebrationOverlay()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _TodayBody — основное тело экрана с прокруткой
// ---------------------------------------------------------------------------

class _TodayBody extends StatelessWidget {
  const _TodayBody({
    required this.items,
    required this.mainItems,
    required this.overdueItems,
    required this.now,
    required this.showKai,
    required this.kaiEmotion,
    required this.showKaiRow,
    required this.morningReviewVisible,
  });

  final List<ItemsTableData> items;
  final List<ItemsTableData> mainItems;
  final List<ItemsTableData> overdueItems;
  final DateTime now;
  final bool showKai;
  final KaiEmotion kaiEmotion;
  final bool showKaiRow;
  final bool morningReviewVisible;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // lg=24 горизонтальные отступы экрана; 96dp снизу — под FAB
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
      children: [
        // 0. G2: тихое напоминание о резервном копировании (только для гостей).
        //    Возвращает SizedBox.shrink() если условия не выполнены.
        const BackupReminderCard(),
        // 1. Тихая шапка
        _QuietHeader(now: now),
        // 2. Строка Kai-разбора (только если есть что переносить)
        if (showKaiRow) ...[
          const SizedBox(height: 12),
          _KaiReviewRow(
            overdueItems: overdueItems,
            mainItems: mainItems,
            showKai: showKai,
            kaiEmotion: kaiEmotion,
            morningReviewVisible: morningReviewVisible,
            now: now,
          ),
        ],
        // 3. Счётчик «Главное · X/Y» (только если есть main-задачи)
        if (mainItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MainCounter(mainItems: mainItems),
        ],
        const SizedBox(height: 16),
        // 4. Единая временная шкала
        _TodayTimeline(items: items, day: now),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _QuietHeader — тихая шапка (§6 REDESIGN-KANAME.md)
//
// Левая часть: дата (labelMedium, textMuted) + приветствие (headlineSmall).
// Правая часть: иконка настроек (gearSix) + аватар профиля (user в accentTint).
// ---------------------------------------------------------------------------

class _QuietHeader extends StatelessWidget {
  const _QuietHeader({required this.now});

  final DateTime now;

  String _greeting(BuildContext context) {
    final hour = now.hour;
    if (hour < 12) return context.s('today.greeting_morning');
    if (hour < 18) return context.s('today.greeting_afternoon');
    return context.s('today.greeting_evening');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Null-guard: FocusThemeExtension отсутствует вне AppTheme (тест/error-recovery).
    final ext = theme.extension<FocusThemeExtension>();
    if (ext == null) return const SizedBox.shrink();

    // #2/#6: правая аватарка и шестерёнка убраны.
    // Профиль открывается из leading-кнопки AppBar (ScaffoldWithNavBar §2 UX-LAYOUT.md).
    // Внешний вид доступен из Профиля → «Оформление» (profile.section_appearance).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.yMMMMEEEEd().format(now),
          style: theme.textTheme.labelMedium?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          _greeting(context),
          style: theme.textTheme.headlineSmall,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _KaiReviewRow — тонкая строка «Kai пересобрал твой день»
//
// Показывается ТОЛЬКО при morningReview (просроченные задачи) или при
// eveningReview (17:00+, есть pending main).
// Тап разворачивает inline-карточку (Accept / Adjust / Leave).
// ---------------------------------------------------------------------------

class _KaiReviewRow extends ConsumerStatefulWidget {
  const _KaiReviewRow({
    required this.overdueItems,
    required this.mainItems,
    required this.showKai,
    required this.kaiEmotion,
    required this.morningReviewVisible,
    required this.now,
  });

  final List<ItemsTableData> overdueItems;
  final List<ItemsTableData> mainItems;
  final bool showKai;
  final KaiEmotion kaiEmotion;
  final bool morningReviewVisible;
  final DateTime now;

  @override
  ConsumerState<_KaiReviewRow> createState() => _KaiReviewRowState();
}

class _KaiReviewRowState extends ConsumerState<_KaiReviewRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Null-guard: FocusThemeExtension отсутствует вне AppTheme (тест/error-recovery).
    // Без guard: при dispose Today-таба в фоне (StatefulShellRoute) может упасть с
    // "Null check operator used on a null value" пока пользователь смотрит на Plan.
    final ext = theme.extension<FocusThemeExtension>();
    if (ext == null) return const SizedBox.shrink();
    final scheme = theme.colorScheme;
    final count = widget.overdueItems.length;
    final reduce = reduceMotionOf(context);

    final row = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              // Маленький Kai (22dp) или Phosphor-иконка sparkle
              if (widget.showKai && !reduce)
                IgnorePointer(
                  child: KaiMascot(
                    size: 22,
                    emotion: widget.kaiEmotion,
                    isHarsh: false,
                  ),
                )
              else
                PhosphorIcon(
                  PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                  size: 16,
                  color: scheme.primary,
                ),
              const SizedBox(width: 8),
              // «Kai reassembled your day»
              Expanded(
                child: Text(
                  context.s('today.kai_review_text'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: ext.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // «moved N»
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  context
                      .s('today.kai_review_moved')
                      .replaceFirst('{n}', '$count'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _expanded ? 0.25 : 0.0,
                duration: _expanded ? kDurationNormal : kDurationFast,
                child: PhosphorIcon(
                  PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
                  size: 14,
                  color: ext.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!_expanded) return row;

    // Развёрнутая карточка с кнопками
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        const SizedBox(height: 8),
        _KaiReviewCard(
          overdueItems: widget.overdueItems,
          morningReview: widget.morningReviewVisible,
          onDismiss: () => setState(() => _expanded = false),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _KaiReviewCard — inline-карточка с кнопками Accept / Adjust / Leave
// ---------------------------------------------------------------------------

class _KaiReviewCard extends ConsumerWidget {
  const _KaiReviewCard({
    required this.overdueItems,
    required this.morningReview,
    required this.onDismiss,
  });

  final List<ItemsTableData> overdueItems;
  final bool morningReview;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Null-guard: FocusThemeExtension отсутствует вне AppTheme (тест/error-recovery).
    final ext = theme.extension<FocusThemeExtension>();
    if (ext == null) return const SizedBox.shrink();
    final scheme = theme.colorScheme;
    // Задачи сегодня нужны moveAllToDay для расчёта слотов
    final todayItems =
        ref.watch(todayItemsProvider).valueOrNull ?? const <ItemsTableData>[];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.accentTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              morningReview
                  ? context.s('today.morning_review')
                  : context.s('today.evening_review'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: ext.accentInk),
            ),
            const SizedBox(height: 10),
            // Wrap предотвращает overflow на 320px
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Accept: перенести всё просроченное на сегодня
                FilledButton(
                  onPressed: overdueItems.isEmpty
                      ? null
                      : () async {
                          await moveAllToDay(
                              ref, overdueItems, DateTime.now(), todayItems);
                          // mounted-guard: _KaiReviewRowState может быть dispose'd пока
                          // moveAllToDay работает — после записи в Drift поток обновляется,
                          // showKaiRow=false, виджет удаляется из дерева до resume await.
                          // Без этой проверки: "setState() called after dispose()".
                          if (context.mounted) onDismiss();
                        },
                  child: Text(context.s('today.morning_review_accept')),
                ),
                // Adjust: детальный лист разбора
                OutlinedButton(
                  onPressed: () {
                    onDismiss();
                    showMorningReviewSheet(context);
                  },
                  child: Text(context.s('today.morning_review_adjust')),
                ),
                // Leave: скрыть строку Kai
                TextButton(
                  style:
                      TextButton.styleFrom(foregroundColor: ext.textMuted),
                  onPressed: onDismiss,
                  child: Text(context.s('today.morning_review_leave')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MainCounter — счётчик «Главное · X/Y» + 3 точки статуса
// ---------------------------------------------------------------------------

class _MainCounter extends StatelessWidget {
  const _MainCounter({required this.mainItems});

  final List<ItemsTableData> mainItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Null-guard: FocusThemeExtension отсутствует вне AppTheme (тест/error-recovery).
    final ext = theme.extension<FocusThemeExtension>();
    if (ext == null) return const SizedBox.shrink();
    final scheme = theme.colorScheme;

    final total = mainItems.length;
    final done = mainItems
        .where((i) => i.status == 'done' || i.status == 'skipped')
        .length;

    return Row(
      children: [
        Text(
          '${context.s('today.main_counter_label')} · $done/$total',
          style: theme.textTheme.labelMedium?.copyWith(
            color: ext.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        // Максимум 3 точки (лимит main = 3)
        ...List.generate(
          total.clamp(0, 3),
          (i) {
            final isDone = i < done;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? scheme.primary : null,
                  border: isDone
                      ? null
                      : Border.all(color: ext.textMuted, width: 1.5),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _TodayTimeline — единая временная шкала (§4.1 REDESIGN-KANAME.md)
//
// Визуальный стиль: [44dp time] [8dp] [28dp spine] [8dp] [Expanded card].
// Соответствует TimelineList/TimelineEntry, но оборачивает каждую строку
// в Dismissible для поддержки свайп-действий (done/skip/delete/snooze).
// Логика свайпов: порт из task_list.dart без изменений.
// ---------------------------------------------------------------------------

class _TodayTimeline extends ConsumerStatefulWidget {
  const _TodayTimeline({
    required this.items,
    required this.day,
  });

  final List<ItemsTableData> items;
  final DateTime day;

  @override
  ConsumerState<_TodayTimeline> createState() => _TodayTimelineState();
}

class _TodayTimelineState extends ConsumerState<_TodayTimeline> {
  bool _showCompleted = true;

  // Защита от двойного свайпа.
  final Set<String> _inFlight = {};

  @override
  void initState() {
    super.initState();
    // Одноразовый нёдж — пометить как просмотренный (логика из TaskList).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (reduceMotionOf(context)) return;
      final seen = ref.read(swipeHintSeenProvider);
      if (!seen) ref.read(swipeHintSeenProvider.notifier).markSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Null-guard: FocusThemeExtension отсутствует вне AppTheme (тест/error-recovery).
    // После guard Dart продвигает тип до FocusThemeExtension (non-null) — _buildRow
    // и _TimelineRow принимают non-null и менять их сигнатуру не нужно.
    final ext = theme.extension<FocusThemeExtension>();
    if (ext == null) return const SizedBox.shrink();
    final scheme = theme.colorScheme;
    final categoriesEnabled = ref.watch(categoriesEnabledProvider);

    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            context.s('today.empty'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: ext.textFaint),
          ),
        ),
      );
    }

    // Сортировка по scheduledAt
    final sorted = [...widget.items]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final pending = sorted.where((i) => i.status == 'pending').toList();
    final completed = sorted.where((i) => i.status != 'pending').toList();

    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    bool nowInserted = false;

    final rows = <Widget>[];

    // Pending-задачи с now-line между ними
    for (final item in pending) {
      final itemMin =
          item.scheduledAt.hour * 60 + item.scheduledAt.minute;
      if (!nowInserted && itemMin > nowMin) {
        rows.add(_buildNowLine(context, ext, scheme, theme));
        nowInserted = true;
      }
      rows.add(_buildRow(
          context, item, ext, scheme, theme, categoriesEnabled));
    }
    // Now-line в конце если все pending-задачи раньше текущего времени
    if (!nowInserted && pending.isNotEmpty) {
      rows.add(_buildNowLine(context, ext, scheme, theme));
    }

    // Тогл выполненных
    if (completed.isNotEmpty) {
      rows.add(const SizedBox(height: 8));
      rows.add(_buildCompletedToggle(context, ext, completed.length));
      if (_showCompleted) {
        for (final item in completed) {
          rows.add(_buildRow(
              context, item, ext, scheme, theme, categoriesEnabled));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  // ── Тогл «скрыть/показать выполненные» ────────────────────────────────────

  Widget _buildCompletedToggle(
    BuildContext context,
    FocusThemeExtension ext,
    int count,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _showCompleted = !_showCompleted),
      child: Padding(
        // Выровнять отступ с картой (44+8 = 52dp слева)
        padding: const EdgeInsets.only(left: 52, top: 6, bottom: 6),
        child: Text(
          _showCompleted
              ? '${context.s('today.hide_completed')} ($count)'
              : '${context.s('today.show_completed')} ($count)',
          style: theme.textTheme.labelMedium?.copyWith(color: ext.textMuted),
        ),
      ),
    );
  }

  // ── Черта «сейчас» ─────────────────────────────────────────────────────────

  Widget _buildNowLine(
    BuildContext context,
    FocusThemeExtension ext,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    return SizedBox(
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                context.s('today.now'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Stack(
              children: [
                // Вертикальная граничная линия
                Positioned(
                  left: 13,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: ext.border),
                ),
                // Горизонтальная accent-линия
                Positioned(
                  left: 0,
                  right: 0,
                  top: 9,
                  child: Container(height: 1, color: scheme.primary),
                ),
                // Кружок в точке пересечения
                Positioned(
                  left: 9,
                  top: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Горизонтальная accent-линия до конца строки
          Expanded(
            child: Container(height: 1, color: scheme.primary),
          ),
        ],
      ),
    );
  }

  // ── Строка задачи/события с Dismissible ───────────────────────────────────

  Widget _buildRow(
    BuildContext context,
    ItemsTableData item,
    FocusThemeExtension ext,
    ColorScheme scheme,
    ThemeData theme,
    bool categoriesEnabled,
  ) {
    final isPending = item.status == 'pending';
    final config = ref.read(swipeActionsProvider);

    // #21: тап по кружку хребта = отметить выполненным (_doDone уже
    // обрабатывает виртуальные вхождения повторов через materializeOccurrence).
    // Для уже выполненных/пропущенных — null (тап отключён).
    final rowWidget = _TimelineRow(
      item: item,
      day: widget.day,
      ext: ext,
      scheme: scheme,
      theme: theme,
      categoriesEnabled: categoriesEnabled,
      onNodeTap: isPending ? () => _doDone(context, item) : null,
    );

    if (!isPending) {
      // Выполненные/пропущенные — без свайпа
      return Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.none,
        child: rowWidget,
      );
    }

    return Dismissible(
      key: ValueKey(item.id),
      background: _swipeBg(
        color: config.right.color(context).withValues(alpha: 0.15),
        icon: config.right.icon,
        iconColor: config.right.color(context),
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBg(
        color: config.left.color(context).withValues(alpha: 0.15),
        icon: config.left.icon,
        iconColor: config.left.color(context),
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        final action = direction == DismissDirection.startToEnd
            ? config.right
            : config.left;
        return _runSwipeAction(context, item, action);
      },
      child: rowWidget,
    );
  }

  Widget _swipeBg({
    required Color color,
    required IconData icon,
    required Color iconColor,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  // ── Свайп-действия (порт из task_list.dart) ────────────────────────────────

  Future<bool> _runSwipeAction(
    BuildContext context,
    ItemsTableData item,
    SwipeAction action,
  ) async {
    if (_inFlight.contains(item.id)) return false;
    _inFlight.add(item.id);
    try {
      switch (action) {
        case SwipeAction.done:
          await _doDone(context, item);
          return false;
        case SwipeAction.skip:
          await _doSkip(context, item);
          return false;
        case SwipeAction.snooze:
          await _doSnooze(context, item);
          return false;
        case SwipeAction.delete:
          await _doDelete(context, item);
          return true;
      }
    } finally {
      _inFlight.remove(item.id);
    }
  }

  Future<void> _doDone(BuildContext context, ItemsTableData item) async {
    final dao = ref.read(itemsDaoProvider);
    final isVirtual = isVirtualOccurrenceId(item.id);
    String? targetId = item.id;
    String? virtualAnchorId;
    DateTime? virtualDate;

    if (isVirtual) {
      virtualAnchorId = anchorIdFromVirtual(item.id);
      virtualDate = dateFromVirtual(item.id) ?? item.scheduledAt;
      targetId = await dao.materializeOccurrence(
          virtualAnchorId, virtualDate,
          status: 'done');
    } else {
      await dao.markDone(item.id);
      await ref.read(notificationServiceProvider).cancelTaskReminder(item.id);
    }

    // E3: мягко просим оценку после «момента ценности» — fire-and-forget,
    // ошибки внутри сервиса поглощаются, UI не затрагивается.
    ref.read(ratingServiceProvider).maybeRequestReview().ignore();

    if (context.mounted && targetId != null) {
      final undoId = targetId;
      final capturedAnchorId = virtualAnchorId;
      final capturedDate = virtualDate;

      showAppToast(
        context,
        variant: AppToastVariant.done,
        message: '"${item.title}" ${context.s('today.marked_done')}',
        // ВАЖНО: используем УЖЕ ЗАХВАЧЕННЫЙ выше `dao` (Provider, не autoDispose —
        // живёт весь app lifecycle), а НЕ ref.read(...) внутри closure. Между
        // свайпом и тапом Undo экран уходит через кратковременный AsyncLoading
        // (todayItemsProvider/expandedDayItemsProvider пересобираются), из-за
        // чего ConsumerStatefulElement этого State успевает disposed+recreate —
        // повторный ref.read() здесь бросал "Cannot use ref after disposed".
        onUndo: () async {
          if (capturedAnchorId != null && capturedDate != null) {
            await dao.undoMaterializeOccurrence(
              anchorId: capturedAnchorId,
              date: capturedDate,
              concreteId: undoId,
            );
          } else {
            await dao.updateItem(
              undoId,
              ItemsTableCompanion(
                status: const Value('pending'),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        },
      );
    }
  }

  Future<void> _doSkip(BuildContext context, ItemsTableData item) async {
    final dao = ref.read(itemsDaoProvider);
    final isVirtual = isVirtualOccurrenceId(item.id);
    String? targetId = item.id;
    String? virtualAnchorId;
    DateTime? virtualDate;

    if (isVirtual) {
      virtualAnchorId = anchorIdFromVirtual(item.id);
      virtualDate = dateFromVirtual(item.id) ?? item.scheduledAt;
      targetId = await dao.materializeOccurrence(
        virtualAnchorId,
        virtualDate,
        status: 'skipped',
      );
    } else {
      await dao.markSkipped(item.id);
      await ref.read(notificationServiceProvider).cancelTaskReminder(item.id);
    }

    // Undo-тост (единый механизм, §3.3 ANIMATIONS.md) — раньше skip был БЕЗ
    // отмены вовсе. Симметрично _doDone: виртуальный повтор откатывается через
    // undoMaterializeOccurrence, обычная задача — возвратом status в pending.
    if (context.mounted && targetId != null) {
      final undoId = targetId;
      final capturedAnchorId = virtualAnchorId;
      final capturedDate = virtualDate;

      showAppToast(
        context,
        variant: AppToastVariant.done,
        message: '"${item.title}" ${context.s('today.skipped')}',
        // dao захвачен ВЫШЕ (см. комментарий в _doDone) — не ref.read() внутри.
        onUndo: () async {
          if (capturedAnchorId != null && capturedDate != null) {
            await dao.undoMaterializeOccurrence(
              anchorId: capturedAnchorId,
              date: capturedDate,
              concreteId: undoId,
            );
          } else {
            await dao.updateItem(
              undoId,
              ItemsTableCompanion(
                status: const Value('pending'),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        },
      );
    }
  }

  Future<void> _doSnooze(BuildContext context, ItemsTableData item) async {
    final dao = ref.read(itemsDaoProvider);
    final notifications = ref.read(notificationServiceProvider);
    final tomorrow = item.scheduledAt.add(const Duration(days: 1));
    final originalScheduledAt = item.scheduledAt;
    String? rescheduledId;
    final isVirtual = isVirtualOccurrenceId(item.id);
    String? virtualAnchorId;
    DateTime? virtualDate;

    if (isVirtual) {
      virtualAnchorId = anchorIdFromVirtual(item.id);
      virtualDate = dateFromVirtual(item.id) ?? item.scheduledAt;
      rescheduledId = await dao.materializeOccurrence(
        virtualAnchorId,
        virtualDate,
        scheduledAt: tomorrow,
      );
    } else {
      await dao.updateItem(
        item.id,
        ItemsTableCompanion(
          scheduledAt: Value(tomorrow),
          updatedAt: Value(DateTime.now()),
        ),
      );
      rescheduledId = item.id;
    }

    if (rescheduledId != null) {
      final minutes = item.reminderMinutesBefore;
      if (minutes == null) {
        await notifications.cancelTaskReminder(rescheduledId);
      } else {
        final fireAt = tomorrow.subtract(Duration(minutes: minutes));
        await notifications.scheduleTaskReminder(
            rescheduledId, item.title, fireAt);
      }
    }

    // Undo-тост: раньше здесь показывался тост БЕЗ кнопки Undo. Отмена
    // возвращает исходный scheduledAt (виртуальный повтор — через
    // undoMaterializeOccurrence, симметрично _doDone/_doSkip).
    if (context.mounted && rescheduledId != null) {
      final undoId = rescheduledId;
      final capturedAnchorId = virtualAnchorId;
      final capturedDate = virtualDate;

      showAppToast(
        context,
        variant: AppToastVariant.done,
        message: '"${item.title}" ${context.s('today.snoozed_tomorrow')}',
        // dao захвачен ВЫШЕ (см. комментарий в _doDone) — не ref.read() внутри.
        onUndo: () async {
          if (capturedAnchorId != null && capturedDate != null) {
            await dao.undoMaterializeOccurrence(
              anchorId: capturedAnchorId,
              date: capturedDate,
              concreteId: undoId,
            );
          } else {
            await dao.updateItem(
              undoId,
              ItemsTableCompanion(
                scheduledAt: Value(originalScheduledAt),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        },
      );
    }
  }

  Future<void> _doDelete(BuildContext context, ItemsTableData item) async {
    final dao = ref.read(itemsDaoProvider);
    String? deletedId = item.id;

    if (isVirtualOccurrenceId(item.id)) {
      deletedId = await dao.materializeOccurrence(
        anchorIdFromVirtual(item.id),
        dateFromVirtual(item.id) ?? item.scheduledAt,
      );
    }
    if (deletedId == null) return;

    final snapshot = await dao.getItemById(deletedId);
    final subtasksDao = ref.read(subtasksDaoProvider);
    final subtasksSnapshot = await subtasksDao.getSubtasks(deletedId);

    await dao.deleteItem(deletedId);
    await ref.read(notificationServiceProvider).cancelTaskReminder(deletedId);

    if (context.mounted) {
      showAppToast(
        context,
        variant: AppToastVariant.removed,
        message: '"${item.title}" ${context.s('today.deleted')}',
        // dao/subtasksDao захвачены ВЫШЕ (см. комментарий в _doDone) —
        // не ref.read() внутри onUndo.
        onUndo: snapshot == null
            ? null
            : () async {
                await dao.insertItem(snapshot.toCompanion(false));
                await subtasksDao.replaceForItem(
                  snapshot.id,
                  subtasksSnapshot.map((s) => s.toCompanion(false)).toList(),
                );
              },
      );
    }
  }
}

// ---------------------------------------------------------------------------
// _TimelineRow — одна строка временной шкалы (§4.1 REDESIGN-KANAME.md)
//
// Структура: [44dp time col] [8dp] [28dp spine] [8dp] [Expanded card]
// Узлы хребта — Widget-версия (без CustomPaint) для совместимости с Dismissible.
// ---------------------------------------------------------------------------

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.day,
    required this.ext,
    required this.scheme,
    required this.theme,
    required this.categoriesEnabled,
    this.onNodeTap,
  });

  final ItemsTableData item;
  final DateTime day;
  final FocusThemeExtension ext;
  final ColorScheme scheme;
  final ThemeData theme;
  final bool categoriesEnabled;
  // #21: тап по узлу хребта = переключить «выполнено».
  // null для уже выполненных/пропущенных задач.
  final VoidCallback? onNodeTap;

  TimelineNodeKind get _kind {
    if (item.status == 'done' || item.status == 'skipped') {
      return TimelineNodeKind.done;
    }
    if (item.priority == 'main') return TimelineNodeKind.mainPending;
    if (item.type == 'event') return TimelineNodeKind.event;
    return TimelineNodeKind.task;
  }

  bool get _isDone => item.status == 'done' || item.status == 'skipped';

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    final isDone = _isDone;
    final isMain = item.priority == 'main' && !isDone;

    final parsed = parseTaskTags(item.title);
    final cleanTitle =
        parsed.cleanTitle.isNotEmpty ? parsed.cleanTitle : item.title;
    final categoryTag =
        (categoriesEnabled && parsed.tags.isNotEmpty) ? parsed.tags.first : null;

    // Иконка типа (показывается только если НЕ main-pending).
    // #31б: deadline → flag (чтобы не путать с alarm = напоминание),
    //        exam   → graduationCap (единообразно с Plan/pinned_exam_card),
    //        event  → calendar (без изменений).
    IconData? typeIcon;
    if (!isMain) {
      typeIcon = switch (item.type) {
        'event' => PhosphorIcons.calendar(PhosphorIconsStyle.regular),
        'deadline' => PhosphorIcons.flag(PhosphorIconsStyle.regular),
        'exam' => PhosphorIcons.graduationCap(PhosphorIconsStyle.regular),
        _ => null,
      };
    }

    // Trailing для завершённых
    Widget? trailing;
    if (item.status == 'done') {
      trailing = PhosphorIcon(
        PhosphorIcons.check(PhosphorIconsStyle.regular),
        size: 14,
        color: ext.success,
      );
    } else if (item.status == 'skipped') {
      trailing = PhosphorIcon(
        PhosphorIcons.minus(PhosphorIconsStyle.regular),
        size: 14,
        color: ext.textFaint,
      );
    }

    final bgColor = isMain ? ext.accentTint : scheme.surface;

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: isDone ? ext.textMuted : null,
      decoration: isDone ? TextDecoration.lineThrough : null,
      decorationColor: ext.textMuted,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Колонка времени (44dp) ──────────────────────────────────────
          SizedBox(
            width: 44,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatTime(item.scheduledAt),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ext.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Хребет (28dp) — тап = отметить выполненным (#21) ──────────
          // Semantics обеспечивает доступность для screen-reader
          // (кнопка «Mark as done»), не конфликтует с Dismissible-свайпами.
          Semantics(
            label: onNodeTap != null
                ? context.s('today.mark_done_tap_tooltip')
                : null,
            button: onNodeTap != null,
            child: GestureDetector(
              onTap: onNodeTap,
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                width: 28,
                child: Stack(
                  children: [
                    // Вертикальная линия — растягивается по IntrinsicHeight
                    Positioned(
                      left: 13,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: ext.border),
                    ),
                    // Узел на позиции Y=4 от верха
                    Positioned(
                      top: 4,
                      left: _nodeLeftOffset(kind),
                      child: _buildNode(kind),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Карточка (Expanded) ─────────────────────────────────────────
          Expanded(
            child: Padding(
              // Нижний зазор между строками
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () =>
                    showAddTaskSheet(context, day: day, existing: item),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ext.border, width: 0.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Точка категории
                        if (categoryTag != null) ...[
                          CategoryDot(tag: categoryTag, size: 10),
                          const SizedBox(width: 8),
                        ],
                        // Заголовок — Expanded предотвращает overflow
                        Expanded(
                          child: Text(
                            cleanTitle,
                            style: titleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Иконка справа: shield (main) или typeIcon (#31б)
                        if (isMain) ...[
                          const SizedBox(width: 6),
                          PhosphorIcon(
                            PhosphorIcons.shield(PhosphorIconsStyle.fill),
                            size: 16,
                            color: scheme.primary,
                          ),
                        ] else if (typeIcon != null) ...[
                          const SizedBox(width: 6),
                          PhosphorIcon(typeIcon, size: 16, color: ext.textMuted),
                        ],
                        // #31а: колокольчик-индикатор напоминания.
                        // Показываем только когда задача pending И напоминание задано
                        // (reminderMinutesBefore != null). Bell fill = визуально
                        // отличается от alarm-иконки типа; малый размер (12dp)
                        // не нарушает overflow на 320px (title в Expanded).
                        if (!isDone && item.reminderMinutesBefore != null) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: context
                                .s('today.reminder_indicator_tooltip'),
                            child: PhosphorIcon(
                              PhosphorIcons.bell(PhosphorIconsStyle.fill),
                              size: 12,
                              color: ext.textMuted,
                            ),
                          ),
                        ],
                        // Trailing (done/skipped индикатор)
                        if (trailing != null) ...[
                          const SizedBox(width: 4),
                          trailing,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Узел хребта — widget-версия (без CustomPaint для совместимости с Dismissible).
  Widget _buildNode(TimelineNodeKind kind) {
    switch (kind) {
      case TimelineNodeKind.mainPending:
        // Кольцо accentTint d22 + заполненный accent d14
        return SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: ext.accentTint),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: scheme.primary),
              ),
            ],
          ),
        );
      case TimelineNodeKind.done:
        return Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: ext.textFaint),
        );
      case TimelineNodeKind.task:
      case TimelineNodeKind.event:
        return Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ext.textMuted, width: 1.5),
          ),
        );
    }
  }

  // Смещение left для узла в 28dp spine, центрируем по центру линии (x=13).
  double _nodeLeftOffset(TimelineNodeKind kind) {
    // mainPending: ширина 22dp → (28-22)/2 = 3
    // done/task/event: ширина 13dp → (28-13)/2 = 7.5
    return kind == TimelineNodeKind.mainPending ? 3.0 : 7.5;
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
