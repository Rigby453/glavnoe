// Бесплатные «зашитые» советы по экранному времени для каждой категории.
// Чистая (без BuildContext, без I/O) логика: по факту использования и лимиту
// определяем уровень (ok / much / tooMuch) и строим ключ локализованной фразы
// с учётом тона (gentle / harsh). Легко тестируется юнит-тестами.
//
// TODO(premium): платный AI-совет (персональный, через backend) — ВНЕ объёма
//   этого прохода. Здесь только бесплатные канонические фразы. Когда появится
//   премиум-путь, он должен подменять/дополнять эти фразы для подписчиков,
//   не трогая чистые функции screenTimeLevel / screenTimeAdviceKey.

import '../../core/settings/tone_provider.dart'; // AppTone

/// Уровень нагрузки по категории относительно эффективного порога.
enum ScreenTimeLevel { ok, much, tooMuch }

/// Пороги по умолчанию (минуты), применяются когда пользователь НЕ задал лимит
/// для категории (limit == 0). Подобраны как «мягкая дневная норма».
const kScreenTimeDefaultThresholds = <String, int>{
  'social': 60,
  'video': 90,
  'games': 120,
  'browsing': 60,
  'messaging': 90,
};

/// Доля порога, с которой использование считается «много» (но ещё не «слишком»).
const double _kMuchFraction = 0.66;

/// Определяет уровень нагрузки.
///
/// Эффективный порог = заданный лимит (если > 0), иначе дефолт по категории.
/// Затем: used >= порог → tooMuch; used >= 66% порога → much; иначе ok.
/// Чистая функция: без BuildContext и I/O.
ScreenTimeLevel screenTimeLevel(
  int usedMinutes,
  int limitMinutes,
  String category,
) {
  final threshold = limitMinutes > 0
      ? limitMinutes
      : (kScreenTimeDefaultThresholds[category] ?? 60);
  if (usedMinutes >= threshold) return ScreenTimeLevel.tooMuch;
  if (usedMinutes >= _kMuchFraction * threshold) return ScreenTimeLevel.much;
  return ScreenTimeLevel.ok;
}

/// Строит ключ локализованной фразы совета:
///   `screentime_advice_{category}_{level}_{tone}`
/// level: ok | much | too_much ; tone: gentle | harsh.
/// Чистая функция: без BuildContext.
String screenTimeAdviceKey(
  String category,
  ScreenTimeLevel level,
  AppTone tone,
) {
  final levelKey = switch (level) {
    ScreenTimeLevel.ok => 'ok',
    ScreenTimeLevel.much => 'much',
    ScreenTimeLevel.tooMuch => 'too_much',
  };
  final toneKey = tone == AppTone.harsh ? 'harsh' : 'gentle';
  return 'screentime_advice_${category}_${levelKey}_$toneKey';
}
