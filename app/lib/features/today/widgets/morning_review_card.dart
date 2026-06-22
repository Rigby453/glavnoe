// FL-TODAY (morning review): карточка утреннего разбора — ядро продукта.
// Если есть просроченные невыполненные задачи (с прошлых дней), показываем
// карточку и лист, где пользователь ПОДТВЕРЖДАЕТ перенос несделанного на сегодня
// или отмечает пропуск.
//
// Два уровня:
// - Free (rule-based, локально): варианты раскладки + перенос (Drift).
// - Premium (AI, через бэкенд): tone-aware сообщение (/ai/morning-message) и
//   умные варианты плана (/ai/redistribute).
// Общая логика разбора вынесена в review_engine.dart (переиспользуется
// вечерним разбором).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/animations/ai_insight_reveal.dart';
import '../../../core/animations/ai_pulse_dot.dart';
import '../../../core/animations/app_sheet.dart';
import '../../../core/animations/constants.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/mascot_provider.dart';
import '../../../core/settings/tone_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api/api_client.dart';
import '../../auth/auth_controller.dart';
import '../../mascot/kai_mascot.dart';
import '../../paywall/paywall_screen.dart';
import 'review_engine.dart';
import 'review_variant_card.dart';

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

class MorningReviewCard extends ConsumerStatefulWidget {
  const MorningReviewCard({super.key});

  @override
  ConsumerState<MorningReviewCard> createState() => _MorningReviewCardState();
}

class _MorningReviewCardState extends ConsumerState<MorningReviewCard> {
  // AI tone-aware утреннее сообщение (premium). null = ещё не запрашивали.
  String? _aiMessage;
  bool _messageLoading = false;

  Future<void> _getAiMessage(int pendingCount) async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      showPremiumUpsell(context, 'AI nudges');
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
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final count = overdue.length;
    final tone = ref.watch(toneProvider);
    // Визуалы тона: harsh даёт строгую подачу (ember-акцент, плотный заголовок).
    final v = ToneVisuals.of(context, tone);

    // Показываем ли Kai (04-kai.md T13): leading slot в заголовке карточки.
    // Gated by showKaiProvider + reduce-motion. Не добавляет тапов (IgnorePointer).
    final showKai = ref.watch(showKaiProvider);
    final reduce = reduceMotionOf(context);

    return Card(
      child: Padding(
        // md=16 внутренний отступ карточки (02-type-space.md §4.1)
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Kai «подаёт» карточку утреннего разбора (MASCOT.md §6, T13).
                // При showKai=false или reduce-motion — обычная иконка.
                if (showKai && !reduce)
                  IgnorePointer(
                    child: KaiMascot(
                      size: 48,
                      emotion: KaiEmotion.thinking,
                      isHarsh: tone == AppTone.harsh,
                    ),
                  )
                else
                  // Иконка тона: gentle — рассвет, harsh — молния (ember).
                  Icon(
                    v.isHarsh ? Icons.bolt : Icons.wb_twilight,
                    color: v.isHarsh
                        ? v.accent
                        : (ext?.ember ?? colorScheme.secondary),
                  ),
                const SizedBox(width: 8),
                Text(
                  context.s('today.morning_review'),
                  // harsh — плотный/строгий заголовок и ember-тон.
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: v.headingWeight,
                    color: v.isHarsh ? v.accent : null,
                  ),
                ),
                const Spacer(),
                // AI-nudge кнопка: во время загрузки — пульс вместо спиннера (§7.1)
                IconButton(
                  tooltip: context.s('today.ai_nudge_tooltip'),
                  visualDensity: VisualDensity.compact,
                  icon: _messageLoading
                      ? const AiPulseDot(size: 10)
                      : const Icon(Icons.auto_awesome, size: 18),
                  onPressed:
                      _messageLoading ? null : () => _getAiMessage(count),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // AI-сообщение появляется с reveal (§7.3); fallback — локализованный
            // rule-based текст через KaiCopy (поддерживает EN/RU/DE).
            if (_aiMessage != null)
              AiInsightReveal(
                child: Text(_aiMessage!, style: textTheme.bodyMedium),
              )
            else
              Text(
                KaiCopy.morningReview(context, tone, count),
                style: textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => _showMorningReviewSheet(context),
                child: Text(context.s('today.review_btn')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showMorningReviewSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
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
      final targetDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final raw = await ref.read(apiClientProvider).aiRedistribute(targetDate);
      final mapped = mapAiPlans(raw);
      if (!mounted) return;
      setState(() => _aiPlans = mapped);
      if (mapped.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s('today.ai_nothing_reschedule'))),
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
    final overdue = ref.watch(overduePendingProvider).valueOrNull ??
        const <ItemsTableData>[];
    final today = ref.watch(_todayItemsForReviewProvider).valueOrNull ??
        const <ItemsTableData>[];
    final variants = overdue.isEmpty
        ? <PlanVariant>[]
        : buildVariants(overdue, today, DateTime.now());
    final textTheme = Theme.of(context).textTheme;
    final aiPlans = _aiPlans;

    return SafeArea(
      child: Padding(
        // lg=24 для внутреннего отступа шита (02-type-space.md §4.1)
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.s('today.carry_over'), style: textTheme.headlineSmall),
                if (overdue.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      for (final item in overdue) {
                        await moveToDay(ref, item, now);
                      }
                    },
                    child: Text(context.s('today.move_all_today')),
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
            if (overdue.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(context.s('today.all_caught_up'), style: textTheme.bodyLarge),
                ),
              )
            else
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
            onPressed: () => moveToDay(ref, item, DateTime.now()),
            child: Text(context.s('today.move_to_today_btn')),
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
