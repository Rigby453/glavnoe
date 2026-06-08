// FL-TODAY (morning review): карточка утреннего разбора — ядро продукта.
// Если есть просроченные невыполненные задачи (с прошлых дней), показываем
// карточку и лист, где пользователь ПОДТВЕРЖДАЕТ перенос несделанного на сегодня
// или отмечает пропуск. Полностью локально (Drift); умное AI-перераспределение
// через бэкенд подключится на шаге 8 (API + sync).

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/settings/tone_provider.dart';

/// Просроченные невыполненные задачи (реактивно)
final overduePendingProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchOverduePending(DateTime.now());
});

/// Перенести задачу на сегодня, сохранив время суток.
Future<void> _moveToToday(WidgetRef ref, ItemsTableData item) async {
  final now = DateTime.now();
  final newAt = DateTime(
    now.year,
    now.month,
    now.day,
    item.scheduledAt.hour,
    item.scheduledAt.minute,
  );
  await ref.read(itemsDaoProvider).updateItem(
        item.id,
        ItemsTableCompanion(
          scheduledAt: Value(newAt),
          updatedAt: Value(now),
        ),
      );
}

class MorningReviewCard extends ConsumerWidget {
  const MorningReviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = ref.watch(overduePendingProvider).valueOrNull ??
        const <ItemsTableData>[];
    if (overdue.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final count = overdue.length;
    final tone = ref.watch(toneProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_twilight, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Text('Morning review', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ToneCopy.morningReview(tone, count),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => _showMorningReviewSheet(context),
                child: const Text('Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showMorningReviewSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _MorningReviewSheet(),
  );
}

class _MorningReviewSheet extends ConsumerWidget {
  const _MorningReviewSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = ref.watch(overduePendingProvider).valueOrNull ??
        const <ItemsTableData>[];
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Carry over', style: textTheme.headlineSmall),
                if (overdue.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      for (final item in overdue) {
                        await _moveToToday(ref, item);
                      }
                    },
                    child: const Text('Move all to today'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (overdue.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    "All caught up 🎉",
                    style: textTheme.bodyLarge,
                  ),
                ),
              )
            else
              // Ограничиваем высоту списка, чтобы лист не уезжал за экран
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: overdue.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _OverdueRow(item: overdue[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverdueRow extends ConsumerWidget {
  const _OverdueRow({required this.item});

  final ItemsTableData item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.title, style: textTheme.bodyLarge),
      subtitle: Text(
        '${DateFormat.MMMd().format(item.scheduledAt)} · ${item.priority}',
        style: textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _moveToToday(ref, item),
            child: const Text('Today'),
          ),
          IconButton(
            tooltip: 'Skip',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () =>
                ref.read(itemsDaoProvider).markSkipped(item.id),
          ),
        ],
      ),
    );
  }
}
