// Тон общения приложения: gentle (мягкий) / harsh (жёсткий).
// Влияет ТОЛЬКО на тексты, не на логику (правило из app/CLAUDE.md).
// Сохраняется в SharedPreferences.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../theme/theme_provider.dart'; // sharedPreferencesProvider

enum AppTone { gentle, harsh }

const _kToneKey = 'tone_preference';

class ToneNotifier extends Notifier<AppTone> {
  @override
  AppTone build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_kToneKey);
    return saved == 'harsh' ? AppTone.harsh : AppTone.gentle;
  }

  Future<void> toggle() => set(state == AppTone.gentle ? AppTone.harsh : AppTone.gentle);

  Future<void> set(AppTone tone) async {
    await ref.read(sharedPreferencesProvider).setString(
          _kToneKey,
          tone == AppTone.harsh ? 'harsh' : 'gentle',
        );
    state = tone;
  }
}

final toneProvider = NotifierProvider<ToneNotifier, AppTone>(ToneNotifier.new);

/// Тон-зависимые тексты (EN hard-coded) — для обратной совместимости.
/// Для UI с локализацией используй KaiCopy.
class ToneCopy {
  ToneCopy._();

  static String morningReview(AppTone tone, int count) {
    if (tone == AppTone.harsh) {
      return count == 1
          ? '1 task ghosted you. Sort it before it piles up.'
          : '$count tasks ghosted you. I lined them up — don\'t ghost them again.';
    }
    return count == 1
        ? 'Yesterday left 1 loose end — let\'s tuck it into today.'
        : 'Yesterday left $count loose ends — let\'s fit them around what matters.';
  }

  static String allDone(AppTone tone) => tone == AppTone.harsh
      ? 'Everything done. Don\'t get cocky.'
      : 'Everything that mattered — done. Proud of you.';

  /// Вечерний разбор завтрашнего дня (SPEC B6).
  static String eveningReview(AppTone tone, int pending) {
    if (tone == AppTone.harsh) {
      return pending == 0
          ? 'Plan tomorrow now, or wing it and panic. Your call.'
          : '$pending left over today. Plan tomorrow now or wing it and panic.';
    }
    return pending == 0
        ? 'Want tomorrow handled? I\'ve got a plan ready.'
        : '$pending unfinished today — want me to fit them into tomorrow?';
  }
}

/// Локализованные Kai-строки для речевого пузыря (MASCOT.md §4, SPEC B6).
/// Принимает BuildContext — резолвит через систему переводов S.
/// Шаблон {count} заменяется вручную на сайте вызова.
class KaiCopy {
  KaiCopy._();

  /// Утренний разбор.
  static String morningReview(BuildContext context, AppTone tone, int count) {
    if (tone == AppTone.harsh) {
      final key = count == 1
          ? 'kai.morning_review_harsh_one'
          : 'kai.morning_review_harsh_many';
      return S.of(context, key).replaceAll('{count}', '$count');
    }
    final key = count == 1
        ? 'kai.morning_review_gentle_one'
        : 'kai.morning_review_gentle_many';
    return S.of(context, key).replaceAll('{count}', '$count');
  }

  /// Строка для шапки Today — все выполнено.
  static String allDone(BuildContext context, AppTone tone) {
    final key = tone == AppTone.harsh ? 'kai.all_done_harsh' : 'kai.all_done_gentle';
    return S.of(context, key);
  }

  /// Вечерний разбор.
  static String eveningReview(BuildContext context, AppTone tone, int pending) {
    if (tone == AppTone.harsh) {
      final key =
          pending == 0 ? 'kai.evening_none_harsh' : 'kai.evening_pending_harsh';
      return S.of(context, key).replaceAll('{count}', '$pending');
    }
    final key =
        pending == 0 ? 'kai.evening_none_gentle' : 'kai.evening_pending_gentle';
    return S.of(context, key).replaceAll('{count}', '$pending');
  }

  /// Пустое состояние — ничего не запланировано.
  static String emptyDay(BuildContext context, AppTone tone) {
    final key =
        tone == AppTone.harsh ? 'kai.empty_day_harsh' : 'kai.empty_day_gentle';
    return S.of(context, key);
  }

  /// Нейтральный idle (по времени суток).
  static String idle(BuildContext context, AppTone tone, DateTime now) {
    final hour = now.hour;
    final timeKey =
        hour < 12 ? 'morning' : (hour < 18 ? 'afternoon' : 'evening');
    final toneKey = tone == AppTone.harsh ? 'harsh' : 'gentle';
    return S.of(context, 'kai.idle_${timeKey}_$toneKey');
  }
}
