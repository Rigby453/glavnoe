import 'package:flutter/material.dart';

import 'strings/common.dart';
import 'strings/today.dart';
import 'strings/plan_diary.dart';
import 'strings/food.dart';
import 'strings/profile_paywall.dart';
import 'strings/misc.dart';
import 'strings/health_a.dart';
import 'strings/health_b.dart';
import 'strings/onboarding_quiz.dart';
import 'strings/workouts_library.dart';
import 'strings/warmup.dart';

/// Система переводов приложения.
///
/// Строки хранятся во фрагментах `strings/*.dart` (по одному на группу экранов),
/// чтобы их можно было редактировать независимо. Каждый ключ —
/// `'key': {'en': ..., 'ru': ..., 'de': ...}`.
///
/// Использование в UI: `context.s('today.main_tasks')`.
/// Если ключа нет в активном языке → откат на en → на сам ключ (никогда не падает).
///
/// Поддержка региональных тегов:
///   - 'pt-BR' → ищет 'pt-BR', затем 'pt', затем 'en'
///   - 'es-ES' → ищет 'es-ES', затем 'es', затем 'en'
///   - Прочие ('fr', 'it', 'hi', 'ja', 'ko', 'id') → ищет по languageCode напрямую
class S {
  S._();

  // Объединённая карта всех фрагментов: key -> { langTag -> текст }.
  static final Map<String, Map<String, String>> _all = {
    ...commonStrings,
    ...todayStrings,
    ...planDiaryStrings,
    ...foodStrings,
    ...profilePaywallStrings,
    ...miscStrings,
    ...healthAStrings,
    ...healthBStrings,
    ...onboardingQuizStrings,
    ...workoutsLibraryStrings,
    ...warmupStrings,
  };

  /// Полная карта строк (key → {langTag → текст}) — только для read-only
  /// потребителей, которым нужны ВСЕ локали ключа (напр. reverse-lookup
  /// «локализованное имя упражнения → группа мышц», Part 2). Не мутировать.
  static Map<String, Map<String, String>> get all => _all;

  static String of(BuildContext context, String key) {
    final locale = Localizations.localeOf(context);
    final entry = _all[key];
    if (entry == null) return key;

    // Строим тег с countryCode если есть: 'pt-BR', 'es-ES'
    final tag = (locale.countryCode != null && locale.countryCode!.isNotEmpty)
        ? '${locale.languageCode}-${locale.countryCode}'
        : locale.languageCode;

    // Резолвинг: точный тег → languageCode → en → key
    return entry[tag] ??
        entry[locale.languageCode] ??
        entry['en'] ??
        key;
  }
}

/// Удобное расширение: `context.s('key')`.
extension SContext on BuildContext {
  String s(String key) => S.of(this, key);
}
