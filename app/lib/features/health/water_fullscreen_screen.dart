// Полноэкранный трекер воды: большой анимированный стакан, быстрые кнопки,
// настройка напоминаний и переход к истории.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database_providers.dart' show waterDaoProvider;
import '../../core/l10n/app_strings.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import 'health_screen.dart' show todayWaterProvider, waterReminderProvider;

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
    // ThemeExtension для textMuted / border / success (без хардкода hex)
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final percent = (progress * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('water.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: context.s('water.history_tooltip'),
            onPressed: () => context.push('/water-report'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // 24dp горизонтальные поля, 16dp сверху — §4.1
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Большой анимированный стакан с поддержкой reduce-motion
              _BigWaterGlass(
                progress: progress,
                totalMl: total,
                goalMl: goal,
              ),
              const SizedBox(height: 12),

              // Hero-процент — displayMedium (40sp, display font, w700)
              // Accent только на первичную метрику прогресса (§1 ACCENT DISCIPLINE)
              Text(
                '$percent%',
                style: textTheme.displayMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              // Детальная цифра — bodyMedium + textMuted
              Text(
                '$total of $goal ml',
                style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
              ),
              const SizedBox(height: 32),

              // Быстрые кнопки добавления: OutlinedButton — повторяемые низкорисковые
              // действия (§2 BUTTON HIERARCHY — «+250 ml» / «+500 ml» pattern)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.8,
                children: [150, 200, 250, 350].map((ml) {
                  return OutlinedButton(
                    onPressed: () => dao.addWater(ml),
                    child: Text(
                      '+$ml ml',
                      style: textTheme.labelLarge,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),

              // Undo — TextButton (tertiary navigation nudge, §2)
              TextButton.icon(
                icon: const Icon(Icons.undo, size: 16),
                label: Text(context.s('water.undo_last')),
                onPressed: () => dao.undoLast(DateTime.now()),
              ),
              const SizedBox(height: 20),

              // Подсказка про напитки из Food — Card (surface + border)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        // Иконка нейтральная — textMuted (не accent)
                        color: ext.textMuted,
                      ),
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
              ),
              const SizedBox(height: 16),

              // Напоминания — Card + SwitchListTile
              Card(
                child: SwitchListTile.adaptive(
                  secondary: Icon(
                    Icons.notifications_outlined,
                    // Иконка напоминаний нейтральная — не accent
                    color: ext.textMuted,
                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}

// Большой стакан на ~32% высоты экрана с анимацией заполнения.
// Поддерживает reduce-motion: при disableAnimations → мгновенное отображение.
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

  @override
  void initState() {
    super.initState();
    // Уважаем reduce-motion: при disableAnimations → duration=0
    final reduce = MediaQuery.of(context).disableAnimations;
    _ctrl = AnimationController(
      vsync: this,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.animateTo(widget.progress);
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
    // Стакан рисуется accent-цветом — это единственная первичная метрика
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
        ..strokeWidth = 3,
    );
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
