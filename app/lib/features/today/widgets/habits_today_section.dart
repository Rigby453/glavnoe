// Раздел «Привычки сегодня» в экране Today (ADR-053, slice 3).
//
// Показывает ХОРОШИЕ привычки, у которых сегодня запланированный день и цель
// ещё не достигнута (см. dueGoodHabitsProvider / isHabitDueUnmet). Размещается
// ПОД списком задач (после «Позже сегодня»). Одна привычка = одна компактная
// строка: эмодзи + название + кнопка-отметка (＋/✓) → logHabit. Привычка
// исчезает из раздела, когда цель достигнута (реактивно). Когда показывать
// нечего — раздел не рисуется вовсе (без пустой коробки).
//
// Это лишь презентационный слой поверх привычек — Item-задачами они не
// становятся (не засоряют перенос/Drift items), только отрисованы в дне.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../health/habits_providers.dart';

/// Раздел «Привычки сегодня». Встраивается в конец списка Today.
/// Если показывать нечего — возвращает SizedBox.shrink().
class HabitsTodaySection extends ConsumerWidget {
  const HabitsTodaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(dueGoodHabitsProvider);
    if (habits.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок раздела — нейтральный (привычки = спокойный слой дня).
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.track_changes_outlined,
                size: 16,
                color: ext?.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.s('today.habits_section'),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        ...habits.map((h) => _HabitTodayRow(habit: h)),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Одна строка привычки: эмодзи + название + кнопка-отметка (＋/✓).
/// Тап по кнопке вызывает logHabit(id) — тот же путь, что и на экране привычек.
class _HabitTodayRow extends ConsumerWidget {
  const _HabitTodayRow({required this.habit});

  final HabitsTableData habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        // Компактный внутренний отступ — строка глянцевая, не «толстая» карточка.
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            if (habit.emoji.isNotEmpty) ...[
              Text(habit.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                habit.name,
                style: textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Отметка: нейтральная иконка-галочка → +1 выполнение.
            IconButton(
              tooltip: context.s('today.habits_mark_done'),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.check_circle_outline,
                color: ext?.textMuted,
              ),
              onPressed: () => ref.read(habitsDaoProvider).logHabit(habit.id),
            ),
          ],
        ),
      ),
    );
  }
}
