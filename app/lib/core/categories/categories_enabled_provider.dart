// Riverpod провайдер флага «категории включены».
//
// По умолчанию OFF (design-tokens §categories: "optional, OFF by default").
// Персистируется в SharedPreferences по ключу 'categories_enabled'.
//
// Использование:
//   final enabled = ref.watch(categoriesEnabledProvider);
//   ref.read(categoriesEnabledProvider.notifier).toggle();
//   ref.read(categoriesEnabledProvider.notifier).set(true);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

const _kCategoriesEnabledKey = 'categories_enabled';

/// Нотифер: хранит флаг «показывать цветные точки категорий».
///
/// По умолчанию [false]. Состояние персистируется в SharedPreferences.
class CategoriesEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    // getBool возвращает null если ключ отсутствует → дефолт false.
    return prefs.getBool(_kCategoriesEnabledKey) ?? false;
  }

  /// Переключить флаг на противоположное значение.
  Future<void> toggle() => set(!state);

  /// Установить флаг явно и сохранить в SharedPreferences.
  Future<void> set(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kCategoriesEnabledKey, value);
    state = value;
  }
}

/// Провайдер флага «категории включены».
///
/// Читайте через `ref.watch(categoriesEnabledProvider)` в виджетах.
/// Управляйте через `ref.read(categoriesEnabledProvider.notifier).toggle()`.
final categoriesEnabledProvider =
    NotifierProvider<CategoriesEnabledNotifier, bool>(
  CategoriesEnabledNotifier.new,
);
