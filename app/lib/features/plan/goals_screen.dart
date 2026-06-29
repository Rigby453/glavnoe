// FL-GOALS: Экран «Долгосрочные цели» (SPEC C4).
// Горизонты: Month → Year → 5 years → 10 years.
// Офлайн-первый: только Drift, без синхронизации (ADR-027).
// State через Riverpod; локальное состояние формы — StatefulWidget.
//
// Kaname redesign (§4.2): object cards — surface1 + hairline + R14.
// Иконки: Phosphor (flag, target, calendarCheck, trash, plus).
// Пустое состояние: KaiMascot(neutral, 64) + приглашение + FilledButton.
// ONE primary action per screen (FAB / empty-state button взаимоисключают).

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import '../mascot/kai_mascot.dart';
import 'goal_progress.dart';

// ---------------------------------------------------------------------------
// Провайдеры
// ---------------------------------------------------------------------------

/// Реактивный список всех целей
final _goalsProvider = StreamProvider<List<GoalsTableData>>((ref) {
  return ref.watch(goalsDaoProvider).watchGoals();
});

/// Реактивный список шагов конкретной цели
final _stepsFamily =
    StreamProvider.family<List<GoalStepsTableData>, String>((ref, goalId) {
  return ref.watch(goalsDaoProvider).watchSteps(goalId);
});

// ---------------------------------------------------------------------------
// Константы горизонтов
// ---------------------------------------------------------------------------

const List<String> _horizonKeys = ['month', 'year', 'five_years', 'ten_years'];

/// Ключ горизонта → ключ локализации.
String _horizonL10nKey(String key) {
  const map = {
    'month': 'plan.horizon_month',
    'year': 'plan.horizon_year',
    'five_years': 'plan.horizon_five_years',
    'ten_years': 'plan.horizon_ten_years',
  };
  return map[key] ?? key;
}

String _horizonLabel(BuildContext context, String key) =>
    context.s(_horizonL10nKey(key));

// ---------------------------------------------------------------------------
// Экран
// ---------------------------------------------------------------------------

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(_goalsProvider);

    // FAB показываем только когда список непустой:
    // пустое состояние имеет собственную primary-кнопку (ONE primary per screen).
    final showFab = goalsAsync.maybeWhen(
      data: (goals) => goals.isNotEmpty,
      orElse: () => true, // при loading/error не убираем FAB резко
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.s('plan.goals_screen_title'))),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: showFab
          ? FloatingActionButton(
              heroTag: 'goals_add_fab',
              onPressed: () => _showNewGoalDialog(context, ref),
              tooltip: context.s('plan.goals_new_button'),
              child: Icon(PhosphorIcons.plus()),
            )
          : null,
      body: goalsAsync.when(
        loading: () => const Center(child: KaiLoader()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.s('error.generic').replaceFirst('{err}', '$e'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return _EmptyState(
              onAdd: () => _showNewGoalDialog(context, ref),
            );
          }
          return _GoalsList(goals: goals);
        },
      ),
    );
  }

  Future<void> _showNewGoalDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _NewGoalDialog(
        onCreate: (title, horizon) async {
          await ref.read(goalsDaoProvider).createGoal(title, horizon);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Пустое состояние — §4.2 invitation pattern
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kai в нейтральном состоянии — §4.2: size 64 для empty/paywall
            const KaiMascot(
              emotion: KaiEmotion.neutral,
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              context.s('plan.goals_empty'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: textMuted),
            ),
            const SizedBox(height: 24),
            // Единственная primary-кнопка на экране (§4.3)
            FilledButton(
              onPressed: onAdd,
              child: Text(context.s('plan.goals_new_button')),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Список целей по горизонтам
// ---------------------------------------------------------------------------

class _GoalsList extends ConsumerWidget {
  const _GoalsList({required this.goals});
  final List<GoalsTableData> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;

    // Группируем по горизонту в заданном порядке
    final byHorizon = <String, List<GoalsTableData>>{};
    for (final key in _horizonKeys) {
      final filtered = goals.where((g) => g.horizon == key).toList();
      if (filtered.isNotEmpty) byHorizon[key] = filtered;
    }

    return ListView(
      // 24dp горизонтальный отступ (токен spacing.lg = 24)
      // 88dp снизу под FAB
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 88),
      children: [
        for (final key in _horizonKeys)
          if (byHorizon.containsKey(key)) ...[
            // Заголовок горизонта — labelMedium, textMuted (sentence case)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Text(
                _horizonLabel(context, key),
                style: textTheme.labelMedium?.copyWith(color: textMuted),
              ),
            ),
            for (final goal in byHorizon[key]!)
              _GoalCard(goal: goal),
          ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка цели — §4.2 object card: surface1 + hairline + R14
// ---------------------------------------------------------------------------

class _GoalCard extends ConsumerStatefulWidget {
  const _GoalCard({required this.goal});
  final GoalsTableData goal;

  @override
  ConsumerState<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<_GoalCard> {
  final _stepController = TextEditingController();

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctxExt = Theme.of(ctx).extension<FocusThemeExtension>();
        final emberColor =
            ctxExt?.ember ?? Theme.of(ctx).colorScheme.secondary;

        return AlertDialog(
          title: Text(ctx.s('plan.goals_delete_title')),
          content: Text(
            '"${widget.goal.title}"${ctx.s('plan.goals_delete_body_suffix')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.s('btn.cancel')),
            ),
            // Деструктивное действие — ember outline (§4.3)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: emberColor,
                side: BorderSide(color: emberColor),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctx.s('plan.goals_delete_button')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await ref.read(goalsDaoProvider).deleteGoal(widget.goal.id);
  }

  /// Добавляет задачу-шаг в Today через itemsDao.
  /// Захватываем messenger и строку ДО await, чтобы не использовать
  /// context через async-gap.
  Future<void> _planToday(
      BuildContext context, GoalStepsTableData step) async {
    final now = DateTime.now();
    final scheduledAt =
        DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    final messenger = ScaffoldMessenger.of(context);
    final addedMsg = context.s('plan.goals_added_to_today');

    await ref.read(itemsDaoProvider).insertItem(
          ItemsTableCompanion(
            id: Value(uuidV4()),
            userId: const Value('local'),
            title: Value(step.title),
            type: const Value('task'),
            priority: const Value('medium'),
            status: const Value('pending'),
            scheduledAt: Value(scheduledAt),
            durationMinutes: const Value(30),
            isProtected: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(addedMsg)));
  }

  Future<void> _addStep() async {
    final title = _stepController.text.trim();
    if (title.isEmpty) return;
    _stepController.clear();
    await ref.read(goalsDaoProvider).addStep(widget.goal.id, title);
  }

  /// Безопасное удаление шага:
  /// 1. Снапшот ДО удаления
  /// 2. Удаление из БД
  /// 3. Undo snackbar
  /// 4. По Undo — restoreStep (тот же id, sortOrder)
  Future<void> _deleteStep(BuildContext context, GoalStepsTableData step) async {
    final dao = ref.read(goalsDaoProvider);
    final snapshot = step;
    await dao.removeStep(step.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: '"${step.title}" — ${context.s('plan.step_removed')}',
      onUndo: () => dao.restoreStep(snapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepsAsync = ref.watch(_stepsFamily(widget.goal.id));
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final textMuted = ext?.textMuted ?? colorScheme.onSurface;
    final borderColor = ext?.border ?? colorScheme.outline;
    final successColor = ext?.success ?? colorScheme.primary;
    final emberColor = ext?.ember ?? colorScheme.secondary;

    // §4.2 object card: surface1 + hairline (0.5dp) + R14, no shadow
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: stepsAsync.when(
        // Inline 20dp спиннер — слишком мал для KaiLoader
        loading: () => ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Icon(PhosphorIcons.flag(), size: 20, color: textMuted),
          title: Text(widget.goal.title, overflow: TextOverflow.ellipsis),
          trailing: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Icon(PhosphorIcons.flag(), size: 20, color: textMuted),
          title: Text(widget.goal.title, overflow: TextOverflow.ellipsis),
        ),
        data: (steps) {
          final progress = goalProgress(steps);
          final doneCount = steps.where((s) => s.done).length;

          return Theme(
            // Убираем стандартный divider ExpansionTile — используем свои hairlines
            data: Theme.of(context)
                .copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              // Убираем границу ExpansionTile (она уже на Container)
              shape: const Border(),
              collapsedShape: const Border(),
              // Кнопка раскрытия — слева; trailing свободен для иконки удаления
              controlAffinity: ListTileControlAffinity.leading,
              tilePadding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
              childrenPadding: EdgeInsets.zero,
              // Заголовок: флаг + название (Expanded защищает от overflow)
              title: Row(
                children: [
                  Icon(PhosphorIcons.flag(), size: 20, color: textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.goal.title,
                      style: textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4, left: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Прогресс-бар success-цветом на нейтральном треке
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(successColor),
                        backgroundColor: borderColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // «N of M steps» / «No steps yet»
                    Text(
                      steps.isEmpty
                          ? context.s('plan.goals_no_steps')
                          : '$doneCount ${context.s('plan.goals_steps_of')} '
                              '${steps.length}'
                              '${context.s('plan.goals_steps_suffix')}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: textMuted),
                    ),
                  ],
                ),
              ),
              // Деструктивное действие — trash (ember), §4.3
              trailing: IconButton(
                icon: Icon(
                  PhosphorIcons.trash(),
                  size: 20,
                  color: emberColor,
                ),
                tooltip: context.s('plan.goals_delete_tooltip'),
                onPressed: () => _confirmDelete(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              children: [
                // Список шагов — hairline-divided rows (§4.2 dense list)
                for (final step in steps)
                  SwipeToDelete(
                    key: ValueKey('step_${step.id}'),
                    onDelete: () => _deleteStep(context, step),
                    child: _StepRow(
                      step: step,
                      borderColor: borderColor,
                      successColor: successColor,
                      emberColor: emberColor,
                      textMuted: textMuted,
                      onToggle: (val) => ref
                          .read(goalsDaoProvider)
                          .setStepDone(step.id, val ?? false),
                      onPlanToday: () => _planToday(context, step),
                      onDelete: () => _deleteStep(context, step),
                      planTodayTooltip:
                          context.s('plan.goals_plan_today_tooltip'),
                      deleteTooltip:
                          context.s('plan.step_delete_tooltip'),
                    ),
                  ),

                // Поле добавления шага
                _AddStepRow(
                  controller: _stepController,
                  borderColor: borderColor,
                  textMuted: textMuted,
                  hintText: context.s('plan.goals_add_step_hint'),
                  addTooltip: context.s('plan.goals_add_step_tooltip'),
                  onAdd: _addStep,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Строка шага — hairline-divided row (§4.2 dense list, NOT ListTile)
// ---------------------------------------------------------------------------

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.borderColor,
    required this.successColor,
    required this.emberColor,
    required this.textMuted,
    required this.onToggle,
    required this.onPlanToday,
    required this.onDelete,
    required this.planTodayTooltip,
    required this.deleteTooltip,
  });

  final GoalStepsTableData step;
  final Color borderColor;
  final Color successColor;
  final Color emberColor;
  final Color textMuted;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onPlanToday;
  final VoidCallback onDelete;
  final String planTodayTooltip;
  final String deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      // Hairline разделитель сверху (§4.2 dense list)
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Row(
        children: [
          // Checkbox — success цвет при завершении
          Checkbox(
            value: step.done,
            activeColor: successColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: onToggle,
          ),
          const SizedBox(width: 4),
          // Название шага — Expanded защищает от overflow
          Expanded(
            child: Text(
              step.title,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: step.done
                  ? textTheme.bodyMedium?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: textMuted,
                    )
                  : textTheme.bodyMedium,
            ),
          ),
          // «Запланировать сегодня» — calendarCheck (§icon-map: today_outlined)
          IconButton(
            icon: Icon(
              PhosphorIcons.calendarCheck(),
              size: 20,
              color: textMuted,
            ),
            tooltip: planTodayTooltip,
            onPressed: onPlanToday,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Удалить шаг — trash (ember, §4.3 destructive)
          IconButton(
            icon: Icon(
              PhosphorIcons.trash(),
              size: 20,
              color: emberColor,
            ),
            tooltip: deleteTooltip,
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Строка добавления шага
// ---------------------------------------------------------------------------

class _AddStepRow extends StatelessWidget {
  const _AddStepRow({
    required this.controller,
    required this.borderColor,
    required this.textMuted,
    required this.hintText,
    required this.addTooltip,
    required this.onAdd,
  });

  final TextEditingController controller;
  final Color borderColor;
  final Color textMuted;
  final String hintText;
  final String addTooltip;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onAdd(),
            ),
          ),
          IconButton(
            icon: Icon(PhosphorIcons.plus(), size: 20, color: textMuted),
            tooltip: addTooltip,
            onPressed: onAdd,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Диалог создания новой цели
// ---------------------------------------------------------------------------

class _NewGoalDialog extends StatefulWidget {
  const _NewGoalDialog({required this.onCreate});
  final Future<void> Function(String title, String horizon) onCreate;

  @override
  State<_NewGoalDialog> createState() => _NewGoalDialogState();
}

class _NewGoalDialogState extends State<_NewGoalDialog> {
  final _titleController = TextEditingController();
  String _horizon = 'month';
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    await widget.onCreate(title, _horizon);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;
    final accentTint = ext?.accentTint;
    final accentInk = ext?.accentInk ?? colorScheme.primary;
    final borderColor = ext?.border ?? colorScheme.outline;

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Text(context.s('plan.goals_new_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: context.s('plan.goals_new_hint'),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),
          // Подпись поля горизонта — labelMedium, textMuted
          Text(
            context.s('plan.goals_horizon_label'),
            style: textTheme.labelMedium?.copyWith(color: textMuted),
          ),
          const SizedBox(height: 10),
          // Chips горизонта — §4.3: accentTint + accent border (selected)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _horizonKeys
                .map(
                  (key) => ChoiceChip(
                    label: Text(_horizonLabel(context, key)),
                    selected: _horizon == key,
                    onSelected: (_) => setState(() => _horizon = key),
                    selectedColor: accentTint,
                    labelStyle: _horizon == key
                        ? textTheme.labelMedium
                            ?.copyWith(color: accentInk)
                        : textTheme.labelMedium
                            ?.copyWith(color: textMuted),
                    side: BorderSide(
                      color: _horizon == key
                          ? colorScheme.primary
                          : borderColor,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.cancel')),
        ),
        // Единственная primary action — FilledButton (§4.3)
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(context.s('plan.goals_create_button')),
        ),
      ],
    );
  }
}
