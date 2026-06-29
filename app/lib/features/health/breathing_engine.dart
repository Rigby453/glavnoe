// Движок дыхательных упражнений — чистая логика без зависимостей на Flutter.
// Не хранит состояние: все функции — чистые вычисления по elapsed.

/// Одна фаза дыхательного цикла.
class BreathPhase {
  const BreathPhase({
    required this.label,
    required this.duration,
    required this.expand,
    this.hold = false,
  });

  /// Ключ локализации фазы ('Inhale', 'Hold', 'Exhale').
  /// Резолвится в месте отображения через context.s(phase.label).
  /// ВНИМАНИЕ: breathing_screen.dart:226 (_colorForPhaseLabel) и :244 (_localizePhaseLabel)
  /// всё ещё используют old-EN switch — оркестратор должен обновить их на новые ключи.
  final String label;

  /// Длительность фазы.
  final Duration duration;

  /// true = вдох (круг растёт), false = выдох (круг сжимается).
  /// При hold — значение expand фиксирует предыдущее состояние круга.
  final bool expand;

  /// true = задержка дыхания (статичный круг).
  final bool hold;
}

/// Пресет дыхательного упражнения.
class BreathingPreset {
  const BreathingPreset({required this.name, required this.phases});

  final String name;
  final List<BreathPhase> phases;

  /// Суммарная длительность одного цикла.
  Duration get cycleDuration =>
      phases.fold(Duration.zero, (acc, p) => acc + p.duration);
}

// ---------------------------------------------------------------------------
// Пресеты (константы)
// ---------------------------------------------------------------------------

// Метки фаз — ВНУТРЕННИЕ switch-ключи на EN ('Inhale'/'Hold'/'Exhale'); пользователю
// напрямую НЕ показываются. В breathing_screen.dart цвет фазы выбирается switch'ем по
// этой метке (_colorForPhaseLabel), а для показа метка локализуется через
// _localizePhaseLabel → context.s('breathing.inhale'|'hold'|'exhale'). Не локализовать здесь.
const breathingPresets = [
  BreathingPreset(
    name: 'Box 4-4-4-4',
    phases: [
      BreathPhase(label: 'Inhale', duration: Duration(seconds: 4), expand: true),
      BreathPhase(label: 'Hold',   duration: Duration(seconds: 4), expand: true,  hold: true),
      BreathPhase(label: 'Exhale', duration: Duration(seconds: 4), expand: false),
      BreathPhase(label: 'Hold',   duration: Duration(seconds: 4), expand: false, hold: true),
    ],
  ),
  BreathingPreset(
    name: 'Calm 4-7-8',
    phases: [
      BreathPhase(label: 'Inhale', duration: Duration(seconds: 4), expand: true),
      BreathPhase(label: 'Hold',   duration: Duration(seconds: 7), expand: true,  hold: true),
      BreathPhase(label: 'Exhale', duration: Duration(seconds: 8), expand: false),
    ],
  ),
  BreathingPreset(
    name: 'Simple 5-5',
    phases: [
      BreathPhase(label: 'Inhale', duration: Duration(seconds: 5), expand: true),
      BreathPhase(label: 'Exhale', duration: Duration(seconds: 5), expand: false),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Результат вычисления текущей фазы
// ---------------------------------------------------------------------------

/// Текущее состояние в цикле: фаза, прогресс внутри фазы 0..1, номер цикла.
class PhaseResult {
  const PhaseResult({
    required this.phase,
    required this.phaseProgress,
    required this.cycleIndex,
  });

  final BreathPhase phase;

  /// Прогресс от 0.0 до 1.0 внутри текущей фазы.
  final double phaseProgress;

  /// Индекс цикла (0-based), увеличивается с каждым полным циклом.
  final int cycleIndex;
}

// ---------------------------------------------------------------------------
// Вычисление фазы по elapsed
// ---------------------------------------------------------------------------

/// Возвращает текущую фазу и прогресс для заданного [elapsed].
///
/// Цикл повторяется бесконечно через модуль суммарной длительности.
/// Если [phases] пуст — бросает [ArgumentError].
PhaseResult phaseAt(List<BreathPhase> phases, Duration elapsed) {
  assert(phases.isNotEmpty, 'phases must not be empty');

  // Суммарная длительность цикла в микросекундах
  final cycleMicros = phases.fold<int>(
    0,
    (acc, p) => acc + p.duration.inMicroseconds,
  );

  if (cycleMicros <= 0) {
    return PhaseResult(
      phase: phases.first,
      phaseProgress: 0.0,
      cycleIndex: 0,
    );
  }

  final elapsedMicros = elapsed.inMicroseconds.clamp(0, elapsed.inMicroseconds);
  final cycleIndex = elapsedMicros ~/ cycleMicros;
  final posInCycle = elapsedMicros % cycleMicros;

  // Находим фазу по позиции внутри цикла
  int cursor = 0;
  for (final phase in phases) {
    final phaseMicros = phase.duration.inMicroseconds;
    if (posInCycle < cursor + phaseMicros) {
      final posInPhase = posInCycle - cursor;
      final progress = phaseMicros > 0 ? posInPhase / phaseMicros : 0.0;
      return PhaseResult(
        phase: phase,
        phaseProgress: progress.clamp(0.0, 1.0),
        cycleIndex: cycleIndex,
      );
    }
    cursor += phaseMicros;
  }

  // Граница цикла — возвращаем первую фазу следующего цикла
  return PhaseResult(
    phase: phases.first,
    phaseProgress: 0.0,
    cycleIndex: cycleIndex + 1,
  );
}
