// Трекер привычек (бэклог): хорошие с прогрессом + счётчик плохих.
// Локально-первый, без синхронизации.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';

final _habitsProvider = StreamProvider.autoDispose<List<HabitsTableData>>((ref) {
  return ref.watch(habitsDaoProvider).watchActive();
});

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(_habitsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('habits.title'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌱', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(context.s('habits.empty_title'), style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    context.s('habits.empty_body'),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          final good = habits.where((h) => h.type == 'good').toList();
          final bad = habits.where((h) => h.type == 'bad').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (good.isNotEmpty) ...[
                Text(context.s('habits.good_habits'), style: textTheme.titleMedium),
                const SizedBox(height: 8),
                ...good.map((h) => _GoodHabitCard(habit: h)),
                const SizedBox(height: 24),
              ],
              if (bad.isNotEmpty) ...[
                Text(context.s('habits.break_these'), style: textTheme.titleMedium),
                const SizedBox(height: 8),
                ...bad.map((h) => _BadHabitCard(habit: h)),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    String type = 'good';
    String emoji = '✅';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(ctx.s('habits.new_habit')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: ctx.s('habits.habit_name')),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(ctx.s('habits.type_label')),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(ctx.s('habits.type_good')),
                    selected: type == 'good',
                    onSelected: (_) => setState(() {
                      type = 'good';
                      emoji = '✅';
                    }),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(ctx.s('habits.type_bad')),
                    selected: type == 'bad',
                    onSelected: (_) => setState(() {
                      type = 'bad';
                      emoji = '🚫';
                    }),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.s('btn.cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref.read(habitsDaoProvider).createHabit(
                      name: name,
                      type: type,
                      emoji: emoji,
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(ctx.s('btn.add')),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }
}

// ---------------------------------------------------------------------------
// Карточка хорошей привычки — прогресс-бар
// ---------------------------------------------------------------------------

class _GoodHabitCard extends ConsumerWidget {
  const _GoodHabitCard({required this.habit});
  final HabitsTableData habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dao = ref.read(habitsDaoProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                    Text(habit.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(habit.name, style: textTheme.titleSmall),
                    ),
                    if (!done)
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        color: colorScheme.primary,
                        onPressed: () => dao.logHabit(habit.id),
                      )
                    else
                      const Icon(Icons.check_circle, color: Colors.green),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'archive') dao.archive(habit.id);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'archive', child: Text(context.s('habits.archive'))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(
                      done ? Colors.green : colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // "$count / $target today" — числа не переводятся; "today" опускаем через ключ
                  done ? context.s('habits.done') : '$count / $target today',
                  style: textTheme.bodySmall?.copyWith(
                    color: done ? Colors.green : colorScheme.outline,
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
  const _BadHabitCard({required this.habit});
  final HabitsTableData habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dao = ref.read(habitsDaoProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<int>(
          future: dao.countForDate(habit.id, DateTime.now()),
          builder: (context, snap) {
            final count = snap.data ?? 0;

            return Row(
              children: [
                Text(habit.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(child: Text(habit.name, style: textTheme.titleSmall)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: count > 0
                        ? colorScheme.errorContainer
                        : colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$count',
                    style: textTheme.titleMedium?.copyWith(
                      color: count > 0 ? colorScheme.error : colorScheme.outline,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => dao.logHabit(habit.id),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'archive') dao.archive(habit.id);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'archive', child: Text(context.s('habits.archive'))),
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
