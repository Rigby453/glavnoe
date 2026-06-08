// Тон общения приложения: gentle (мягкий) / harsh (жёсткий).
// Влияет ТОЛЬКО на тексты, не на логику (правило из app/CLAUDE.md).
// Сохраняется в SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Тон-зависимые тексты для ключевых моментов (EN, из SPEC B6).
class ToneCopy {
  ToneCopy._();

  static String morningReview(AppTone tone, int count) {
    if (tone == AppTone.harsh) {
      return count == 1
          ? '1 task ghosted you. Sort it before it piles up.'
          : "$count tasks ghosted you. I lined them up — don't ghost them again.";
    }
    return count == 1
        ? 'Yesterday left 1 loose end — let’s tuck it into today.'
        : "Yesterday left $count loose ends — let’s fit them around what matters.";
  }

  static String allDone(AppTone tone) => tone == AppTone.harsh
      ? 'Everything done. Don’t get cocky.'
      : 'Everything that mattered — done. Proud of you.';
}
