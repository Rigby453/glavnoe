// Пользовательский размер шрифта (доступность). Применяется глобально через
// MediaQuery.textScaler в main.dart и комбинируется с бонусом темы Contrast.
// Сохраняется в SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

enum TextSizePref { small, normal, large, larger }

extension TextSizePrefX on TextSizePref {
  /// Множитель масштаба текста.
  double get scale => switch (this) {
        TextSizePref.small => 0.9,
        TextSizePref.normal => 1.0,
        TextSizePref.large => 1.15,
        TextSizePref.larger => 1.3,
      };

  String get label => switch (this) {
        TextSizePref.small => 'Small',
        TextSizePref.normal => 'Default',
        TextSizePref.large => 'Large',
        // «Larger» звучало невнятно (ревью MVP) — это максимальный размер.
        TextSizePref.larger => 'Extra large',
      };
}

const _kTextSizeKey = 'text_size_preference';

class TextScaleNotifier extends Notifier<TextSizePref> {
  @override
  TextSizePref build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_kTextSizeKey);
    return TextSizePref.values.firstWhere(
      (p) => p.name == saved,
      orElse: () => TextSizePref.normal,
    );
  }

  Future<void> set(TextSizePref pref) async {
    await ref.read(sharedPreferencesProvider).setString(_kTextSizeKey, pref.name);
    state = pref;
  }
}

final textScaleProvider =
    NotifierProvider<TextScaleNotifier, TextSizePref>(TextScaleNotifier.new);
