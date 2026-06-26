// Провайдер эффективного настроения: вычисляет EffectiveMood из сигналов дня
// через чистые функции mood_engine.dart.
//
// Уровень настроения (level) и harshness определяются ТОЛЬКО heat'ом:
//   heat=0 → calm; heat=0.2..0.45 → neutral; heat=0.45..0.75 → stern; ≥0.75 → angry.
//
// Тон (gentle/harsh) и напор (ReactiveIntensity) НЕ влияют на MoodLevel/harshness.
// Они читаются провайдерами-потребителями для:
//   • тон  → KaiMascot.isHarsh (форма глаз/брови), тексты реплик;
//   • напор → частота проактивных реплик.
//
// Зависимости для heat:
//   overduePendingProvider — просроченные задачи
//   todayMainItemsProvider — main-задачи сегодня
//   todayItemsProvider     — все задачи сегодня

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../database/database_providers.dart';
import '../settings/tone_provider.dart';
import 'mood_engine.dart';
import 'reactive_intensity_provider.dart';

export 'mood_engine.dart' show MoodLevel, computeHeat, computeEffectiveMood,
    EffectiveMood;
export 'reactive_intensity_provider.dart' show ReactiveIntensity,
    ReactiveIntensityMultiplier, ReactiveIntensityNotifier,
    reactiveIntensityProvider;

// ---------------------------------------------------------------------------
// Сигналы дня (переиспользуем уже существующие провайдеры из today_screen)
// ---------------------------------------------------------------------------

/// Просроченные невыполненные задачи из прошлых дней (тот же стрим, что в МorningReviewCard).
/// Объявлен здесь как отдельный провайдер, чтобы mood мог наблюдать без
/// circular dependency с today_screen.dart.
final _moodOverdueProvider =
    StreamProvider<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchOverduePending(DateTime.now());
});

/// Все задачи сегодня — для определения пустого дня.
final _moodTodayAllProvider =
    StreamProvider<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchTodayItems(DateTime.now());
});

/// Только main-задачи сегодня — для счёта выполненных.
final _moodTodayMainProvider =
    StreamProvider<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchMainItems(DateTime.now());
});

// ---------------------------------------------------------------------------
// effectiveMoodProvider — основной провайдер настроения
// ---------------------------------------------------------------------------

/// Эффективное настроение: MoodLevel + числовой harshness (0..1).
/// Пересчитывается реактивно при изменении сигналов дня.
/// MoodLevel зависит ТОЛЬКО от heat — тон и напор вид не меняют.
final effectiveMoodProvider = Provider<EffectiveMood>((ref) {
  // Тон и напор НЕ наблюдаются здесь: они не входят в расчёт MoodLevel.
  // Потребители (KaiMascot, _TonePreview, KaiCopy) читают toneProvider напрямую.
  final overdueItems = ref.watch(_moodOverdueProvider).valueOrNull ?? const [];
  final todayAll = ref.watch(_moodTodayAllProvider).valueOrNull ?? const [];
  final todayMain = ref.watch(_moodTodayMainProvider).valueOrNull ?? const [];

  // Сигнал «стрик под угрозой»: время >= 20:00, есть main-задачи, не все выполнены
  final now = DateTime.now();
  final streakAtRisk = now.hour >= 20 &&
      todayMain.isNotEmpty &&
      todayMain.any((i) => i.status == 'pending');

  final mainDone = todayMain.where((i) => i.status == 'done').length;
  final mainTotal = todayMain.length;

  final heat = computeHeat(
    overdueCount: overdueItems.length,
    mainDone: mainDone,
    mainTotal: mainTotal,
    hasItemsToday: todayAll.isNotEmpty,
    streakAtRisk: streakAtRisk,
  );

  return computeEffectiveMood(heat: heat);
});

// ---------------------------------------------------------------------------
// MoodPreset — пресеты для пульта в профиле
// ---------------------------------------------------------------------------

/// Три именованных пресета настроя.
enum MoodPreset {
  calm,   // Спокойный:       tone=gentle, intensity=off
  normal, // Обычный:         tone=gentle, intensity=slight
  coach,  // Жёсткий тренер:  tone=harsh,  intensity=full
}

/// Применить пресет: устанавливает tone + intensity одним вызовом.
/// Пример: applyMoodPreset(ref, MoodPreset.coach)
Future<void> applyMoodPreset(WidgetRef ref, MoodPreset preset) async {
  switch (preset) {
    case MoodPreset.calm:
      await ref.read(toneProvider.notifier).set(AppTone.gentle);
      await ref.read(reactiveIntensityProvider.notifier).set(ReactiveIntensity.off);
    case MoodPreset.normal:
      await ref.read(toneProvider.notifier).set(AppTone.gentle);
      await ref.read(reactiveIntensityProvider.notifier).set(ReactiveIntensity.slight);
    case MoodPreset.coach:
      await ref.read(toneProvider.notifier).set(AppTone.harsh);
      await ref.read(reactiveIntensityProvider.notifier).set(ReactiveIntensity.full);
  }
}
