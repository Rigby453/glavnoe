// Фирменный момент (ТЗ B4): конфетти, когда ВСЕ главные задачи дня закрыты.
// Самодостаточно: следит за main-задачами через Drift, на переходе
// "не всё закрыто" → "всё закрыто" один раз проигрывает падающее конфетти.
// Слой не перехватывает тапы (IgnorePointer) и ничего не рисует в покое.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';

/// Main-задачи на сегодня (отдельный поток для слоя празднования).
final _celebrationMainItemsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchMainItems(DateTime.now());
});

/// Полноэкранный слой поверх Today. Вешается в Stack над Scaffold.
class CelebrationOverlay extends ConsumerStatefulWidget {
  const CelebrationOverlay({super.key});

  @override
  ConsumerState<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends ConsumerState<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  // null = ещё не знаем базовое состояние (не палим конфетти на первом кадре).
  bool? _wasAllDone;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isAllDone(List<ItemsTableData> mains) =>
      mains.isNotEmpty &&
      mains.every((i) => i.status == 'done' || i.status == 'skipped');

  void _celebrate(ColorScheme scheme) {
    _particles
      ..clear()
      ..addAll(_buildParticles(scheme));
    _controller.forward(from: 0);
  }

  List<_Particle> _buildParticles(ColorScheme scheme) {
    final colors = <Color>[
      scheme.primary,
      scheme.secondary,
      const Color(0xFFFFD166),
      const Color(0xFF06D6A0),
      const Color(0xFFEF476F),
    ];
    return List.generate(36, (_) {
      return _Particle(
        startX: _random.nextDouble(),
        color: colors[_random.nextInt(colors.length)],
        width: 6 + _random.nextDouble() * 6,
        height: 8 + _random.nextDouble() * 8,
        swayAmplitude: 12 + _random.nextDouble() * 28,
        swayFrequency: 2 + _random.nextDouble() * 3,
        phase: _random.nextDouble() * pi * 2,
        rotations: 1 + _random.nextDouble() * 3,
        fallDelay: _random.nextDouble() * 0.25,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Следим за main-задачами и ловим переход в "всё закрыто".
    final mains = ref.watch(_celebrationMainItemsProvider).valueOrNull;
    if (mains != null) {
      final allDone = _isAllDone(mains);
      final prev = _wasAllDone;
      _wasAllDone = allDone;
      // Палим конфетти только на переходе false→true (не на первом кадре).
      if (prev == false && allDone) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _celebrate(scheme);
        });
      }
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isDismissed || _particles.isEmpty) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

/// Одна частица конфетти.
class _Particle {
  const _Particle({
    required this.startX,
    required this.color,
    required this.width,
    required this.height,
    required this.swayAmplitude,
    required this.swayFrequency,
    required this.phase,
    required this.rotations,
    required this.fallDelay,
  });

  final double startX; // 0..1 доля ширины
  final Color color;
  final double width;
  final double height;
  final double swayAmplitude; // px горизонтального покачивания
  final double swayFrequency;
  final double phase;
  final double rotations; // оборотов за анимацию
  final double fallDelay; // 0..1 задержка старта падения
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Локальный прогресс с учётом задержки старта.
      final local = ((progress - p.fallDelay) / (1 - p.fallDelay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final eased = Curves.easeIn.transform(local);
      final y = -20 + (size.height + 40) * eased;
      final x = p.startX * size.width +
          sin(local * p.swayFrequency * pi * 2 + p.phase) * p.swayAmplitude;

      // Затухание ближе к концу.
      final opacity = local < 0.8 ? 1.0 : (1 - (local - 0.8) / 0.2);
      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.phase + local * p.rotations * pi * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.width,
            height: p.height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.particles != particles;
}
