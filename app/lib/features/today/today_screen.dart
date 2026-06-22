// FL-TODAY-01: Экран Today — собирает кольцо прогресса, строку streak,
// список задач и FAB добавления. AppBar даёт общая оболочка ScaffoldWithNavBar,
// поэтому здесь вложенный Scaffold без AppBar (нужен только ради FAB),
// а приветствие и дата вынесены в шапку тела.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/animations/constants.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/mood/mood_provider.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/widgets/kai_loader.dart';
import '../../features/mascot/kai_mascot.dart';
import '../../features/mascot/kai_speech_bubble.dart';
import '../../services/streak/streak_service.dart';
import '../../services/widget/widget_service.dart';
import 'undo_provider.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/celebration_overlay.dart';
import 'widgets/evening_review_card.dart';
import 'widgets/morning_review_card.dart';
import 'widgets/progress_ring.dart';
import 'widgets/streak_row.dart';
import 'widgets/task_list.dart';
import '../plan/widgets/recurrence_providers.dart';

/// Все задачи на сегодня — раскрытые: конкретные строки дня + виртуальные
/// повторы серий (recurrence_providers). Якоря-шаблоны исключены из
/// watchTodayItems и появляются только как повторы. Реэкспортирует
/// expandedDayItemsProvider, сохраняя AsyncValue-API для экрана.
final todayItemsProvider =
    Provider.autoDispose<AsyncValue<List<ItemsTableData>>>((ref) {
  // Нормализуем до даты (без времени): иначе DateTime.now() меняется на каждом
  // ребилде и создаёт новый family-ключ → провайдер бесконечно «загружается».
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ref.watch(expandedDayItemsProvider(today));
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

    // Kai: определяем эмоцию по реальному состоянию дня.
    //
    // Приоритет проверок (сверху вниз — первое совпавшее побеждает):
    //   1. success  — все главные задачи закрыты.
    //   2. away     — ничего не запланировано на сегодня (empty day, пустой список).
    //   3. angry    — MoodLevel.angry → harsh (строгий режим полностью включён)
    //   4. stern    — MoodLevel.stern → anxious (слегка обеспокоенный)
    //   5. anxious  — есть просроченные pending main/important задачи СЕГОДНЯ.
    //   6. thinking — показан утренний/вечерний разбор.
    //   7. neutral  — иначе.
    final showKai = ref.watch(showKaiProvider);
    final moodLevel = ref.watch(effectiveMoodProvider).level;
    final overdueItems = ref.watch(overduePendingProvider).valueOrNull ??
        const <ItemsTableData>[];
    // Переиспользуем уже отслеживаемый itemsAsync — не добавляем лишних подписок.
    final allItems = itemsAsync.valueOrNull ?? const <ItemsTableData>[];

    // Задачи с просроченным временем сегодня (main|important, pending, scheduledAt < now)
    final overdueToday = allItems.where((i) =>
      (i.priority == 'main' || i.priority == 'important') &&
      i.status == 'pending' &&
      i.scheduledAt.isBefore(now),
    ).toList();

    // Показан ли утренний разбор (есть просроченные невыполненные из прошлых дней)?
    final morningReviewVisible = overdueItems.isNotEmpty;
    // Показан ли вечерний разбор (время >= 17:00)?
    final eveningReviewVisible = now.hour >= 17;
    // Пустой день — данные загрузились, но задач нет совсем
    final isEmptyDay = itemsAsync.hasValue && allItems.isEmpty;

    final KaiEmotion kaiEmotion;
    if (allMainDone) {
      kaiEmotion = KaiEmotion.success;
    } else if (isEmptyDay) {
      // away = «давно не заходил» / «день пуст» — глаза-нитки (MASCOT.md §6)
      kaiEmotion = KaiEmotion.away;
    } else if (moodLevel == MoodLevel.angry) {
      // Реактивное настроение: полностью сердитый режим → harsh
      kaiEmotion = KaiEmotion.harsh;
    } else if (moodLevel == MoodLevel.stern) {
      // Реактивное настроение: строгий режим → anxious
      kaiEmotion = KaiEmotion.anxious;
    } else if (overdueToday.isNotEmpty) {
      kaiEmotion = KaiEmotion.anxious;
    } else if (morningReviewVisible ||
        (eveningReviewVisible && mainItems.isNotEmpty &&
         mainItems.any((i) => i.status == 'pending'))) {
      kaiEmotion = KaiEmotion.thinking;
    } else {
      kaiEmotion = KaiEmotion.neutral;
    }

    final isTablet = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    if (isTablet) {
      return _buildTabletLayout(
          context, ref, itemsAsync, mainItems, tone, allMainDone, now,
          showKai: showKai, kaiEmotion: kaiEmotion,
          isEmptyDay: isEmptyDay, morningReviewVisible: morningReviewVisible,
          eveningReviewVisible: eveningReviewVisible, overdueItems: overdueItems);
    }
    return _buildMobileLayout(
        context, ref, itemsAsync, mainItems, tone, allMainDone, now,
        showKai: showKai, kaiEmotion: kaiEmotion,
        isEmptyDay: isEmptyDay, morningReviewVisible: morningReviewVisible,
        eveningReviewVisible: eveningReviewVisible, overdueItems: overdueItems);
  }

  /// Мобильный макет — одна колонка, оригинальный вид.
  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ItemsTableData>> itemsAsync,
    List<ItemsTableData> mainItems,
    AppTone tone,
    bool allMainDone,
    DateTime now, {
    required bool showKai,
    required KaiEmotion kaiEmotion,
    required bool isEmptyDay,
    required bool morningReviewVisible,
    required bool eveningReviewVisible,
    required List<ItemsTableData> overdueItems,
  }) {

    return Stack(
      children: [
        Scaffold(
          // Простой круглый FAB — только плюс-иконка, без текстовой подписи.
          // Текст-метка убрана (она сама начиналась с «+», давая двойной плюс).
          // tooltip обеспечивает доступность вместо видимой подписи.
          // Слева от него — постоянная кнопка ↩ (undo), видна только когда
          // есть что отменять (lastUndoableActionProvider != null).
          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _UndoFab(),
              const SizedBox(width: 12),
              FloatingActionButton(
                heroTag: 'today_add_fab',
                onPressed: () => showAddTaskSheet(context, day: now),
                tooltip: context.s('today.add_task_btn'),
                child: const Icon(Icons.add),
              ),
            ],
          ),
          body: itemsAsync.when(
            // Заменяем стандартный спиннер на KaiLoader (BOLD design system)
            loading: () => Center(
              child: KaiLoader(label: context.s('loading.tasks')),
            ),
            error: (err, _) => Center(
              child: Text(
                context.s('today.failed_to_load').replaceFirst('{err}', '$err'),
              ),
            ),
            data: (items) {
              return ListView(
                // 24dp горизонтальный отступ экрана (02-type-space.md §4.1: lg=24)
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                children: [
                  // Kai-шапка: маскот + приветствие + тумблер тона
                  _KaiHeaderSection(
                    now: now,
                    tone: tone,
                    showKai: showKai,
                    emotion: kaiEmotion,
                    isHarsh: tone == AppTone.harsh,
                    isEmptyDay: isEmptyDay,
                    morningReviewVisible: morningReviewVisible,
                    eveningReviewVisible: eveningReviewVisible,
                    overdueCount: overdueItems.length,
                    pendingCount: mainItems
                        .where((i) => i.status == 'pending')
                        .length,
                    allMainDone: allMainDone,
                  ),
                  // xl=32 между шапкой и кольцом (02-type-space.md §4.1)
                  const SizedBox(height: 32),
                  Center(child: ProgressRing(items: mainItems)),
                  // xl=32 между кольцом и streak-строкой
                  const SizedBox(height: 32),
                  const StreakRow(),
                  // Карточки обзора — после streak, с разделителем xl=32
                  const SizedBox(height: 32),
                  const MorningReviewCard(),
                  const EveningReviewCard(),
                  const SizedBox(height: 32),
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
  Widget _buildTabletLayout(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ItemsTableData>> itemsAsync,
    List<ItemsTableData> mainItems,
    AppTone tone,
    bool allMainDone,
    DateTime now, {
    required bool showKai,
    required KaiEmotion kaiEmotion,
    required bool isEmptyDay,
    required bool morningReviewVisible,
    required bool eveningReviewVisible,
    required List<ItemsTableData> overdueItems,
  }) {
    final items = itemsAsync.valueOrNull ?? const <ItemsTableData>[];

    return Stack(
      children: [
        Scaffold(
          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _UndoFab(),
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                heroTag: 'today_add_fab_tablet',
                onPressed: () => showAddTaskSheet(context, day: now),
                icon: const Icon(Icons.add),
                label: Text(context.s('today.fab_add')),
                // Тень для визуальной отдельности FAB от контента (тема: elevation=0)
                elevation: 4,
                focusElevation: 6,
                hoverElevation: 6,
              ),
            ],
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
                        _KaiHeaderSection(
                          now: now,
                          tone: tone,
                          showKai: showKai,
                          emotion: kaiEmotion,
                          isHarsh: tone == AppTone.harsh,
                          isEmptyDay: isEmptyDay,
                          morningReviewVisible: morningReviewVisible,
                          eveningReviewVisible: eveningReviewVisible,
                          overdueCount: overdueItems.length,
                          pendingCount: mainItems
                              .where((i) => i.status == 'pending')
                              .length,
                          allMainDone: allMainDone,
                        ),
                        const SizedBox(height: 32),
                        Center(child: ProgressRing(items: mainItems)),
                        const SizedBox(height: 32),
                        const StreakRow(),
                        const SizedBox(height: 32),
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

// ---------------------------------------------------------------------------
// _KaiHeaderSection — главная «лицевая» секция экрана Today.
// Kai увеличен до 104dp, центрирован над приветствием, речевой пузырь ниже.
// Тумблер тона — в углу строки, не мешает взгляду.
// ---------------------------------------------------------------------------

/// Полная шапка Today: Kai + речевой пузырь + приветствие + дата + тумблер тона.
///
/// Kai — визуальный «якорь» экрана (104dp); пузырь под ним транслирует текущий
/// контекст (KaiCopy по тону/состоянию). Приветствие + дата — слева, тумблер тона — справа.
class _KaiHeaderSection extends StatelessWidget {
  const _KaiHeaderSection({
    required this.now,
    required this.tone,
    required this.showKai,
    required this.emotion,
    required this.isHarsh,
    required this.isEmptyDay,
    required this.morningReviewVisible,
    required this.eveningReviewVisible,
    required this.overdueCount,
    required this.pendingCount,
    required this.allMainDone,
  });

  final DateTime now;
  final AppTone tone;
  final bool showKai;
  final KaiEmotion emotion;
  final bool isHarsh;
  final bool isEmptyDay;
  final bool morningReviewVisible;
  final bool eveningReviewVisible;
  final int overdueCount;
  final int pendingCount;
  final bool allMainDone;

  /// Строка для речевого пузыря в зависимости от контекста.
  String _bubbleMessage(BuildContext context) {
    if (allMainDone) return KaiCopy.allDone(context, tone);
    if (isEmptyDay) return KaiCopy.emptyDay(context, tone);
    if (morningReviewVisible) {
      return KaiCopy.morningReview(context, tone, overdueCount);
    }
    if (eveningReviewVisible && pendingCount > 0) {
      return KaiCopy.eveningReview(context, tone, pendingCount);
    }
    if (eveningReviewVisible && pendingCount == 0) {
      return KaiCopy.eveningReview(context, tone, 0);
    }
    return KaiCopy.idle(context, tone, now);
  }

  @override
  Widget build(BuildContext context) {
    final message = _bubbleMessage(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Верхняя строка: приветствие слева, тумблер тона справа
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Header(now: now)),
            const _ToneToggle(),
          ],
        ),

        const SizedBox(height: 20),

        // Kai — центральный, большой (104dp), с анимацией внимания
        if (showKai) ...[
          Center(
            child: _KaiHeader(
              emotion: emotion,
              isHarsh: isHarsh,
            ),
          ),
          // Речевой пузырь под Kai (tail снизу → хвостик указывает на Kai выше)
          const SizedBox(height: 4),
          Center(
            child: KaiSpeechBubble(
              message: message,
              animate: true,
              tail: KaiBubbleTail.bottomCenter,
              maxWidth: 260,
            ),
          ),
        ] else ...[
          // Kai отключён — пузырь всё равно показываем как обычный текст
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _UndoFab — постоянная кнопка ↩ слева от FAB «Add».
//
// Видна ТОЛЬКО когда есть обратимое действие (lastUndoableActionProvider != null) —
// чтобы не захламлять экран. Нажатие выполняет отмену через DAO (offline-first)
// и показывает краткое подтверждение снэкбаром.
// ---------------------------------------------------------------------------

class _UndoFab extends ConsumerWidget {
  const _UndoFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(lastUndoableActionProvider);
    // Нечего отменять — скрываем кнопку (prefer hidden, ТЗ).
    if (action == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // Приглушённый accent: undo вторичнее, чем основной add-FAB.
    final bg = ext?.surfaceElevated ?? colorScheme.surface;
    final fg = colorScheme.primary;

    return FloatingActionButton.small(
      heroTag: 'today_undo_fab',
      backgroundColor: bg,
      foregroundColor: fg,
      tooltip: context.s('today.undo_tooltip'),
      onPressed: () async {
        final dao = ref.read(itemsDaoProvider);
        final done =
            await ref.read(lastUndoableActionProvider.notifier).undo(dao);
        if (done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('today.undo_done'))),
          );
        }
      },
      child: const Icon(Icons.undo),
    );
  }
}

// ---------------------------------------------------------------------------
// _Header — приветствие + дата
// ---------------------------------------------------------------------------

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
    // textFaint для даты — tertiary, не конкурирует с приветствием
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // headlineLarge: 40sp, display-font (Fraunces/Newsreader/...) по 02-type-space.md §1
        Text(_greeting(context), style: textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          DateFormat.yMMMMEEEEd().format(now),
          style: textTheme.bodyMedium?.copyWith(color: ext?.textFaint),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ToneToggle — маленький тумблер тона gentle/harsh в углу шапки
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// _KaiHeader — маскот 104dp с анимацией «внимания» каждые ~6–10с
// ---------------------------------------------------------------------------

/// Большой Kai в шапке Today (104dp).
///
/// Помимо idle-анимации самого KaiMascot (дыхание / моргание / look),
/// здесь добавлена «attention» анимация: каждые 6–10 секунд Kai делает
/// небольшой bounce (вертикальный сдвиг −8px + обратно, 400мс, elasticOut).
/// Reduce-motion: attention bounce пропускается.
///
/// Tap micro-interaction: тап успокаивает Kai к neutral — это поведение
/// реализовано внутри самого KaiMascot, отдельный override здесь не нужен.
class _KaiHeader extends StatefulWidget {
  const _KaiHeader({
    required this.emotion,
    required this.isHarsh,
  });

  final KaiEmotion emotion;
  final bool isHarsh;

  @override
  State<_KaiHeader> createState() => _KaiHeaderState();
}

class _KaiHeaderState extends State<_KaiHeader>
    with SingleTickerProviderStateMixin {
  // --- Attention bounce ---
  late final AnimationController _attentionCtrl;
  late final Animation<double> _attentionY; // значение смещения Y (px)
  Timer? _attentionTimer;

  // Размер маскота в шапке — видный, выраженный
  static const double _kaiSize = 104;

  @override
  void initState() {
    super.initState();
    _attentionCtrl = AnimationController(
      vsync: this,
      // Slow (~400ms) — но это не UI-переход, а деко-движение, за пределами правила 300мс
      duration: const Duration(milliseconds: 420),
    );
    // Bounce вверх на 8px (отрицательный Y = вверх) и обратно через elasticOut
    _attentionY = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _attentionCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleAttention();
  }

  @override
  void dispose() {
    _attentionTimer?.cancel();
    _attentionCtrl.dispose();
    super.dispose();
  }

  /// Планирует следующий attention bounce через псевдослучайный интервал 6000–10000мс.
  void _scheduleAttention() {
    _attentionTimer?.cancel();
    // Детерминированный «случайный» интервал: зависит от текущего времени
    final phase = DateTime.now().millisecondsSinceEpoch & 0x3FFF;
    final delayMs = 6000 + (phase % 4000); // 6000–9999 мс
    _attentionTimer = Timer(Duration(milliseconds: delayMs), _doAttention);
  }

  /// Проигрывает один attention bounce: вверх → обратно, затем планирует следующий.
  Future<void> _doAttention() async {
    if (!mounted) return;
    final reduce = reduceMotionOf(context);
    if (!reduce) {
      // forward (0→1): идём вверх с elasticOut (перелёт + возврат встроен в кривую)
      await _attentionCtrl.forward(from: 0);
      await _attentionCtrl.reverse();
    }
    if (mounted) _scheduleAttention();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _attentionY,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _attentionY.value),
          child: child,
        );
      },
      // Тап по Kai успокаивает его к neutral — логика внутри KaiMascot.
      child: KaiMascot(
        size: _kaiSize,
        emotion: widget.emotion,
        isHarsh: widget.isHarsh,
      ),
    );
  }
}
