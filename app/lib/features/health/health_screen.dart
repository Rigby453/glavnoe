// Экран Health — хаб здоровья.
// Kaname redesign (Phase 5): §4.2 cards (surface1+hairline+R14), Phosphor icons,
// displaySmall header, tablet 2-col preserved.
// Вся бизнес-логика (провайдеры/Drift/уведомления) без изменений.

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../core/animations/app_toast.dart';
import '../../core/animations/constants.dart';
import '../../services/notifications/notification_service.dart'
    show nextInstanceAfterNow;
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart'; // S.all — для локализации уведомлений без context
import '../../core/settings/feature_modes_provider.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/widgets/kai_loader.dart';
import 'sleep_stats.dart';

/// Единый набор быстрых объёмов воды (мл) — карточка Здоровья и полный экран.
const kWaterQuickMl = [150, 250, 350, 500];

/// Диалог «Своё количество» — ввод произвольного объёма воды.
Future<void> showCustomWaterDialog(BuildContext context, dynamic dao) async {
  final ctrl = TextEditingController();
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.s('water.custom_amount_title')),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(
          hintText: ctx.s('water.custom_amount_hint'),
          suffixText: 'ml',
        ),
        onSubmitted: (_) {
          final v = int.tryParse(ctrl.text.trim());
          if (v != null && v > 0 && v <= 5000) Navigator.pop(ctx, v);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.s('btn.cancel')),
        ),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(ctrl.text.trim());
            if (v != null && v > 0 && v <= 5000) Navigator.pop(ctx, v);
          },
          child: Text(ctx.s('btn.ok')),
        ),
      ],
    ),
  );
  ctrl.dispose();
  if (result != null) await dao.addWater(result);
}

/// Сумма выпитого за сегодня (реактивно).
final todayWaterProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(waterDaoProvider).watchTodayTotalMl(DateTime.now());
});

/// Суммы по дням за последние 7 дней (индекс 6 — сегодня), реактивно.
final weekWaterProvider = StreamProvider.autoDispose<List<int>>((ref) {
  return ref.watch(waterDaoProvider).watchDailyTotals(DateTime.now(), 7);
});

/// Открытая ночь (endAt == null), реактивно.
final openNightProvider = StreamProvider.autoDispose<SleepLogsTableData?>((ref) {
  return ref.watch(sleepDaoProvider).watchOpenNight();
});

/// Завершённые ночи за последние 7 дней, реактивно.
final recentNightsProvider =
    StreamProvider.autoDispose<List<SleepLogsTableData>>((ref) {
  return ref.watch(sleepDaoProvider).watchRecentNights(7);
});

/// Провайдер напоминаний о воде — включить/выключить расписание уведомлений.
final waterReminderProvider =
    StateNotifierProvider<WaterReminderNotifier, bool>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return WaterReminderNotifier(prefs);
});

class WaterReminderNotifier extends StateNotifier<bool> {
  WaterReminderNotifier(this._prefs)
      : super(_prefs.getBool('water_reminders') ?? false);
  final SharedPreferences _prefs;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _baseId = 400;

  /// Резолвит строку по ключу из S.all, используя локаль из SharedPreferences.
  /// Ключ 'app_locale' совпадает с locale_provider.dart (_kLocaleKey).
  String _ls(String key) {
    final tag = _prefs.getString('app_locale') ?? 'en';
    final entry = S.all[key];
    if (entry == null) return key;
    final langCode = tag.split('-').first;
    return entry[tag] ?? entry[langCode] ?? entry['en'] ?? key;
  }

  Future<void> toggle(bool value) async {
    state = value;
    await _prefs.setBool('water_reminders', value);
    if (value) {
      await _schedule();
    } else {
      await _cancel();
    }
  }

  Future<void> _schedule() async {
    await _cancel();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'kaizen_water',
        'Water reminders',
        channelDescription: 'Hydration reminders every 2 hours',
        importance: Importance.low,
        priority: Priority.low,
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (var i = 0; i < 8; i++) {
      final hour = 8 + i * 2;
      final scheduled = _nextInstance(hour);
      await _plugin.zonedSchedule(
        id: _baseId + i,
        title: _ls('health.water_reminder_title'),
        body: _ls('health.water_reminder_body'),
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _cancel() async {
    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(id: _baseId + i);
    }
  }

  // Делегирует единой функции nextInstanceAfterNow: гарантирует строгое
  // будущее (включая кейс t == now, который isBefore пропускал).
  tz.TZDateTime _nextInstance(int hour) =>
      nextInstanceAfterNow(hour, 0, tz.TZDateTime.now(tz.local));
}

// ---------------------------------------------------------------------------
// §4.2 card: surface1 + 0.5dp hairline + R14, no shadow.
// ---------------------------------------------------------------------------

class _KaCard extends StatelessWidget {
  const _KaCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: ext.border, width: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// HealthScreen — 4-секционный хаб: Nutrition / Sleep / Mind / Movement.
// ---------------------------------------------------------------------------

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.tablet) {
          return _buildTabletLayout(context, ref);
        }
        return _buildMobileLayout(context, ref);
      },
    );
  }

  /// Mobile: единая колонка.
  Widget _buildMobileLayout(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final total = ref.watch(todayWaterProvider).valueOrNull ?? 0;
    final waterGoalMl = ref.watch(waterGoalProvider);
    final progress = (total / waterGoalMl).clamp(0.0, 1.0);
    final dao = ref.read(waterDaoProvider);

    final waterOn = ref.watch(waterModeProvider);
    final nutritionOn = ref.watch(nutritionModeProvider);
    final workoutOn = ref.watch(workoutModeProvider);
    final meditationOn = ref.watch(meditationLibraryModeProvider);
    final breathingOn = ref.watch(breathingEditorModeProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
      children: [
        // displaySmall — спокойный, не кричащий заголовок хаба
        Text(context.s('health.title'), style: textTheme.displaySmall),

        // ── NUTRITION ──────────────────────────────────────────────────────
        // Water и Food — опциональные модули (#17/#владелец): секция целиком
        // скрыта, если ОБА выключены. Сон — единственный всегда видимый модуль.
        if (waterOn || nutritionOn) ...[
          _HealthSectionHeader(labelKey: 'health.section_nutrition'),
          if (waterOn)
            _buildWaterCard(context, ref, textTheme, total, waterGoalMl, progress, dao),
          if (waterOn && nutritionOn) const SizedBox(height: 8),
          if (nutritionOn)
            _HealthModuleTile(
              titleKey: 'health.food',
              subtitleKey: 'health.food_subtitle',
              icon: PhosphorIcons.forkKnife(),
              route: '/food',
            ),
        ],

        // ── SLEEP ──────────────────────────────────────────────────────────
        _HealthSectionHeader(labelKey: 'health.section_sleep'),
        const _SleepCard(),

        // ── MIND ───────────────────────────────────────────────────────────
        // #19: единая плитка «Практики» — ведёт на объединённый экран с
        // вкладками Медитация/Дыхание (mind_screen.dart). Секция целиком
        // скрыта, если ОБА флага выключены.
        if (meditationOn || breathingOn) ...[
          _HealthSectionHeader(labelKey: 'health.section_mind'),
          _HealthModuleTile(
            titleKey: 'health.mind_practices',
            subtitleKey: 'health.mind_practices_subtitle',
            icon: PhosphorIcons.flowerLotus(),
            route: '/mind',
          ),
        ],

        // ── MOVEMENT ───────────────────────────────────────────────────────
        // Опциональный модуль (#17): выключен → секция целиком скрыта.
        if (workoutOn) ...[
          _HealthSectionHeader(labelKey: 'health.section_movement'),
          _HealthModuleTile(
            titleKey: 'health.workouts',
            subtitleKey: 'health.workouts_subtitle',
            icon: PhosphorIcons.barbell(),
            route: '/workouts',
          ),
        ],

        const SizedBox(height: 16),
        _ManageModulesRow(),
      ],
    );
  }

  /// Tablet: 2-col (Nutrition+Sleep / Mind+Movement).
  Widget _buildTabletLayout(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final total = ref.watch(todayWaterProvider).valueOrNull ?? 0;
    final waterGoalMl = ref.watch(waterGoalProvider);
    final progress = (total / waterGoalMl).clamp(0.0, 1.0);
    final dao = ref.read(waterDaoProvider);

    final waterOn = ref.watch(waterModeProvider);
    final nutritionOn = ref.watch(nutritionModeProvider);
    final workoutOn = ref.watch(workoutModeProvider);
    final meditationOn = ref.watch(meditationLibraryModeProvider);
    final breathingOn = ref.watch(breathingEditorModeProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(context.s('health.title'), style: textTheme.displaySmall),
        const SizedBox(height: 8),

        // ── NUTRITION + SLEEP side by side ─────────────────────────────────
        // Water и Food — опциональные модули (#17/#владелец): выключены →
        // ничего не рендерится. Включаются только в Profile → Behavior.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (waterOn || nutritionOn) ...[
                    _HealthSectionHeader(labelKey: 'health.section_nutrition'),
                    if (waterOn)
                      _buildWaterCard(
                        context, ref, textTheme, total, waterGoalMl, progress, dao,
                      ),
                    if (waterOn && nutritionOn) const SizedBox(height: 8),
                    if (nutritionOn)
                      _HealthModuleTile(
                        titleKey: 'health.food',
                        subtitleKey: 'health.food_subtitle',
                        icon: PhosphorIcons.forkKnife(),
                        route: '/food',
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HealthSectionHeader(labelKey: 'health.section_sleep'),
                  const _SleepCard(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── MIND + MOVEMENT side by side ───────────────────────────────────
        // Опциональные модули (#17): секция целиком скрыта, когда выключена
        // (для Mind — когда выключены ОБА: meditation и breathing).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // #19: единая плитка «Практики» вместо двух — см. mobile.
                  if (meditationOn || breathingOn) ...[
                    _HealthSectionHeader(labelKey: 'health.section_mind'),
                    _HealthModuleTile(
                      titleKey: 'health.mind_practices',
                      subtitleKey: 'health.mind_practices_subtitle',
                      icon: PhosphorIcons.flowerLotus(),
                      route: '/mind',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (workoutOn) ...[
                    _HealthSectionHeader(labelKey: 'health.section_movement'),
                    _HealthModuleTile(
                      titleKey: 'health.workouts',
                      subtitleKey: 'health.workouts_subtitle',
                      icon: PhosphorIcons.barbell(),
                      route: '/workouts',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _ManageModulesRow(),
      ],
    );
  }

  /// Карточка трекера воды — делегирует в _WaterCard (StatefulWidget для expand-логики).
  Widget _buildWaterCard(
    BuildContext context,
    WidgetRef ref,
    TextTheme textTheme,
    int total,
    int waterGoalMl,
    double progress,
    dynamic dao,
  ) {
    return _WaterCard(
      total: total,
      waterGoalMl: waterGoalMl,
      progress: progress,
      dao: dao,
    );
  }
}

// ---------------------------------------------------------------------------
// _WaterCard — §4.2 карточка трекера воды со сворачиваемыми пресетами.
// Тап по зоне стакана/прогресса — toggle пресетов объёма.
// Кнопки-пресеты добавляют воду, не сворачивают панель.
// ---------------------------------------------------------------------------

class _WaterCard extends ConsumerStatefulWidget {
  const _WaterCard({
    required this.total,
    required this.waterGoalMl,
    required this.progress,
    required this.dao,
  });

  final int total;
  final int waterGoalMl;
  final double progress;
  final dynamic dao;

  @override
  ConsumerState<_WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends ConsumerState<_WaterCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return _KaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок: drop icon + метрика + кнопка полного экрана
          Row(
            children: [
              Icon(PhosphorIcons.drop(), color: ext.textMuted, size: 20),
              const SizedBox(width: 8),
              Text(context.s('health.water'), style: textTheme.titleMedium),
              const Spacer(),
              Flexible(
                child: Text(
                  '${widget.total} / ${widget.waterGoalMl} ml',
                  style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  PhosphorIcons.arrowSquareOut(),
                  size: 18,
                  color: ext.textMuted,
                ),
                tooltip: context.s('health.water_full_view'),
                onPressed: () => context.push('/water'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Тап-зона: стакан + прогресс → toggle пресетов.
          // GestureDetector + HitTestBehavior.opaque чтобы тап по пустому пространству тоже срабатывал.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                _AnimatedWaterGlass(progress: widget.progress),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.total} ml',
                        style: textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        context.s('health.water_goal_of')
                            .replaceFirst('{goal}', '${widget.waterGoalMl}'),
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: widget.progress,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 4),
                      // Мелкая подсказка о тап-зоне
                      Text(
                        context.s(_expanded
                            ? 'water.hint_collapse'
                            : 'water.hint_tap_to_add'),
                        style: textTheme.labelSmall
                            ?.copyWith(color: ext.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Анимированно раскрывающиеся пресеты объёма.
          // AnimatedSize обеспечивает плавное появление/скрытие (kDurationNormal).
          // Кнопки пресетов добавляют воду — НЕ сворачивают панель.
          AnimatedSize(
            duration: effectiveDuration(context, kDurationNormal),
            curve: kCurveLift,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...kWaterQuickMl.map(
                          (ml) => OutlinedButton(
                            onPressed: () => widget.dao.addWater(ml),
                            child: Text(
                              context
                                  .s('water.add_ml_fmt')
                                  .replaceFirst('{ml}', '$ml'),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: Icon(PhosphorIcons.pencilSimple(), size: 16),
                          label: Text(context.s('water.custom_btn')),
                          onPressed: () =>
                              showCustomWaterDialog(context, widget.dao),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Undo — справа
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: context.s('health.water_undo'),
              icon: Icon(
                PhosphorIcons.arrowCounterClockwise(),
                color: ext.textMuted,
              ),
              onPressed: () => widget.dao.undoLast(DateTime.now()),
            ),
          ),
          const SizedBox(height: 4),

          // Тоггл напоминаний
          Row(
            children: [
              Icon(PhosphorIcons.bell(), size: 16, color: ext.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.s('health.water_reminders'),
                  style: textTheme.bodySmall,
                ),
              ),
              Switch.adaptive(
                value: ref.watch(waterReminderProvider),
                onChanged: (v) =>
                    ref.read(waterReminderProvider.notifier).toggle(v),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Мини-график 7 дней — нажимаемая зона → отчёт
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push('/water-report'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: _WeekWaterChart(goalMl: widget.waterGoalMl)),
                  Icon(
                    PhosphorIcons.caretRight(),
                    size: 18,
                    color: ext.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HealthSectionHeader — мутированный заголовок тематической секции.
// ---------------------------------------------------------------------------

class _HealthSectionHeader extends StatelessWidget {
  const _HealthSectionHeader({required this.labelKey});
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        context.s(labelKey),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: ext.textMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HealthModuleTile — §4.2 object card.
//
// Только nav card (caretRight, Material+InkWell для ripple) — рендерится ТОЛЬКО
// когда модуль включён в Profile → Behavior (feature_modes_provider.dart).
// Выключенные модули в Health не отображаются вообще (#17): нет карточки,
// нет инлайн-тумблера. Включить модуль можно только через Profile → Behavior
// (см. _ManageModulesRow ниже) — это единственный источник истины для тумблеров.
// ---------------------------------------------------------------------------

class _HealthModuleTile extends StatelessWidget {
  const _HealthModuleTile({
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.route,
  });

  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final surface = Theme.of(context).colorScheme.surface;

    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ext.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: ext.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.s(titleKey),
                      style: textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.s(subtitleKey),
                      style: textTheme.bodySmall?.copyWith(
                        color: ext.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(PhosphorIcons.caretRight(), size: 16, color: ext.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ManageModulesRow — ссылка на Profile → Behavior.
// ---------------------------------------------------------------------------

class _ManageModulesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/profile/behavior'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(PhosphorIcons.slidersHorizontal(), size: 18, color: ext.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.s('health.manage_modules'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ext.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(PhosphorIcons.caretRight(), size: 16, color: ext.textMuted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AnimatedWaterGlass — анимированный стакан воды (бизнес-логика не изменена).
// ---------------------------------------------------------------------------

class _AnimatedWaterGlass extends StatefulWidget {
  const _AnimatedWaterGlass({required this.progress});
  final double progress;

  @override
  State<_AnimatedWaterGlass> createState() => _AnimatedWaterGlassState();
}

class _AnimatedWaterGlassState extends State<_AnimatedWaterGlass>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // MediaQuery.of(context) нельзя в initState — читаем в didChangeDependencies.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    _ctrl.duration =
        reduce ? Duration.zero : const Duration(milliseconds: 600);
    if (!_started) {
      _started = true;
      _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedWaterGlass old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      if (old.progress < 1.0 && widget.progress >= 1.0) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            showAppToast(
              context,
              variant: AppToastVariant.done,
              message: context.s('health.water_goal_reached'),
            );
          }
        });
      }
      _anim = Tween<double>(begin: _anim.value, end: widget.progress).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      );
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: context.s('health.water_goal_reached'),
      triggerMode: widget.progress >= 1.0
          ? TooltipTriggerMode.tap
          : TooltipTriggerMode.manual,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (ctx, _) => CustomPaint(
          size: const Size(56, 72),
          painter: _GlassPainter(fill: _anim.value, color: color),
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter({required this.fill, required this.color});
  final double fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final glassPath = Path()
      ..moveTo(w * 0.1, 0)
      ..lineTo(w * 0.9, 0)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.22, h)
      ..close();

    final waterTop = h * (1 - fill.clamp(0.0, 1.0));
    final waterPath = Path()
      ..moveTo(w * 0.1 + (w * 0.12) * (waterTop / h), waterTop)
      ..lineTo(w * 0.9 - (w * 0.12) * (waterTop / h), waterTop)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.22, h)
      ..close();

    canvas.drawPath(
      waterPath,
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      glassPath,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (fill > 0.02) {
      canvas.drawLine(
        Offset(w * 0.1 + (w * 0.12) * (waterTop / h) + 2, waterTop),
        Offset(w * 0.9 - (w * 0.12) * (waterTop / h) - 2, waterTop),
        Paint()
          ..color = color.withValues(alpha: 0.7)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill || old.color != color;
}

// ---------------------------------------------------------------------------
// _WeekWaterChart — мини-график воды за 7 дней.
// День недели через DateFormat (локализовано).
// ---------------------------------------------------------------------------

class _WeekWaterChart extends ConsumerWidget {
  const _WeekWaterChart({required this.goalMl});
  final int goalMl;

  static const _chartHeight = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(weekWaterProvider).valueOrNull;
    if (totals == null || totals.length != 7) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();
    final locale = Localizations.localeOf(context).toString();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final day = today.subtract(Duration(days: 6 - i));
        final frac = goalMl <= 0 ? 0.0 : (totals[i] / goalMl).clamp(0.0, 1.0);
        final isToday = i == 6;
        final reached = totals[i] >= goalMl && goalMl > 0;
        // Локализованная узкая аббревиатура дня недели (EEEEE = 'M','T','W'…)
        final dayLetter = DateFormat('EEEEE', locale).format(day);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: (_chartHeight * frac).clamp(3.0, _chartHeight),
                  decoration: BoxDecoration(
                    color: reached
                        ? colorScheme.primary
                        : ext.textMuted.withValues(
                            alpha: isToday ? 0.55 : 0.30,
                          ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dayLetter,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight:
                        isToday ? FontWeight.w600 : FontWeight.w400,
                    color: isToday ? ext.textMuted : ext.textFaint,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// _SleepCard — §4.2 карточка трекера сна.
// ---------------------------------------------------------------------------

class _SleepCard extends ConsumerWidget {
  const _SleepCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final openAsync = ref.watch(openNightProvider);
    final dao = ref.read(sleepDaoProvider);

    return _KaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.moon(), color: ext.textMuted, size: 20),
              const SizedBox(width: 8),
              Text(context.s('health.sleep'), style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          openAsync.when(
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: KaiLoader(label: context.s('loading.sleep')),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (open) {
              if (open != null) {
                final timeStr =
                    TimeOfDay.fromDateTime(open.startAt).format(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${context.s('health.sleep_sleeping_since')} $timeStr',
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: Icon(PhosphorIcons.sun()),
                      label: Text(context.s('health.sleep_im_awake')),
                      onPressed: () async {
                        await dao.endNight();
                        final dur =
                            DateTime.now().difference(open.startAt);
                        final h = dur.inHours;
                        final m = dur.inMinutes % 60;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context
                                    .s('health.sleep_night_logged')
                                    .replaceAll('{h}', '$h')
                                    .replaceAll('{m}', '$m'),
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                );
              }

              // Ночи нет — кнопка «Ложусь спать» + недельный график
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    icon: Icon(PhosphorIcons.moon(PhosphorIconsStyle.fill)),
                    label: Text(context.s('health.sleep_going_to_bed')),
                    onPressed: () => dao.startNight(),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push('/sleep-report'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: _WeekSleepChart(goalHours: 7)),
                          Icon(
                            PhosphorIcons.caretRight(),
                            size: 18,
                            color: ext.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WeekSleepChart — мини-график сна за 7 дней (аналог _WeekWaterChart).
// ---------------------------------------------------------------------------

class _WeekSleepChart extends ConsumerWidget {
  const _WeekSleepChart({required this.goalHours});
  final double goalHours;

  static const _chartHeight = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nights = ref.watch(recentNightsProvider).valueOrNull;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();
    final locale = Localizations.localeOf(context).toString();

    if (nights == null) return const SizedBox.shrink();
    if (nights.isEmpty) {
      return Text(
        context.s('health.sleep_no_nights'),
        style: textTheme.bodySmall,
      );
    }

    final slots = nightlyHours(nights, today, 7);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final slot = slots[i];
        final frac = goalHours <= 0
            ? 0.0
            : (slot.hours / goalHours).clamp(0.0, 1.0);
        final isToday = i == 6;
        final reached = slot.hours >= goalHours && goalHours > 0;
        final dayLetter = DateFormat('EEEEE', locale).format(slot.day);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: (_chartHeight * frac).clamp(3.0, _chartHeight),
                  decoration: BoxDecoration(
                    color: reached
                        ? colorScheme.primary
                        : ext.textMuted.withValues(
                            alpha: isToday ? 0.55 : 0.30,
                          ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dayLetter,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight:
                        isToday ? FontWeight.w600 : FontWeight.w400,
                    color: isToday ? ext.textMuted : ext.textFaint,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
