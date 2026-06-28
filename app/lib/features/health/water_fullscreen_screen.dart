// Полноэкранный трекер воды: большой анимированный стакан, быстрые кнопки,
// настройка напоминаний и переход к истории.
// Redesign «Kaname» §G: Phosphor, §4.2 flat cards, unified button set,
// локализованный прогресс без хардкода 'of'.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database_providers.dart' show waterDaoProvider;
import '../../core/l10n/app_strings.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import 'health_screen.dart'
    show
        todayWaterProvider,
        waterReminderProvider,
        kWaterQuickMl,
        showCustomWaterDialog;

class WaterFullscreenScreen extends ConsumerWidget {
  const WaterFullscreenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(todayWaterProvider).valueOrNull ?? 0;
    final goal = ref.watch(waterGoalProvider);
    final progress = (total / goal).clamp(0.0, 1.0);
    final dao = ref.read(waterDaoProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // ThemeExtension — textMuted / border без хардкода hex
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final percent = (progress * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('water.title')),
        actions: [
          IconButton(
            // Phosphor: chartLine → отчёт/история (confirmed in icon-map)
            icon: Icon(PhosphorIcons.chartLine()),
            tooltip: context.s('water.history_tooltip'),
            onPressed: () => context.push('/water-report'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // 24dp горизонтальные поля, 16dp сверху — §1 screen padding
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Большой анимированный стакан — занимает ~32% высоты экрана
              _BigWaterGlass(
                progress: progress,
                totalMl: total,
                goalMl: goal,
              ),
              const SizedBox(height: 12),

              // Hero-процент — displayMedium, accent (единственная первичная метрика)
              Text(
                '$percent%',
                style: textTheme.displayMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              // Подпись «N из M мл» — локаль-aware (water.progress_fmt)
              Text(
                context
                    .s('water.progress_fmt')
                    .replaceFirst('{total}', '$total')
                    .replaceFirst('{goal}', '$goal'),
                style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
              ),
              const SizedBox(height: 32),

              // Сетка быстрых кнопок (2×2) — OutlinedButton (повторяемые действия §4.3).
              // kWaterQuickMl = [150, 250, 350, 500] — единый набор с карточкой Health.
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                // 2.4 → ~55dp при 320px, ~65dp при 375px — выше минимума 52dp §4.3
                childAspectRatio: 2.4,
                children: kWaterQuickMl.map((ml) {
                  return OutlinedButton(
                    onPressed: () => dao.addWater(ml),
                    child: Text(
                      // Локаль-aware «+N мл» через шаблон (не конкатенация с EN)
                      context
                          .s('water.add_ml_fmt')
                          .replaceFirst('{ml}', '$ml'),
                      style: textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              // «Своё количество» — полная ширина, Phosphor pencilSimple
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(PhosphorIcons.pencilSimple(), size: 18),
                  label: Text(context.s('water.custom_btn')),
                  onPressed: () => showCustomWaterDialog(context, dao),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Undo — выровнено по левому краю, Phosphor arrowCounterClockwise
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: Icon(PhosphorIcons.arrowCounterClockwise(), size: 16),
                  label: Text(context.s('water.undo_last')),
                  onPressed: () => dao.undoLast(DateTime.now()),
                ),
              ),
              const SizedBox(height: 20),

              // Подсказка про напитки из Food — §4.2 flat card (surface1 + hairline + R14)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ext.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    // Phosphor info — нейтральная иконка (textMuted)
                    Icon(PhosphorIcons.info(), size: 16, color: ext.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.s('water.food_tip'),
                        style: textTheme.bodySmall?.copyWith(
                          color: ext.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Напоминания — §4.2 flat card с SwitchListTile.adaptive
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ext.border, width: 0.5),
                ),
                child: SwitchListTile.adaptive(
                  // Phosphor bell — нейтральный (не accent)
                  secondary: Icon(PhosphorIcons.bell(), color: ext.textMuted),
                  title: Text(
                    context.s('water.drink_reminders'),
                    style: textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    context.s('water.reminders_subtitle'),
                    style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                  ),
                  value: ref.watch(waterReminderProvider),
                  onChanged: (v) =>
                      ref.read(waterReminderProvider.notifier).toggle(v),
                ),
              ),
              // Нижний отступ для Scaffold FAB / NavBar
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Большой анимированный стакан (~32% высоты экрана)
// Поддерживает reduce-motion: при disableAnimations → мгновенный переход.
// ---------------------------------------------------------------------------

class _BigWaterGlass extends StatefulWidget {
  const _BigWaterGlass({
    required this.progress,
    required this.totalMl,
    required this.goalMl,
  });

  final double progress;
  final int totalMl;
  final int goalMl;

  @override
  State<_BigWaterGlass> createState() => _BigWaterGlassState();
}

class _BigWaterGlassState extends State<_BigWaterGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // MediaQuery.of(context) нельзя в initState — читаем в didChangeDependencies
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    _ctrl.duration =
        reduce ? Duration.zero : const Duration(milliseconds: 600);
    if (!_started) {
      _started = true;
      _ctrl.animateTo(widget.progress);
    }
  }

  @override
  void didUpdateWidget(_BigWaterGlass old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
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
    // Стакан — accent цвет (единственная первичная метрика §ACCENT DISCIPLINE)
    final color = Theme.of(context).colorScheme.primary;
    final screenH = MediaQuery.of(context).size.height;
    final glassH = screenH * 0.32;
    final glassW = glassH * 0.65;

    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) => CustomPaint(
        size: Size(glassW, glassH),
        painter: _BigGlassPainter(fill: _anim.value, color: color),
      ),
    );
  }
}

class _BigGlassPainter extends CustomPainter {
  const _BigGlassPainter({required this.fill, required this.color});
  final double fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Форма стакана (трапеция, шире сверху)
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

    // Заливка воды — 35% прозрачности (мягко)
    canvas.drawPath(
      waterPath,
      Paint()..color = color.withValues(alpha: 0.35),
    );
    // Контур стакана — 60%
    canvas.drawPath(
      glassPath,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Линия поверхности воды — 70%
    if (fill > 0.02) {
      canvas.drawLine(
        Offset(w * 0.1 + (w * 0.12) * (waterTop / h) + 2, waterTop),
        Offset(w * 0.9 - (w * 0.12) * (waterTop / h) - 2, waterTop),
        Paint()
          ..color = color.withValues(alpha: 0.7)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_BigGlassPainter old) =>
      old.fill != fill || old.color != color;
}
