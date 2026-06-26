// Движок реактивного настроения — ЧИСТЫЕ функции без сайд-эффектов.
// Тестируемы в изоляции без Flutter / Riverpod.
// Формула и уровни описаны ниже — источник правды для mood_provider.dart.

/// Уровень настроения Kai/темы (нарастающий).
enum MoodLevel { calm, neutral, stern, angry }

// ---------------------------------------------------------------------------
// computeHeat — «уровень лени/отставания» дня (0.0..1.0)
// ---------------------------------------------------------------------------
//
// Формула:
//   base = 0.0
//   + overdueCount * 0.15          → каждая просрочка добавляет 0.15 (мах ≈ 0.60 при 4+)
//   - mainDone * 0.12              → выполненные главные понижают нагрев
//   + emptyMiddleOfDay * 0.20      → пустой план в рабочее время дня (hasItemsToday=false)
//   + streakAtRisk * 0.25          → стрик под угрозой существенно греет
//   clamp(0.0, 1.0)
//
// Диапазоны heat:
//   0.00..0.20 → спокойно (calm)
//   0.20..0.45 → нейтрально (neutral)
//   0.45..0.75 → строго (stern)
//   0.75..1.00 → сердито (angry)

/// Вычислить «тепло» (уровень лени/отставания) на основе сигналов дня.
///
/// [overdueCount]    — количество просроченных невыполненных задач (из прошлых дней).
/// [mainDone]        — выполненных главных задач сегодня.
/// [mainTotal]       — всего главных задач сегодня (0 → нет плана).
/// [hasItemsToday]   — есть ли хотя бы одна задача сегодня (включая не-main).
/// [streakAtRisk]    — стрик под угрозой (нет выполненных main при конце дня).
///
/// Возвращает значение 0.0..1.0.
double computeHeat({
  required int overdueCount,
  required int mainDone,
  required int mainTotal,
  required bool hasItemsToday,
  required bool streakAtRisk,
}) {
  double heat = 0.0;

  // Просрочки из прошлых дней — каждая +0.15, максимальный вклад ≈ 0.60
  heat += (overdueCount * 0.15).clamp(0.0, 0.60);

  // Выполненные главные понижают нагрев: каждая −0.12
  heat -= (mainDone * 0.12).clamp(0.0, 0.36);

  // Пустой план в рабочее время (нет задач вообще)
  if (!hasItemsToday) {
    heat += 0.20;
  }

  // Стрик под угрозой — ощутимый сигнал
  if (streakAtRisk) {
    heat += 0.25;
  }

  return heat.clamp(0.0, 1.0);
}

// ---------------------------------------------------------------------------
// computeEffectiveMood — эффективное настроение исключительно из тепла дня
// ---------------------------------------------------------------------------
//
// harshness (0.0..1.0):
//   = heat (напрямую; тон и напор НЕ влияют на уровень/выражение Каи)
//
// MoodLevel:
//   harshness < 0.20 → calm
//   harshness < 0.45 → neutral
//   harshness < 0.75 → stern
//   else             → angry
//
// Тон (gentle/harsh) влияет только на манеру/форму (KaiMascot.isHarsh, текст).
// Напор (ReactiveIntensity) влияет только на частоту проактивных реплик.

/// Результат вычисления эффективного настроения.
typedef EffectiveMood = ({MoodLevel level, double harshness});

/// Вычислить итоговое настроение — исключительно из [heat] состояния дня.
///
/// [heat] — нагрев из computeHeat (0.0..1.0).
///
/// Тон и напор больше не входят в расчёт выражения Kai:
///   • тон влияет на форму (isHarsh в KaiMascot) и тексты;
///   • напор влияет только на частоту проактивных реплик.
///
/// Возвращает запись с MoodLevel и числовым harshness.
EffectiveMood computeEffectiveMood({
  required double heat,
}) {
  // harshness = heat: уровень настроения ведётся прямо от состояния дня
  final harshness = heat.clamp(0.0, 1.0);

  final level = switch (harshness) {
    < 0.20 => MoodLevel.calm,
    < 0.45 => MoodLevel.neutral,
    < 0.75 => MoodLevel.stern,
    _ => MoodLevel.angry,
  };

  return (level: level, harshness: harshness);
}
