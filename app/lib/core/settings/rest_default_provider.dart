// Глобальное время отдыха между подходами по умолчанию (секунды).
//
// Зачем: чтобы не настраивать отдых на каждом упражнении вручную. Пользователь
// задаёт «в среднем 2-3 минуты» один раз в Профиле; тренажёр использует это
// значение, когда у упражнения НЕ задан явный per-exercise restSeconds.
//
// Сентинель «использовать глобальный дефолт» = kUseDefaultRest (-1).
// Это ЯВНЫЙ маркер «не настраивали», добавленный в A3. Устраняет путаницу с
// числом 60 — теперь пользователь может явно выставить 60с и получить ровно 60с.
//
// Обратная совместимость: [kLegacyRestMarkerSeconds] = 60 — старый Constant-дефолт
// колонки workout_exercises.restSeconds. Существующие записи в БД со значением 60
// по-прежнему рассматриваются как «не настраивали» → применяется глобальный дефолт.
// Это сохраняет старое поведение тренажёра без миграции данных.
// Новые записи пишут kUseDefaultRest (-1), поэтому 60 со временем исчезнет.
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

/// Явный сентинель «использовать глобальный дефолт» (A3).
/// Хранится в workout_exercises.restSeconds вместо старого магического 60.
/// Тренажёр и карточка редактора проверяют это значение через [effectiveRestSeconds]
/// и [isUseDefaultRest].
const int kUseDefaultRest = -1;

/// Легаси-маркер: исходный Constant-дефолт колонки workout_exercises.restSeconds.
/// Хранится только в СТАРЫХ записях БД (созданных до A3). Обратная совместимость:
/// effectiveRestSeconds обрабатывает его так же, как kUseDefaultRest.
/// Новые записи пишут kUseDefaultRest вместо этого значения.
const int kLegacyRestMarkerSeconds = 60;

/// Границы разумного глобального отдыха (секунды): 15с … 10 мин.
const int kRestDefaultMinSeconds = 15;
const int kRestDefaultMaxSeconds = 600;

/// Возвращает true, если [restSeconds] означает «использовать глобальный дефолт».
/// Охватывает и новый сентинель (kUseDefaultRest = -1), и легаси-маркер (60).
bool isUseDefaultRest(int restSeconds) =>
    restSeconds == kUseDefaultRest || restSeconds == kLegacyRestMarkerSeconds;

/// Возвращает эффективное время отдыха для упражнения:
/// - kUseDefaultRest (-1): явный «использовать глобальный дефолт» → [globalDefaultSeconds]
/// - kLegacyRestMarkerSeconds (60): старая запись «не настраивали» → [globalDefaultSeconds]
/// - любое другое значение: явное per-exercise переопределение → используется как есть.
int effectiveRestSeconds({
  required int exerciseRestSeconds,
  required int globalDefaultSeconds,
}) {
  return isUseDefaultRest(exerciseRestSeconds)
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
