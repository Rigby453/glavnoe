// Юнит-тесты для mood_engine.dart.
// Чистые функции — нет Flutter, нет Riverpod, нет БД.
// Тестируем крайние случаи computeHeat и все ветки computeEffectiveMood.
// v2 (рефакторинг): computeEffectiveMood принимает только heat (тон/напор не входят).

import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/mood/mood_engine.dart';

void main() {
  // ---------------------------------------------------------------------------
  // computeHeat
  // ---------------------------------------------------------------------------

  group('computeHeat', () {
    test('нет сигналов → 0.0 (идеальный день)', () {
      final heat = computeHeat(
        overdueCount: 0,
        mainDone: 0,
        mainTotal: 3,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      expect(heat, 0.0);
    });

    test('пустой план → 0.20 (средний нагрев)', () {
      final heat = computeHeat(
        overdueCount: 0,
        mainDone: 0,
        mainTotal: 0,
        hasItemsToday: false,
        streakAtRisk: false,
      );
      expect(heat, closeTo(0.20, 0.001));
    });

    test('стрик под угрозой → 0.25', () {
      final heat = computeHeat(
        overdueCount: 0,
        mainDone: 0,
        mainTotal: 1,
        hasItemsToday: true,
        streakAtRisk: true,
      );
      expect(heat, closeTo(0.25, 0.001));
    });

    test('одна просрочка → 0.15', () {
      final heat = computeHeat(
        overdueCount: 1,
        mainDone: 0,
        mainTotal: 1,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      expect(heat, closeTo(0.15, 0.001));
    });

    test('5 просрочек → clamp 0.60 (не > 1.0)', () {
      final heat = computeHeat(
        overdueCount: 5,
        mainDone: 0,
        mainTotal: 0,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      expect(heat, closeTo(0.60, 0.001));
    });

    test('выполненные main снижают нагрев', () {
      final heatBefore = computeHeat(
        overdueCount: 2,
        mainDone: 0,
        mainTotal: 3,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      final heatAfter = computeHeat(
        overdueCount: 2,
        mainDone: 3,
        mainTotal: 3,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      expect(heatAfter, lessThan(heatBefore));
    });

    test('максимальный нагрев ≤ 1.0', () {
      final heat = computeHeat(
        overdueCount: 100,
        mainDone: 0,
        mainTotal: 0,
        hasItemsToday: false,
        streakAtRisk: true,
      );
      expect(heat, lessThanOrEqualTo(1.0));
    });

    test('heat не может быть < 0.0 (выполненные не уводят в минус)', () {
      final heat = computeHeat(
        overdueCount: 0,
        mainDone: 10,
        mainTotal: 10,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      expect(heat, greaterThanOrEqualTo(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // computeEffectiveMood
  // ---------------------------------------------------------------------------

  group('computeEffectiveMood', () {
    // v2: harshness = heat напрямую; тон и напор НЕ входят в расчёт.

    test('heat=0 → calm (harshness=0.0)', () {
      final mood = computeEffectiveMood(heat: 0.0);
      expect(mood.harshness, closeTo(0.0, 0.001));
      expect(mood.level, MoodLevel.calm);
    });

    test('heat=0.10 → calm (< 0.20)', () {
      final mood = computeEffectiveMood(heat: 0.10);
      expect(mood.harshness, closeTo(0.10, 0.001));
      expect(mood.level, MoodLevel.calm);
    });

    test('heat=0.19 → calm (граница, < 0.20)', () {
      final mood = computeEffectiveMood(heat: 0.19);
      expect(mood.level, MoodLevel.calm);
    });

    test('heat=0.20 → neutral (граница, ≥ 0.20)', () {
      final mood = computeEffectiveMood(heat: 0.20);
      expect(mood.harshness, closeTo(0.20, 0.001));
      expect(mood.level, MoodLevel.neutral);
    });

    test('heat=0.30 → neutral (0.20..0.45)', () {
      final mood = computeEffectiveMood(heat: 0.30);
      expect(mood.harshness, closeTo(0.30, 0.001));
      expect(mood.level, MoodLevel.neutral);
    });

    test('heat=0.45 → stern (граница, ≥ 0.45)', () {
      final mood = computeEffectiveMood(heat: 0.45);
      expect(mood.level, MoodLevel.stern);
    });

    test('heat=0.60 → stern (0.45..0.75)', () {
      final mood = computeEffectiveMood(heat: 0.60);
      expect(mood.harshness, closeTo(0.60, 0.001));
      expect(mood.level, MoodLevel.stern);
    });

    test('heat=0.75 → angry (граница, ≥ 0.75)', () {
      final mood = computeEffectiveMood(heat: 0.75);
      expect(mood.level, MoodLevel.angry);
    });

    test('heat=0.80 → angry (≥ 0.75)', () {
      final mood = computeEffectiveMood(heat: 0.80);
      expect(mood.harshness, closeTo(0.80, 0.001));
      expect(mood.level, MoodLevel.angry);
    });

    test('heat=1.0 → angry, harshness clamp 1.0', () {
      final mood = computeEffectiveMood(heat: 1.0);
      expect(mood.harshness, closeTo(1.0, 0.001));
      expect(mood.level, MoodLevel.angry);
    });

    test('harshness = heat (тон и напор не влияют на уровень)', () {
      // Инвариант: harshness всегда равен переданному heat
      const testCases = [0.0, 0.15, 0.35, 0.55, 0.85, 1.0];
      for (final h in testCases) {
        final mood = computeEffectiveMood(heat: h);
        expect(mood.harshness, closeTo(h, 0.001),
            reason: 'При heat=$h harshness должна быть $h');
      }
    });
  });
}
