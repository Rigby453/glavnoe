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
  // Локально скрыта на текущую сессию (кнопка «Оставить»).
  // Сбрасывается автоматически, когда список просроченных изменяется.
  bool _dismissed = false;
  int _lastKnownCount = -1;

  @override
  Widget build(BuildContext context) {
    final overdue = ref.watch(overduePendingProvider).valueOrNull ??
        const <ItemsTableData>[];
    if (overdue.isEmpty) return const SizedBox.shrink();

    // Сбрасываем dismissed если пришли новые просроченные (новый день).
    final count = overdue.length;
    if (count != _lastKnownCount) {
      _dismissed = false;
      _lastKnownCount = count;
    }
    if (_dismissed) return const SizedBox.shrink();

    // Задачи сегодня — для распределения слотов при «Принять всё».
    final today = ref.watch(_todayItemsForReviewProvider).valueOrNull ??
        const <ItemsTableData>[];

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final tone = ref.watch(toneProvider);

    // Ember — визуальный сигнал «срочно»; работает во всех 5 темах (токен urgent).
    final ember = ext?.ember ?? colorScheme.error;

    // Kai в шапке карточки (T13 MASCOT.md) — меньше (36dp), без анимации тапа.
    // При showKai=false или reduce-motion — рассветная иконка.
    final showKai = ref.watch(showKaiProvider);
    final reduce = reduceMotionOf(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Тёплый ember-тинт фона — карточка выделяется среди нейтрального контента.
        color: ember.withAlpha(20),
        borderRadius: BorderRadius.circular(16), // radius.md
        border: Border.all(color: ember.withAlpha(80), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Заголовок: иконка/Kai + название + счётчик задач ---
          Row(
            children: [
              // Kai «подаёт» разбор (T13); меньше, чем в шапке экрана.
              if (showKai && !reduce)
                IgnorePointer(
                  child: KaiMascot(
                    size: 36,
                    emotion: KaiEmotion.thinking,
                    isHarsh: tone == AppTone.harsh,
                  ),
                )
              else
                Icon(Icons.wb_twilight, color: ember, size: 22),
              const SizedBox(width: 8),
              // Expanded защищает от RenderFlex overflow на 320px.
              Expanded(
                child: Text(
                  context.s('today.morning_review'),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ember,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Счётчик просроченных задач.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ember.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: textTheme.labelMedium?.copyWith(
                    color: ember,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // --- Контекстное сообщение (rule-based, tone-aware) ---
          Text(
            KaiCopy.morningReview(context, tone, count),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          // --- Кнопки в одно касание ---
          // Wrap предотвращает overflow: на 320px кнопки переносятся на следующую строку.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // «Принять всё» — перенести всё на сегодня.
              FilledButton(
                onPressed: () async {
                  await moveAllToDay(ref, overdue, DateTime.now(), today);
                },
                child: Text(context.s('today.morning_review_accept')),
              ),
              // «Поправить» — открыть детальный лист (варианты, AI-план).
              OutlinedButton(
                onPressed: () => _showMorningReviewSheet(context),
                child: Text(context.s('today.morning_review_adjust')),
              ),
              // «Оставить» — скрыть карточку до следующей сессии.
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: ext?.textMuted,
                ),
                onPressed: () => setState(() => _dismissed = true),
                child: Text(context.s('today.morning_review_leave')),
              ),
            ],
          ),
        ],
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
              children: [
                Expanded(
                  child: Text(context.s('today.carry_over'), style: textTheme.headlineSmall),
                ),
                if (overdue.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      // Распределяем по разным слотам, иначе все задачи
                      // встали бы на одно и то же время (стак).
                      await moveAllToDay(
                        ref,
                        overdue,
                        DateTime.now(),
                        today,
                      );
                    },
                    child: Text(context.s('today.move_all_today')),
                  ),
                // Крестик закрытия — видимый аффорданс (всегда присутствует)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.s('btn.close'),
                  onPressed: () => Navigator.of(context).maybePop(),
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
