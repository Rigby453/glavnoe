// Трекер привычек (бэклог): хорошие с прогрессом + счётчик плохих.
// Локально-первый, без синхронизации.
// Удаление: SwipeToDelete (свайп влево) + кнопка в popup → Undo через snackbar.
// Прогресс (HabitLogsTable) сохраняется при удалении — логи остаются в БД,
// привязаны по habitId. После Undo тот же id возвращается и логи снова видны.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';

final _habitsProvider = StreamProvider.autoDispose<List<HabitsTableData>>((ref) {
  return ref.watch(habitsDaoProvider).watchActive();
});

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(_habitsProvider);
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('habits.title'))),
      floatingActionButton: FloatingActionButton(
        heroTag: 'habits_add_fab',
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: habitsAsync.when(
        // KaiLoader вместо базового CircularProgressIndicator
        loading: () => Center(child: KaiLoader(label: context.s('loading.habits'))),
        error: (e, _) => Center(
          child: Text(
            context.s('error.generic').replaceFirst('{err}', '$e'),
            style: textTheme.bodyMedium?.copyWith(color: ext.ember),
          ),
        ),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Padding(
                // 24dp screen margin
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emoji заменяется нейтральной иконкой в стиле дизайн-системы
                    Icon(
                      Icons.track_changes_outlined,
                      size: 48,
                      color: ext.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.s('habits.empty_title'),
                      style: textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.s('habits.empty_body'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          final good = habits.where((h) => h.type == 'good').toList();
          final bad = habits.where((h) => h.type == 'bad').toList();

          return ListView(
            // 24dp screen margin — spec §4.1
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
            children: [
              if (good.isNotEmpty) ...[
                // Секционный заголовок — titleMedium (body font, w600)
                Text(context.s('habits.good_habits'), style: textTheme.titleMedium),
                const SizedBox(height: 8),
                ...good.map(
                  (h) => SwipeToDelete(
                    key: ValueKey('habit_${h.id}'),
                    onDelete: () => _deleteHabit(context, ref, h),
                    child: _GoodHabitCard(
                      habit: h,
                      onDelete: () => _deleteHabit(context, ref, h),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (bad.isNotEmpty) ...[
                Text(context.s('habits.break_these'), style: textTheme.titleMedium),
                const SizedBox(height: 8),
                ...bad.map(
                  (h) => SwipeToDelete(
                    key: ValueKey('habit_${h.id}'),
                    onDelete: () => _deleteHabit(context, ref, h),
                    child: _BadHabitCard(
                      habit: h,
                      onDelete: () => _deleteHabit(context, ref, h),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Паттерн безопасного удаления:
  /// 1. Делаем снапшот данных привычки ДО удаления
  /// 2. Удаляем из БД (HabitLogsTable не трогаем — прогресс сохраняется по habitId)
  /// 3. Показываем Undo snackbar
  /// 4. По Undo — восстанавливаем через insertOnConflictUpdate снапшота (тот же id)
  Future<void> _deleteHabit(
    BuildContext context,
    WidgetRef ref,
    HabitsTableData habit,
  ) async {
    final dao = ref.read(habitsDaoProvider);
    // Снапшот сделан до удаления (habit уже пришёл из stream — это актуальная запись)
    final snapshot = habit;
    await dao.deleteHabit(habit.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: '"${habit.name}" ${context.s('habits.removed')}',
      onUndo: () => dao.restoreHabit(snapshot),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    // Диалог-тело вынесено в _AddHabitDialog (StatefulWidget) — он сам владеет
    // TextEditingController и освобождает его в своём dispose(). Здесь мы лишь
    // ждём результат и создаём привычку. Так контроллер не используется после
    // dispose (исходная причина red-screen).
    final result = await showDialog<_NewHabitResult>(
      context: context,
      builder: (_) => const _AddHabitDialog(),
    );
    if (result == null) return;
    await ref.read(habitsDaoProvider).createHabit(
          name: result.name,
          type: result.type,
          emoji: result.emoji,
        );
  }
}

// ---------------------------------------------------------------------------
// Диалог добавления привычки — владеет TextEditingController.
// ---------------------------------------------------------------------------

/// Результат диалога: возвращается через Navigator.pop.
class _NewHabitResult {
  const _NewHabitResult({
    required this.name,
    required this.type,
    required this.emoji,
  });
  final String name;
  final String type;
  final String emoji;
}

class _AddHabitDialog extends StatefulWidget {
  const _AddHabitDialog();

  @override
  State<_AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<_AddHabitDialog> {
  late final TextEditingController _nameController;
  String _type = 'good';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    // Пустое имя — ничего не делаем (валидация сохранена).
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      _NewHabitResult(name: name, type: _type, emoji: ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.s('habits.new_habit')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: context.s('habits.habit_name')),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(context.s('habits.type_label')),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(context.s('habits.type_good')),
                selected: _type == 'good',
                onSelected: (_) => setState(() => _type = 'good'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(context.s('habits.type_bad')),
                selected: _type == 'bad',
                onSelected: (_) => setState(() => _type = 'bad'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.cancel')),
        ),
        // FilledButton — единственное первичное действие в диалоге
        FilledButton(
          onPressed: _submit,
          child: Text(context.s('btn.add')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка хорошей привычки — прогресс-бар
// ---------------------------------------------------------------------------

class _GoodHabitCard extends ConsumerWidget {
  const _GoodHabitCard({required this.habit, required this.onDelete});
  final HabitsTableData habit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final dao = ref.read(habitsDaoProvider);

    return Card(
      // Отступ между карточками
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        // 16dp card inner padding — spec §4.1
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<int>(
          future: dao.countForDate(habit.id, DateTime.now()),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            final target = habit.targetPerDay;
            final done = count >= target;
            final progress = (count / target).clamp(0.0, 1.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Emoji из данных привычки
                    Text(
                      habit.emoji.isNotEmpty ? habit.emoji : '',
                      style: const TextStyle(fontSize: 22),
                    ),
                    if (habit.emoji.isNotEmpty) const SizedBox(width: 8),
                    Expanded(
                      child: Text(habit.name, style: textTheme.titleSmall),
                    ),
                    // Кнопка логирования: иконка нейтральная когда не выполнено;
                    // accent (success) — только в состоянии done
                    if (!done)
                      IconButton(
                        icon: Icon(
                          Icons.check_circle_outline,
                          // Иконка нейтральная — не accent, до момента завершения
                          color: ext.textMuted,
                        ),
                        onPressed: () => dao.logHabit(habit.id),
                      )
                    else
                      // Done state — accent moment (success)
                      Icon(Icons.check_circle, color: ext.success),
                    // Кнопка меню: архив + удалить (пользователь хочет оба способа)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: ext.textMuted, size: 20),
                      onSelected: (v) {
                        if (v == 'archive') dao.archive(habit.id);
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(context.s('habits.archive')),
                        ),
                        // Пункт удаления с Undo (ember цвет — деструктивное действие)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            context.s('habits.delete'),
                            style: TextStyle(color: ext.ember),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Прогресс-бар: accent при done (success moment), иначе textMuted
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: ext.textMuted.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation(
                      done ? colorScheme.primary : ext.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  done
                      ? context.s('habits.done')
                      : context
                          .s('habits.progress')
                          .replaceFirst('{count}', '$count')
                          .replaceFirst('{target}', '$target'),
                  style: textTheme.bodySmall?.copyWith(
                    // Done: success color; иначе textFaint (самый тихий уровень)
                    color: done ? ext.success : ext.textFaint,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка плохой привычки — счётчик
// ---------------------------------------------------------------------------

class _BadHabitCard extends ConsumerWidget {
  const _BadHabitCard({required this.habit, required this.onDelete});
  final HabitsTableData habit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final dao = ref.read(habitsDaoProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        // 16dp card inner padding
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<int>(
          future: dao.countForDate(habit.id, DateTime.now()),
          builder: (context, snap) {
            final count = snap.data ?? 0;

            return Row(
              children: [
                Text(
                  habit.emoji.isNotEmpty ? habit.emoji : '',
                  style: const TextStyle(fontSize: 22),
                ),
                if (habit.emoji.isNotEmpty) const SizedBox(width: 8),
                Expanded(child: Text(habit.name, style: textTheme.titleSmall)),
                // Счётчик нарушений: ember при count>0 (признак срочности/проблемы)
                // surface fill — без colorScheme.errorContainer (не стандарт дизайн-системы)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    // Нейтральный фон; текст ember только если count > 0
                    color: count > 0
                        ? ext.ember.withValues(alpha: 0.12)
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: count > 0 ? ext.ember.withValues(alpha: 0.4) : ext.border,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: textTheme.titleMedium?.copyWith(
                      // Ember — только для плохих событий (согласно 03-components §1)
                      color: count > 0 ? ext.ember : ext.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.add, color: ext.textMuted),
                  onPressed: () => dao.logHabit(habit.id),
                ),
                // Кнопка меню: архив + удалить (пользователь хочет оба способа)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: ext.textMuted, size: 20),
                  onSelected: (v) {
                    if (v == 'archive') dao.archive(habit.id);
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(context.s('habits.archive')),
                    ),
                    // Пункт удаления с Undo (ember цвет — деструктивное действие)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        context.s('habits.delete'),
                        style: TextStyle(color: ext.ember),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
