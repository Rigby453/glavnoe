// FL-TODAY (evening review, SPEC C3): вечерний разбор завтрашнего дня.
// Показывается вечером (с 17:00). Помогает перенести сегодняшнее незакрытое на
// завтра и разложить его по свободным слотам:
// - Free (rule-based, локально): варианты раскладки на завтра + перенос.
// - Premium (AI): умные варианты (/ai/redistribute, target_date = завтра).
// Общая логика — в review_engine.dart (как у утреннего разбора).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/animations/ai_insight_reveal.dart';
import '../../../core/animations/ai_pulse_dot.dart';
import '../../../core/animations/app_sheet.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/tone_provider.dart';
import '../../../services/api/api_client.dart';
import '../../auth/auth_controller.dart';
import '../../paywall/paywall_screen.dart';
import 'review_engine.dart';
import 'review_variant_card.dart';

/// Час, с которого показываем вечерний разбор.
const int _eveningHour = 17;

DateTime _tomorrow() {
  final t = DateTime.now().add(const Duration(days: 1));
  return DateTime(t.year, t.month, t.day);
}

/// Сегодняшние невыполненные задачи (кандидаты на перенос на завтра).
final _todayPendingProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchTodayItems(DateTime.now()).map(
        (items) => items.where((i) => i.status == 'pending').toList(),
      );
});

/// Задачи, уже запланированные на завтра (для занятых слотов).
final _tomorrowItemsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchTodayItems(_tomorrow());
});

class EveningReviewCard extends ConsumerWidget {
  const EveningReviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Только вечером (ритуал «разбор на завтра»).
    if (DateTime.now().hour < _eveningHour) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tone = ref.watch(toneProvider);
    final pending = ref.watch(_todayPendingProvider).valueOrNull ??
        const <ItemsTableData>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime_outlined, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Text(context.s('today.plan_tomorrow'), style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ToneCopy.eveningReview(tone, pending.length),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => _showEveningReviewSheet(context),
                child: Text(context.s('today.plan_tomorrow_btn')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showEveningReviewSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => const _EveningReviewSheet(),
  );
}

class _EveningReviewSheet extends ConsumerStatefulWidget {
  const _EveningReviewSheet();

  @override
  ConsumerState<_EveningReviewSheet> createState() =>
      _EveningReviewSheetState();
}

class _EveningReviewSheetState extends ConsumerState<_EveningReviewSheet> {
  List<PlanVariant>? _aiPlans;
  bool _aiLoading = false;

  Future<void> _getAiPlans() async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      showPremiumUpsell(context, 'AI plans');
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final targetDate = DateFormat('yyyy-MM-dd').format(_tomorrow());
      final raw = await ref.read(apiClientProvider).aiRedistribute(targetDate);
      final mapped = mapAiPlans(raw);
      if (!mounted) return;
      setState(() => _aiPlans = mapped);
      if (mapped.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s('today.ai_nothing_schedule'))),
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

  Future<void> _apply(PlanVariant variant) async {
    await applyVariant(ref, variant);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(_todayPendingProvider).valueOrNull ??
        const <ItemsTableData>[];
    final tomorrowItems = ref.watch(_tomorrowItemsProvider).valueOrNull ??
        const <ItemsTableData>[];
    final tomorrow = _tomorrow();
    final variants = pending.isEmpty
        ? <PlanVariant>[]
        : buildVariants(pending, tomorrowItems, tomorrow);
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
                Text(context.s('today.plan_tomorrow'), style: textTheme.headlineSmall),
                if (pending.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      for (final item in pending) {
                        await moveToDay(ref, item, tomorrow);
                      }
                    },
                    child: Text(context.s('today.move_all_tomorrow')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (variants.isNotEmpty) ...[
              Text(context.s('today.smart_plans'), style: textTheme.titleSmall),
              const SizedBox(height: 8),
              ...variants.map(
                (v) => ReviewVariantCard(variant: v, onApply: () => _apply(v)),
              ),
              const SizedBox(height: 8),
              if (aiPlans == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    // Во время загрузки AI — пульс вместо спиннера (§7.1)
                    icon: _aiLoading
                        ? const AiPulseDot(size: 10)
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(context.s('today.ai_smarter_plan')),
                    onPressed: _aiLoading ? null : _getAiPlans,
                  ),
                )
              else ...[
                Text(context.s('today.ai_plans'), style: textTheme.titleSmall),
                const SizedBox(height: 8),
                // AI-варианты плана появляются с reveal (§7.3)
                ...aiPlans.map(
                  (v) => AiInsightReveal(
                    child: ReviewVariantCard(
                      variant: v,
                      onApply: () => _apply(v),
                    ),
                  ),
                ),
              ],
              const Divider(height: 24),
            ],
            if (pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(context.s('today.nothing_left'),
                      style: textTheme.bodyLarge),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: pending.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _PendingRow(item: pending[index], tomorrow: tomorrow),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends ConsumerWidget {
  const _PendingRow({required this.item, required this.tomorrow});

  final ItemsTableData item;
  final DateTime tomorrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.title, style: textTheme.bodyLarge),
      subtitle: Text(
        '${DateFormat.Hm().format(item.scheduledAt)} · ${item.priority}',
        style: textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => moveToDay(ref, item, tomorrow),
            child: Text(context.s('today.move_to_tomorrow_btn')),
          ),
          IconButton(
            tooltip: context.s('today.skip_tooltip'),
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => ref.read(itemsDaoProvider).markSkipped(item.id),
          ),
        ],
      ),
    );
  }
}
