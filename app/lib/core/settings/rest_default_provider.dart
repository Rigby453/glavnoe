// Глобальное время отдыха между подходами по умолчанию (секунды).
//
// Зачем: чтобы не настраивать отдых на каждом упражнении вручную. Пользователь
// задаёт «в среднем 2-3 минуты» один раз в Профиле; тренажёр использует это
// значение, когда у упражнения НЕ задан явный per-exercise restSeconds.
//
// Per-exercise restSeconds (workout_exercises.restSeconds) остаётся как
// переопределение: если у упражнения значение ОТЛИЧАЕТСЯ от легаси-маркера
// [kLegacyRestMarkerSeconds] (60 — старый Constant-дефолт колонки), считаем его
// явно заданным и используем как есть. Если значение РАВНО маркеру — упражнение
// «не настраивали», берём глобальный дефолт. Без миграции БД (ADR — prefs).
//
// Хранение в SharedPreferences по образцу water_goal_provider / reminder_default_provider:
// Notifier + NotifierProvider. UI настройки — в Профиле (секция «Тренировки»).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

// ---------------------------------------------------------------------------
// Ключи и константы
// ---------------------------------------------------------------------------

/// Глобальное время отдыха по умолчанию (секунды).
const String kRestDefaultSecondsKey = 'rest_default_seconds';

/// Значение по умолчанию глобального отдыха (секунды). 2 минуты.
const int kDefaultRestSeconds = 120;

/// Легаси-маркер: исходный Constant-дефолт колонки workout_exercises.restSeconds.
/// Если per-exercise restSeconds равен этому значению — считаем, что отдых на
/// упражнении НЕ настраивали явно, и применяем глобальный дефолт. Любое другое
/// значение — это явное переопределение, его и используем.
const int kLegacyRestMarkerSeconds = 60;

/// Границы разумного глобального отдыха (секунды): 15с … 10 мин.
const int kRestDefaultMinSeconds = 15;
const int kRestDefaultMaxSeconds = 600;

/// Возвращает эффективное время отдыха для упражнения:
/// per-exercise [exerciseRestSeconds], если оно явно задано (≠ легаси-маркер),
/// иначе — глобальный [globalDefaultSeconds].
int effectiveRestSeconds({
  required int exerciseRestSeconds,
  required int globalDefaultSeconds,
}) {
  return exerciseRestSeconds == kLegacyRestMarkerSeconds
      ? globalDefaultSeconds
      : exerciseRestSeconds;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class RestDefaultNotifier extends Notifier<int> {
  @override
  int build() {
    final stored =
        ref.read(sharedPreferencesProvider).getInt(kRestDefaultSecondsKey);
    if (stored == null) return kDefaultRestSeconds;
    return stored.clamp(kRestDefaultMinSeconds, kRestDefaultMaxSeconds);
  }

  /// Задать глобальный отдых по умолчанию (секунды), с клампом в разумные границы.
  Future<void> set(int seconds) async {
    final clamped =
        seconds.clamp(kRestDefaultMinSeconds, kRestDefaultMaxSeconds);
    await ref
        .read(sharedPreferencesProvider)
        .setInt(kRestDefaultSecondsKey, clamped);
    state = clamped;
  }
}

/// Глобальное время отдыха между подходами по умолчанию (секунды).
/// Читается тренажёром, когда у упражнения нет явного restSeconds.
final restDefaultProvider =
    NotifierProvider<RestDefaultNotifier, int>(RestDefaultNotifier.new);
