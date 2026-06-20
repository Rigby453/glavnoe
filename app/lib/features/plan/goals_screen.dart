// FL-GOALS: Экран «Долгосрочные цели» (SPEC C4).
// Горизонты: Month → Year → 5 years → 10 years.
// Офлайн-первый: только Drift, без синхронизации (ADR-027).
// State через Riverpod; локальное состояние формы — StatefulWidget.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(context.s('plan.goals_screen_title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewGoalDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.s('plan.goals_new_button')),
      ),
      body: goalsAsync.when(
        // KaiLoader вместо CircularProgressIndicator (kai_loader.dart)
        loading: () => const Center(child: KaiLoader()),
        error: (e, _) => Center(
          child: Text(context.s('error.generic').replaceFirst('{err}', '$e')),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return _EmptyState();
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
// Пустое состояние
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textFaint = ext?.textFaint ?? Theme.of(context).colorScheme.onSurface;
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 64,
              // textFaint для иконки пустого состояния (01-color.md)
              color: textFaint,
            ),
            const SizedBox(height: 16),
            Text(
              context.s('plan.goals_empty'),
              textAlign: TextAlign.center,
              // bodyLarge для основного текста пустого состояния
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: textMuted,
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;

    // Группируем по горизонту в заданном порядке
    final byHorizon = <String, List<GoalsTableData>>{};
    for (final key in _horizonKeys) {
      final filtered = goals.where((g) => g.horizon == key).toList();
      if (filtered.isNotEmpty) {
        byHorizon[key] = filtered;
      }
    }

    return ListView(
      // 24dp горизонтальный отступ, 88dp снизу под FAB (02-type-space §4.1)
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 88),
      children: [
        for (final key in _horizonKeys)
          if (byHorizon.containsKey(key)) ...[
            // Заголовок горизонта — titleSmall, нейтральный цвет (не primary)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Text(
                _horizonLabel(context, key),
                // titleSmall для заголовков секций (accent discipline: не primary)
                style: textTheme.titleSmall?.copyWith(color: textMuted),
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
// Карточка цели
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
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('plan.goals_delete_title')),
        content: Text('"${widget.goal.title}"${ctx.s('plan.goals_delete_body_suffix')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.s('btn.cancel')),
          ),
          // Danger variant: ember foreground + ember border (03-components §5)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.secondary,
              side: BorderSide(color: Theme.of(ctx).colorScheme.secondary),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.s('plan.goals_delete_button')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await ref.read(goalsDaoProvider).deleteGoal(widget.goal.id);
  }

  /// Добавляет задачу-шаг в Today через itemsDao
  Future<void> _planToday(
      BuildContext context, GoalStepsTableData step) async {
    final now = DateTime.now();
    // Ближайший следующий час
    final scheduledAt = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    // Захватываем messenger и строку перевода до await, чтобы не использовать
    // context через async-gap
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
    messenger.showSnackBar(
      SnackBar(content: Text(addedMsg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepsAsync = ref.watch(_stepsFamily(widget.goal.id));
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;
    final textMuted = ext?.textMuted ?? colorScheme.onSurface;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      // 8dp вертикальный отступ между карточками (02-type-space §4.1)
      margin: const EdgeInsets.only(bottom: 8),
      child: stepsAsync.when(
        // Inline 20dp спиннер — слишком мал для KaiLoader; используем
        // CircularProgressIndicator напрямую (trailing в ListTile карточки)
        loading: () => ListTile(
          title: Text(widget.goal.title),
          trailing: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => ListTile(title: Text(widget.goal.title)),
        data: (steps) {
          final progress = goalProgress(steps);
          final doneCount = steps.where((s) => s.done).length;

          return ExpansionTile(
            // Заголовок + прогресс-бар
            title: Text(
              widget.goal.title,
              // titleSmall для заголовков целей (02-type-space §1)
              style: textTheme.titleSmall,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  // success цвет для прогресса завершённости
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ext?.success ?? colorScheme.primary,
                  ),
                  // Нейтральный трек (не accent)
                  backgroundColor: ext?.border ?? colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                Text(
                  steps.isEmpty
                      ? context.s('plan.goals_no_steps')
                      : '$doneCount ${context.s('plan.goals_steps_of')} ${steps.length}${context.s('plan.goals_steps_suffix')}',
                  // bodySmall для вспомогательного текста (02-type-space §1)
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            // Иконка удаления в trailing — нейтральный цвет
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: textMuted),
                  tooltip: context.s('plan.goals_delete_tooltip'),
                  onPressed: () => _confirmDelete(context),
                ),
                Icon(Icons.expand_more, color: textMuted),
              ],
            ),
            // Отключаем встроенную trailing-иконку, чтобы наш trailing работал
            controlAffinity: ListTileControlAffinity.leading,
            children: [
              // Список шагов-чекбоксов
              // SwipeToDelete + кнопка-корзина на каждой строке шага
              for (final step in steps)
                SwipeToDelete(
                  key: ValueKey('step_${step.id}'),
                  onDelete: () => _deleteStep(context, step),
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(left: 16, right: 8),
                    leading: Checkbox(
                      value: step.done,
                      // success цвет при завершении (01-color.md)
                      activeColor: ext?.success ?? colorScheme.primary,
                      onChanged: (val) => ref
                          .read(goalsDaoProvider)
                          .setStepDone(step.id, val ?? false),
                    ),
                    title: Text(
                      step.title,
                      style: step.done
                          ? textTheme.bodyMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: textMuted,
                            )
                          : textTheme.bodyMedium,
                    ),
                    // trailing: кнопка «запланировать сегодня» + кнопка удаления шага
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.today_outlined, size: 20, color: textMuted),
                          tooltip: context.s('plan.goals_plan_today_tooltip'),
                          onPressed: () => _planToday(context, step),
                        ),
                        // Кнопка удаления шага (ember цвет — деструктивное действие)
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 20, color: textMuted),
                          tooltip: context.s('plan.step_delete_tooltip'),
                          onPressed: () => _deleteStep(context, step),
                        ),
                      ],
                    ),
                  ),
                ),

              // Поле добавления шага
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stepController,
                        decoration: InputDecoration(
                          hintText: context.s('plan.goals_add_step_hint'),
                          isDense: true,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _addStep(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: textMuted),
                      tooltip: context.s('plan.goals_add_step_tooltip'),
                      onPressed: _addStep,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addStep() async {
    final title = _stepController.text.trim();
    if (title.isEmpty) return;
    _stepController.clear();
    await ref.read(goalsDaoProvider).addStep(widget.goal.id, title);
  }

  /// Паттерн безопасного удаления шага:
  /// 1. Снапшот шага ДО удаления (сохраняем id, goalId, title, done, sortOrder)
  /// 2. Удаляем из БД через removeStep
  /// 3. Показываем Undo snackbar
  /// 4. По Undo — восстанавливаем через restoreStep (тот же id, sortOrder)
  Future<void> _deleteStep(BuildContext context, GoalStepsTableData step) async {
    final dao = ref.read(goalsDaoProvider);
    // Снапшот шага до удаления (step пришёл из stream — актуальная запись)
    final snapshot = step;
    await dao.removeStep(step.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: '"${step.title}" — ${context.s('plan.step_removed')}',
      onUndo: () => dao.restoreStep(snapshot),
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
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      // 24dp внутренний отступ диалога (02-type-space §4.1)
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
            decoration: InputDecoration(hintText: context.s('plan.goals_new_hint')),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),
          // labelMedium для подписи поля горизонта
          Text(
            context.s('plan.goals_horizon_label'),
            style: textTheme.labelMedium?.copyWith(color: textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _horizonKeys
                .map(
                  (key) => ChoiceChip(
                    label: Text(_horizonLabel(context, key)),
                    selected: _horizon == key,
                    onSelected: (_) => setState(() => _horizon = key),
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
        // Единственная primary action — FilledButton (03-components §3)
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(context.s('plan.goals_create_button')),
        ),
      ],
    );
  }
}
