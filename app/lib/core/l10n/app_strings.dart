import 'package:flutter/material.dart';

import 'strings/common.dart';
import 'strings/today.dart';
import 'strings/plan_diary.dart';
import 'strings/food.dart';
import 'strings/profile_paywall.dart';
import 'strings/misc.dart';
import 'strings/health_a.dart';
import 'strings/health_b.dart';

/// Система переводов приложения.
///
/// Строки хранятся во фрагментах `strings/*.dart` (по одному на группу экранов),
/// чтобы их можно было редактировать независимо. Каждый ключ —
/// `'key': {'en': ..., 'ru': ..., 'de': ...}`.
///
/// Использование в UI: `context.s('today.main_tasks')`.
/// Если ключа нет в активном языке → откат на en → на сам ключ (никогда не падает).
class S {
  S._();

  // Объединённая карта всех фрагментов: key -> { langCode -> текст }.
  static final Map<String, Map<String, String>> _all = {
    ...commonStrings,
    ...todayStrings,
    ...planDiaryStrings,
    ...foodStrings,
    ...profilePaywallStrings,
    ...miscStrings,
    ...healthAStrings,
    ...healthBStrings,
  };

  static String of(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;
    final entry = _all[key];
    return entry?[lang] ?? entry?['en'] ?? key;
  }
}

/// Удобное расширение: `context.s('key')`.
extension SContext on BuildContext {
  String s(String key) => S.of(this, key);
}
