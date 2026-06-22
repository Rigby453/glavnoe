// Тон общения приложения: gentle (мягкий) / harsh (жёсткий).
// Влияет ТОЛЬКО на тексты, не на логику (правило из app/CLAUDE.md).
// Сохраняется в SharedPreferences.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart'; // FocusThemeExtension (ember)
import '../theme/theme_provider.dart'; // sharedPreferencesProvider

enum AppTone { gentle, harsh }

/// Визуальный «язык» тона — единый источник для оформления, чтобы связь
/// «режим → вид» читалась мгновенно (gentle = мягко/спокойно, harsh = строго).
///
/// Резолвится из текущей темы (переиспользует дизайн-токены, не вводит новые
/// цвета): gentle берёт accent (primary), harsh — ember (secondary/срочное).
/// Используется в превью профиля и в шапках, где Kai обращается к пользователю.
class ToneVisuals {
  const ToneVisuals._({
    required this.accent,
    required this.icon,
    required this.emoji,
    required this.cornerRadius,
    required this.headingWeight,
    required this.isHarsh,
  });

  /// Акцентный цвет тона: gentle → accent (primary), harsh → ember.
  final Color accent;

  /// Иконка-маркер тона: gentle → росток, harsh → молния.
  final IconData icon;

  /// Эмодзи-маркер (для пресетов/заголовков): 🌿 / 🔥.
  final String emoji;

  /// Радиус скругления карточек: gentle мягче, harsh резче/строже.
  final double cornerRadius;

  /// Насыщенность заголовков мотивации: harsh — плотнее/жирнее.
  final FontWeight headingWeight;

  /// Удобный флаг (для KaiMascot.isHarsh и пр.).
  final bool isHarsh;

  /// Построить визуалы тона из текущего контекста темы.
  factory ToneVisuals.of(BuildContext context, AppTone tone) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final harsh = tone == AppTone.harsh;
    return ToneVisuals._(
      accent: harsh
          ? (ext?.ember ?? scheme.secondary) // ember — «срочно/строго»
          : scheme.primary, // accent — спокойный
      icon: harsh ? Icons.bolt : Icons.spa_outlined,
      emoji: harsh ? '🔥' : '🌿',
      cornerRadius: harsh ? 8 : 18,
      headingWeight: harsh ? FontWeight.w800 : FontWeight.w600,
      isHarsh: harsh,
    );
  }
}

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

  /// Образец сообщения для ЖИВОГО превью в Профиле — показывает, как Kai
  /// обращается к пользователю в выбранном тоне (gentle мягко / harsh резко).
  static String preview(BuildContext context, AppTone tone) {
    final key = tone == AppTone.harsh ? 'kai.preview_harsh' : 'kai.preview_gentle';
    return S.of(context, key);
  }

  /// Короткий ярлык-«вайб» тона для бейджа превью (одно слово).
  static String previewVibe(BuildContext context, AppTone tone) {
    final key =
        tone == AppTone.harsh ? 'kai.vibe_harsh' : 'kai.vibe_gentle';
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
