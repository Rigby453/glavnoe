// Riverpod провайдеры темы — Kaname redesign v4.
// Тема хранит только ключ поверхности (AppThemeKey); акцент и highContrast — отдельно.
// По умолчанию: тема=day, акцент=indigo, highContrast=false.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'custom_theme_provider.dart';
import '../mood/mood_provider.dart';

const _kThemePrefsKey = 'app_theme_key';
const _kAccentPrefsKey = 'app_accent_key';
const _kHighContrastPrefsKey = 'app_high_contrast';

/// Провайдер SharedPreferences — инициализируется в main перед ProviderScope.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'SharedPreferences must be overridden in ProviderScope',
  ),
);

// ---------------------------------------------------------------------------
// Тема
// ---------------------------------------------------------------------------

/// Нотифер ключа темы. При первом запуске = day.
/// Автоматически мигрирует старые ключи (focus→night, white→day, contrast→day, custom→day).
class ThemeNotifier extends Notifier<AppThemeKey> {
  @override
  AppThemeKey build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_kThemePrefsKey);
    if (saved == null) return AppThemeKey.day; // умолчание Kaname = day
    return _migrateKey(saved);
  }

  Future<void> setTheme(AppThemeKey key) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kThemePrefsKey, key.prefsKey);
    state = key;
  }

  /// Переводит старые prefs-ключи v3 в новые v4.
  static AppThemeKey _migrateKey(String raw) => switch (raw) {
        'focus' => AppThemeKey.night,    // Focus (тёплый тёмный) → Night
        'white' => AppThemeKey.day,      // White (светлая)       → Day
        'contrast' => AppThemeKey.day,   // Contrast (доступность) → Day + highContrast
        'custom' => AppThemeKey.day,     // My Theme               → Day (Phase 4)
        _ => AppThemeKey.values.firstWhere(
            (k) => k.prefsKey == raw,
            orElse: () => AppThemeKey.day,
          ),
      };
}

/// Провайдер ключа темы.
final themeNotifierProvider =
    NotifierProvider<ThemeNotifier, AppThemeKey>(ThemeNotifier.new);

// ---------------------------------------------------------------------------
// Акцент
// ---------------------------------------------------------------------------

/// Нотифер выбранного акцента. По умолчанию indigo.
class AccentNotifier extends Notifier<AccentKey> {
  @override
  AccentKey build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_kAccentPrefsKey);
    if (saved == null) return AccentKey.indigo;
    return AccentKey.values.firstWhere(
      (k) => k.name == saved,
      orElse: () => AccentKey.indigo,
    );
  }

  Future<void> setAccent(AccentKey key) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kAccentPrefsKey, key.name);
    state = key;
  }
}

/// Провайдер акцента (Phase 4 подключит picker в Profile→Appearance).
final accentNotifierProvider =
    NotifierProvider<AccentNotifier, AccentKey>(AccentNotifier.new);

// ---------------------------------------------------------------------------
// High-contrast (настройка доступности, не тема)
// ---------------------------------------------------------------------------

/// Нотифер настройки высокого контраста. По умолчанию false.
class HighContrastNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_kHighContrastPrefsKey) ?? false;
  }

  Future<void> setHighContrast(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kHighContrastPrefsKey, value);
    state = value;
  }
}

/// Провайдер настройки высокого контраста.
final highContrastProvider =
    NotifierProvider<HighContrastNotifier, bool>(HighContrastNotifier.new);

// ---------------------------------------------------------------------------
// themeDataProvider — итоговый ThemeData
// ---------------------------------------------------------------------------

/// Итоговый ThemeData: наблюдает тему + акцент + highContrast + harshness (тон).
/// При дефолтных настройках harshness=0.0 → цвета без изменений.
final themeDataProvider = Provider<ThemeData>((ref) {
  final key = ref.watch(themeNotifierProvider);
  final accent = ref.watch(accentNotifierProvider);
  final highContrast = ref.watch(highContrastProvider);
  final mood = ref.watch(effectiveMoodProvider);
  // customThemeNotifierProvider оставлен (нужен CustomThemeEditorScreen),
  // но в v4 custom-тема является shim → AppTheme.build игнорирует конфиг.
  ref.watch(customThemeNotifierProvider); // подписка сохранена
  return AppTheme.build(
    theme: key,
    accent: accent,
    highContrast: highContrast,
    harshness: mood.harshness,
  );
});
