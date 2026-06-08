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

/// Задачи сегодня (для определения занятых слотов при построении вариантов)
final _todayItemsForReviewProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchTodayItems(DateTime.now());
});

// --- Rule-based варианты раскладки (free, без AI) ---

class _Variant {
  const _Variant(this.label, this.reason, this.assign);
  final String label;
  final String reason;
  final Map<String, DateTime> assign; // itemId → новое время
}

int _priorityWeight(String p) => switch (p) {
      'main' => 4,
      'high' => 3,
      'medium' => 2,
      _ => 1,
    };

String _slotKey(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${(t.minute < 30 ? 0 : 30).toString().padLeft(2, '0')}';

List<DateTime> _freeSlots(DateTime day, Set<String> occupied) {
  final slots = <DateTime>[];
  for (var h = 8; h < 22; h++) {
    for (final m in [0, 30]) {
      final key = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      if (!occupied.contains(key)) {
        slots.add(DateTime(day.year, day.month, day.day, h, m));
      }
    }
  }
  return slots;
}

_Variant? _assignVariant(
  String label,
  String reason,
  List<ItemsTableData> movable,
  List<DateTime> slots,
) {
  if (slots.isEmpty) return null;
  final map = <String, DateTime>{};
  for (var i = 0; i < movable.length && i < slots.length; i++) {
    map[movable[i].id] = slots[i];
  }
  if (map.isEmpty) return null;
  return _Variant(label, reason, map);
}

/// 2-3 варианта раскладки просроченных задач на сегодня (защищённые не двигаем).
List<_Variant> _buildVariants(
  List<ItemsTableData> overdue,
  List<ItemsTableData> today,
  DateTime day,
) {
  final movable = overdue.where((i) => !i.isProtected).toList()
    ..sort((a, b) => _priorityWeight(b.priority) - _priorityWeight(a.priority));
  if (movable.isEmpty) return [];

  final occupied = today.map((i) => _slotKey(i.scheduledAt)).toSet();
  final free = _freeSlots(day, occupied);
  if (free.isEmpty) return [];

  final variants = <_Variant?>[
    _assignVariant('Front-loaded', 'Earliest free slots, important first', movable, free),
    _assignVariant('Spread out', 'More breathing room between tasks', movable,
        [for (var i = 0; i < free.length; i += 2) free[i]]),
    _assignVariant('Afternoon start', 'Ease in, tackle them after noon', movable,
        free.where((s) => s.hour >= 14).toList()),
  ];
  return variants.whereType<_Variant>().toList();
}

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
    final today = ref.watch(_todayItemsForReviewProvider).valueOrNull ??
        const <ItemsTableData>[];
    final variants =
        overdue.isEmpty ? <_Variant>[] : _buildVariants(overdue, today, DateTime.now());
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
            if (variants.isNotEmpty) ...[
              Text('Smart plans (free)', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              ...variants.map(
                (v) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(v.label),
                    subtitle: Text(v.reason),
                    trailing: TextButton(
                      onPressed: () async {
                        final dao = ref.read(itemsDaoProvider);
                        final now = DateTime.now();
                        for (final entry in v.assign.entries) {
                          await dao.updateItem(
                            entry.key,
                            ItemsTableCompanion(
                              scheduledAt: Value(entry.value),
                              updatedAt: Value(now),
                            ),
                          );
                        }
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ),
              ),
              const Divider(height: 24),
            ],
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
