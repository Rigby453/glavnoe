// FL-TODAY-01: Экран Today — собирает кольцо прогресса, строку streak,
// список задач и FAB добавления. AppBar даёт общая оболочка ScaffoldWithNavBar,
// поэтому здесь вложенный Scaffold без AppBar (нужен только ради FAB),
// а приветствие и дата вынесены в шапку тела.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/utils/breakpoints.dart';
import '../../features/mascot/kai_mascot.dart';
import '../../services/streak/streak_service.dart';
import '../../services/widget/widget_service.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/celebration_overlay.dart';
import 'widgets/evening_review_card.dart';
import 'widgets/morning_review_card.dart';
import 'widgets/progress_ring.dart';
import 'widgets/streak_row.dart';
import 'widgets/task_list.dart';

/// Все задачи на сегодня (реактивно из Drift)
final todayItemsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchTodayItems(DateTime.now());
});

/// Только main-задачи на сегодня — для кольца прогресса
final todayMainItemsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchMainItems(DateTime.now());
});

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch/listen — ВНЕ LayoutBuilder: callbacks LayoutBuilder не регистрируют
    // подписки Riverpod для пересборки (вызываются в layout-фазе, не в build-фазе).
    ref.listen(todayMainItemsProvider, (_, _) async {
      await ref.read(streakServiceProvider).recomputeForDay(DateTime.now());
      await refreshHomeWidget(
        itemsDao: ref.read(itemsDaoProvider),
        streakDao: ref.read(streakDaoProvider),
      );
    });

    final now = DateTime.now();
    final itemsAsync = ref.watch(todayItemsProvider);
    final mainItems = ref.watch(todayMainItemsProvider).valueOrNull ??
        const <ItemsTableData>[];
    final tone = ref.watch(toneProvider);
    final allMainDone = mainItems.isNotEmpty &&
        mainItems.every((i) => i.status == 'done' || i.status == 'skipped');

    // Kai: определяем эмоцию по прогрессу главных задач
    final showKai = ref.watch(showKaiProvider);
    final kaiEmotion = mainItems.isEmpty
        ? KaiEmotion.neutral
        : (allMainDone ? KaiEmotion.success : KaiEmotion.neutral);

    final isTablet = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    if (isTablet) {
      return _buildTabletLayout(
          context, itemsAsync, mainItems, tone, allMainDone, now,
          showKai: showKai, kaiEmotion: kaiEmotion);
    }
    return _buildMobileLayout(
        context, itemsAsync, mainItems, tone, allMainDone, now,
        showKai: showKai, kaiEmotion: kaiEmotion);
  }

  /// Мобильный макет — одна колонка, оригинальный вид.
  Widget _buildMobileLayout(
    BuildContext context,
    AsyncValue<List<ItemsTableData>> itemsAsync,
    List<ItemsTableData> mainItems,
    AppTone tone,
    bool allMainDone,
    DateTime now, {
    required bool showKai,
    required KaiEmotion kaiEmotion,
  }) {

    return Stack(
      children: [
        Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () => showAddTaskSheet(context, day: now),
            child: const Icon(Icons.add),
          ),
          body: itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Failed to load tasks: $err')),
            data: (items) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _Header(now: now)),
                      if (showKai) ...[
                        const SizedBox(width: 8),
                        _KaiHeader(
                          emotion: kaiEmotion,
                          isHarsh: tone == AppTone.harsh,
                        ),
                      ],
                      const _ToneToggle(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const MorningReviewCard(),
                  const EveningReviewCard(),
                  const SizedBox(height: 8),
                  Center(child: ProgressRing(items: mainItems)),
                  const SizedBox(height: 24),
                  const StreakRow(),
                  if (allMainDone) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        ToneCopy.allDone(tone),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TaskList(items: items, day: now),
                ],
              );
            },
          ),
        ),
        const Positioned.fill(child: CelebrationOverlay()),
      ],
    );
  }

  /// Планшетный макет ≥600px — две колонки равной ширины.
  /// Левая: шапка + ProgressRing + StreakRow + карточки обзора.
  /// Правая: список задач.
  Widget _buildTabletLayout(
    BuildContext context,
    AsyncValue<List<ItemsTableData>> itemsAsync,
    List<ItemsTableData> mainItems,
    AppTone tone,
    bool allMainDone,
    DateTime now, {
    required bool showKai,
    required KaiEmotion kaiEmotion,
  }) {
    final items = itemsAsync.valueOrNull ?? const <ItemsTableData>[];

    return Stack(
      children: [
        Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () => showAddTaskSheet(context, day: now),
            child: const Icon(Icons.add),
          ),
          body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Левая колонка: шапка, кольцо, серия, карточки обзора ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _Header(now: now)),
                            if (showKai) ...[
                              const SizedBox(width: 8),
                              _KaiHeader(
                                emotion: kaiEmotion,
                                isHarsh: tone == AppTone.harsh,
                              ),
                            ],
                            const _ToneToggle(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(child: ProgressRing(items: mainItems)),
                        const SizedBox(height: 24),
                        const StreakRow(),
                        if (allMainDone) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              ToneCopy.allDone(tone),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const MorningReviewCard(),
                        const EveningReviewCard(),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // --- Правая колонка: список задач ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: TaskList(items: items, day: now),
                  ),
                ),
              ],
            ),
        ),
        const Positioned.fill(child: CelebrationOverlay()),
      ],
    );
  }
}

/// Приветствие, зависящее от времени суток, + сегодняшняя дата
class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  String _greeting(BuildContext context) {
    final hour = now.hour;
    if (hour < 12) return context.s('today.greeting_morning');
    if (hour < 18) return context.s('today.greeting_afternoon');
    return context.s('today.greeting_evening');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting(context), style: textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          DateFormat.yMMMMEEEEd().format(now),
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Маленький тумблер тона gentle/harsh в шапке Today.
class _ToneToggle extends ConsumerWidget {
  const _ToneToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final harsh = tone == AppTone.harsh;
    return TextButton.icon(
      onPressed: () => ref.read(toneProvider.notifier).toggle(),
      icon: Icon(harsh ? Icons.bolt : Icons.spa_outlined, size: 18),
      label: Text(harsh ? context.s('today.tone_harsh') : context.s('today.tone_gentle')),
    );
  }
}

/// Маскот Kai в шапке Today — компактный, 44×44, вертикально выровнен по центру.
/// Виден только если showKaiProvider == true (условие проверяется в _buildMobileLayout
/// и _buildTabletLayout, сюда попадаем уже внутри if-блока).
class _KaiHeader extends StatelessWidget {
  const _KaiHeader({
    required this.emotion,
    required this.isHarsh,
  });

  final KaiEmotion emotion;
  final bool isHarsh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Небольшой отступ сверху, чтобы выровнять оптически с иконкой тона
      padding: const EdgeInsets.only(top: 2),
      child: KaiMascot(
        size: 44,
        emotion: emotion,
        isHarsh: isHarsh,
        // onTap — зарезервировано для будущего цикла выражений
      ),
    );
  }
}
