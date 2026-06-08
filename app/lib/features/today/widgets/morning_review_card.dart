// FL-TODAY (morning review): карточка утреннего разбора — ядро продукта.
// Если есть просроченные невыполненные задачи (с прошлых дней), показываем
// карточку и лист, где пользователь ПОДТВЕРЖДАЕТ перенос несделанного на сегодня
// или отмечает пропуск.
//
// Два уровня:
// - Free (rule-based, локально): варианты раскладки + перенос (Drift).
// - Premium (AI, через бэкенд): tone-aware утреннее сообщение (/ai/morning-message)
//   и умные варианты плана (/ai/redistribute). Числа/время — из ответа сервера,
//   применение — локально через тот же Drift-путь, что и у free-вариантов.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/settings/tone_provider.dart';
import '../../../services/api/api_client.dart';
import '../../auth/auth_controller.dart';

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

/// Применить вариант: переносим задачи на назначенное время (локально, Drift).
Future<void> _applyVariant(WidgetRef ref, _Variant variant) async {
  final dao = ref.read(itemsDaoProvider);
  final now = DateTime.now();
  for (final entry in variant.assign.entries) {
    await dao.updateItem(
      entry.key,
      ItemsTableCompanion(
        scheduledAt: Value(entry.value),
        updatedAt: Value(now),
      ),
    );
  }
}

class MorningReviewCard extends ConsumerStatefulWidget {
  const MorningReviewCard({super.key});

  @override
  ConsumerState<MorningReviewCard> createState() => _MorningReviewCardState();
}

class _MorningReviewCardState extends ConsumerState<MorningReviewCard> {
  // AI tone-aware утреннее сообщение (premium). null = ещё не запрашивали.
  String? _aiMessage;
  bool _messageLoading = false;

  /// Запрашивает у бэкенда tone-aware сообщение (premium). Показывает inline.
  Future<void> _getAiMessage(int pendingCount) async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium feature — upgrade for AI nudges')),
      );
      return;
    }
    setState(() => _messageLoading = true);
    try {
      final tone = ref.read(toneProvider) == AppTone.harsh ? 'harsh' : 'gentle';
      final message = await ref.read(apiClientProvider).aiMorningMessage(
            pendingCount: pendingCount,
            tone: tone,
          );
      if (!mounted) return;
      setState(() => _aiMessage = message.isEmpty ? null : message);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _messageLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const Spacer(),
                // Кнопка AI-сообщения (premium). Спиннер на время запроса.
                IconButton(
                  tooltip: 'AI nudge (Premium)',
                  visualDensity: VisualDensity.compact,
                  icon: _messageLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  onPressed:
                      _messageLoading ? null : () => _getAiMessage(count),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // Показываем AI-сообщение, если получили; иначе rule-based строку.
              _aiMessage ?? ToneCopy.morningReview(tone, count),
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

class _MorningReviewSheet extends ConsumerStatefulWidget {
  const _MorningReviewSheet();

  @override
  ConsumerState<_MorningReviewSheet> createState() =>
      _MorningReviewSheetState();
}

class _MorningReviewSheetState extends ConsumerState<_MorningReviewSheet> {
  // AI-варианты плана (premium). null = ещё не запрашивали.
  List<_Variant>? _aiPlans;
  bool _aiLoading = false;

  /// Запрашивает умные варианты у бэкенда (/ai/redistribute, premium).
  Future<void> _getAiPlans() async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium feature — upgrade for AI plans')),
      );
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final targetDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final raw = await ref.read(apiClientProvider).aiRedistribute(targetDate);
      final mapped = _mapAiPlans(raw);
      if (!mounted) return;
      setState(() => _aiPlans = mapped);
      if (mapped.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI had nothing to reschedule')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  /// Парсит ответ /ai/redistribute (plans:[{label, reason, items:[{id, scheduled_at}]}])
  /// в локальные _Variant. scheduled_at — ISO 8601, приводим к локальному времени.
  List<_Variant> _mapAiPlans(List<dynamic> raw) {
    final result = <_Variant>[];
    for (final p in raw) {
      if (p is! Map) continue;
      final assign = <String, DateTime>{};
      final items = p['items'];
      if (items is List) {
        for (final it in items) {
          if (it is! Map) continue;
          final id = it['id'] as String?;
          final at = it['scheduled_at'] as String?;
          if (id == null || at == null) continue;
          final dt = DateTime.tryParse(at);
          if (dt != null) assign[id] = dt.toLocal();
        }
      }
      if (assign.isEmpty) continue;
      result.add(_Variant(
        (p['label'] as String?) ?? 'AI plan',
        (p['reason'] as String?) ?? '',
        assign,
      ));
    }
    return result;
  }

  Future<void> _apply(_Variant variant) async {
    await _applyVariant(ref, variant);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final overdue = ref.watch(overduePendingProvider).valueOrNull ??
        const <ItemsTableData>[];
    final today = ref.watch(_todayItemsForReviewProvider).valueOrNull ??
        const <ItemsTableData>[];
    final variants = overdue.isEmpty
        ? <_Variant>[]
        : _buildVariants(overdue, today, DateTime.now());
    final textTheme = Theme.of(context).textTheme;
    final aiPlans = _aiPlans;

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
                (v) => _VariantCard(variant: v, onApply: () => _apply(v)),
              ),
              const SizedBox(height: 8),
              // AI-вариант (premium): кнопка запроса + результаты.
              if (aiPlans == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: _aiLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Smarter plan with AI (Premium)'),
                    onPressed: _aiLoading ? null : _getAiPlans,
                  ),
                )
              else ...[
                Text('AI plans', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                ...aiPlans.map(
                  (v) => _VariantCard(variant: v, onApply: () => _apply(v)),
                ),
              ],
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

/// Карточка одного варианта раскладки (free или AI) с кнопкой Apply.
class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.variant, required this.onApply});

  final _Variant variant;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(variant.label),
        subtitle: variant.reason.isEmpty ? null : Text(variant.reason),
        trailing: TextButton(
          onPressed: onApply,
          child: const Text('Apply'),
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
