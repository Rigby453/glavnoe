// Юнит-тесты движка дыхательных упражнений.
// Проверяем: границы фаз, прогресс в середине фазы, второй цикл.

import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/health/breathing_engine.dart';

void main() {
  // Простой пресет 4-4 (вдох 4с, выдох 4с) — удобно для арифметики
  const phases = [
    BreathPhase(label: 'Inhale', duration: Duration(seconds: 4), expand: true),
    BreathPhase(label: 'Exhale', duration: Duration(seconds: 4), expand: false),
  ];

  group('phaseAt — первый цикл', () {
    test('elapsed=0 → первая фаза, прогресс=0, цикл=0', () {
      final r = phaseAt(phases, Duration.zero);
      expect(r.phase.label, 'Inhale');
      expect(r.phaseProgress, 0.0);
      expect(r.cycleIndex, 0);
    });

    test('середина первой фазы (elapsed=2s) → прогресс=0.5', () {
      final r = phaseAt(phases, const Duration(seconds: 2));
      expect(r.phase.label, 'Inhale');
      expect(r.phaseProgress, closeTo(0.5, 1e-9));
      expect(r.cycleIndex, 0);
    });

    test('конец первой фазы (elapsed=4s) → вторая фаза начинается', () {
      final r = phaseAt(phases, const Duration(seconds: 4));
      expect(r.phase.label, 'Exhale');
      expect(r.phaseProgress, closeTo(0.0, 1e-9));
      expect(r.cycleIndex, 0);
    });

    test('середина второй фазы (elapsed=6s) → прогресс=0.5', () {
      final r = phaseAt(phases, const Duration(seconds: 6));
      expect(r.phase.label, 'Exhale');
      expect(r.phaseProgress, closeTo(0.5, 1e-9));
      expect(r.cycleIndex, 0);
    });
  });

  group('phaseAt — второй цикл', () {
    test('начало второго цикла (elapsed=8s) → первая фаза, цикл=1', () {
      final r = phaseAt(phases, const Duration(seconds: 8));
      expect(r.phase.label, 'Inhale');
      expect(r.phaseProgress, closeTo(0.0, 1e-9));
      expect(r.cycleIndex, 1);
    });

    test('середина первой фазы второго цикла (elapsed=10s) → прогресс=0.5, цикл=1', () {
      final r = phaseAt(phases, const Duration(seconds: 10));
      expect(r.phase.label, 'Inhale');
      expect(r.phaseProgress, closeTo(0.5, 1e-9));
      expect(r.cycleIndex, 1);
    });

    test('третий цикл (elapsed=16s) → цикл=2', () {
      final r = phaseAt(phases, const Duration(seconds: 16));
      expect(r.phase.label, 'Inhale');
      expect(r.cycleIndex, 2);
    });
  });

  group('phaseAt — Box 4-4-4-4', () {
    final boxPhases = breathingPresets[0].phases; // Box 4-4-4-4

    test('elapsed=0 → Inhale', () {
      final r = phaseAt(boxPhases, Duration.zero);
      expect(r.phase.label, 'Inhale');
      expect(r.phase.hold, false);
    });

    test('elapsed=4s → Hold (первый)', () {
      final r = phaseAt(boxPhases, const Duration(seconds: 4));
      expect(r.phase.label, 'Hold');
      expect(r.phase.expand, true); // hold после вдоха — расширен
      expect(r.phase.hold, true);
    });

    test('elapsed=8s → Exhale', () {
      final r = phaseAt(boxPhases, const Duration(seconds: 8));
      expect(r.phase.label, 'Exhale');
      expect(r.phase.expand, false);
    });

    test('elapsed=12s → Hold (второй)', () {
      final r = phaseAt(boxPhases, const Duration(seconds: 12));
      expect(r.phase.label, 'Hold');
      expect(r.phase.expand, false); // hold после выдоха — сжат
      expect(r.phase.hold, true);
    });

    test('elapsed=16s → второй цикл Inhale, cycleIndex=1', () {
      final r = phaseAt(boxPhases, const Duration(seconds: 16));
      expect(r.phase.label, 'Inhale');
      expect(r.cycleIndex, 1);
    });
  });

  group('phaseAt — Calm 4-7-8', () {
    final calmPhases = breathingPresets[1].phases;

    test('cycleDuration = 19s', () {
      expect(breathingPresets[1].cycleDuration, const Duration(seconds: 19));
    });

    test('elapsed=4s → Hold', () {
      final r = phaseAt(calmPhases, const Duration(seconds: 4));
      expect(r.phase.label, 'Hold');
    });

    test('elapsed=11s → Exhale', () {
      final r = phaseAt(calmPhases, const Duration(seconds: 11));
      expect(r.phase.label, 'Exhale');
    });

    test('прогресс в середине Exhale: elapsed=15s → progress≈0.5', () {
      // Exhale начинается в 11s, длится 8s → середина в 15s
      final r = phaseAt(calmPhases, const Duration(seconds: 15));
      expect(r.phase.label, 'Exhale');
      expect(r.phaseProgress, closeTo(0.5, 1e-9));
    });
  });

  group('phaseAt — Simple 5-5', () {
    final simplePhases = breathingPresets[2].phases;

    test('cycleDuration = 10s', () {
      expect(breathingPresets[2].cycleDuration, const Duration(seconds: 10));
    });

    test('elapsed=5s → Exhale', () {
      final r = phaseAt(simplePhases, const Duration(seconds: 5));
      expect(r.phase.label, 'Exhale');
    });
  });

  group('BreathingPreset.cycleDuration', () {
    test('Box 4-4-4-4 → 16s', () {
      expect(breathingPresets[0].cycleDuration, const Duration(seconds: 16));
    });
  });
}
