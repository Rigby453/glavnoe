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
import '../../core/utils/id.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            context.s('plan.goals_empty'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
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
    // Группируем по горизонту в заданном порядке
    final byHorizon = <String, List<GoalsTableData>>{};
    for (final key in _horizonKeys) {
      final filtered = goals.where((g) => g.horizon == key).toList();
      if (filtered.isNotEmpty) {
        byHorizon[key] = filtered;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final key in _horizonKeys)
          if (byHorizon.containsKey(key)) ...[
            // Заголовок секции
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                _horizonLabel(context, key),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: stepsAsync.when(
        loading: () => ListTile(title: Text(widget.goal.title)),
        error: (e, _) => ListTile(title: Text(widget.goal.title)),
        data: (steps) {
          final progress = goalProgress(steps);
          final doneCount = steps.where((s) => s.done).length;

          return ExpansionTile(
            // Заголовок + прогресс-бар
            title: Text(widget.goal.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 2),
                Text(
                  steps.isEmpty
                      ? context.s('plan.goals_no_steps')
                      : '$doneCount ${context.s('plan.goals_steps_of')} ${steps.length}${context.s('plan.goals_steps_suffix')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            // Иконка удаления в trailing
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: context.s('plan.goals_delete_tooltip'),
                  onPressed: () => _confirmDelete(context),
                ),
                // Стандартная стрелка ExpansionTile появится после trailing
                // только если не переопределена; используем кастомный chevron
                const Icon(Icons.expand_more),
              ],
            ),
            // Отключаем встроенную trailing-иконку, чтобы наш trailing работал
            controlAffinity: ListTileControlAffinity.leading,
            children: [
              // Список шагов-чекбоксов
              for (final step in steps)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 8),
                  leading: Checkbox(
                    value: step.done,
                    onChanged: (val) => ref
                        .read(goalsDaoProvider)
                        .setStepDone(step.id, val ?? false),
                  ),
                  title: Text(
                    step.title,
                    style: step.done
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.today_outlined, size: 20),
                    tooltip: context.s('plan.goals_plan_today_tooltip'),
                    onPressed: () => _planToday(context, step),
                  ),
                ),

              // Поле добавления шага
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 4, 16, 12),
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
                      icon: const Icon(Icons.add),
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
    return AlertDialog(
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
          const SizedBox(height: 16),
          Text(context.s('plan.goals_horizon_label'), style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(context.s('plan.goals_create_button')),
        ),
      ],
    );
  }
}
