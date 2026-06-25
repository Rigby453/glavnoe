// Провайдер реального использования экранного времени на Android.
//
// Читает per-package usage через плагин usage_stats (требует спец-разрешение
// PACKAGE_USAGE_STATS — «Доступ к данным об использовании»), агрегирует минуты
// по нашим 6 категориям через categorizeUsageMinutes() и отдаёт UI:
//   - состояние разрешения (granted / denied / unknown),
//   - использованные минуты по категориям за сегодня (с локальной полуночи),
//   - loading / error.
//
// Платформенная защита: плагин дёргается ТОЛЬКО на Android. На iOS / web / в
// тестах провайдер сразу отдаёт «нет разрешения, пустые данные» и не падает.
// Блокировки приложений НЕТ — Android не позволяет обычным приложениям блокировать
// чужие приложения; мы только показываем использование и предупреждаем о лимите.
//
// Android-fallback: для пакетов, не найденных в нашем whitelist kPackageToCategory,
// запрашиваем ApplicationInfo.category через MethodChannel "kaizen/app_category".
// Это позволяет играм (CATEGORY_GAME=0) попасть в 'games', а не пропасть.
// При любой ошибке канала — пакеты уходят в 'other' (минуты не теряются).

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:usage_stats/usage_stats.dart';

import 'screen_time_categories.dart';

/// Состояние разрешения на доступ к статистике использования.
enum UsagePermissionStatus { unknown, granted, denied }

/// Иммутабельное состояние экрана использования.
@immutable
class ScreenTimeUsageState {
  const ScreenTimeUsageState({
    this.permission = UsagePermissionStatus.unknown,
    this.usedMinutes = const <String, int>{},
    this.isLoading = false,
    this.hasError = false,
  });

  /// Текущий статус разрешения.
  final UsagePermissionStatus permission;

  /// Использованные минуты по категориям (social/video/games/browsing/messaging/other).
  /// Пустая карта = нет данных (нет разрешения / не Android).
  final Map<String, int> usedMinutes;

  /// Идёт загрузка/обновление.
  final bool isLoading;

  /// Произошла ошибка при запросе (плагин кинул исключение).
  final bool hasError;

  /// true, если можно показывать цифры использования.
  bool get isGranted => permission == UsagePermissionStatus.granted;

  ScreenTimeUsageState copyWith({
    UsagePermissionStatus? permission,
    Map<String, int>? usedMinutes,
    bool? isLoading,
    bool? hasError,
  }) {
    return ScreenTimeUsageState(
      permission: permission ?? this.permission,
      usedMinutes: usedMinutes ?? this.usedMinutes,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
    );
  }
}

/// Поддерживается ли реальный сбор статистики (только Android, не в вебе).
bool get _isAndroid {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid;
  } catch (_) {
    // В юнит-тестах Platform может бросать — считаем «не Android».
    return false;
  }
}

/// MethodChannel для получения Android-категорий пакетов.
/// Реализация на Kotlin-стороне — в MainActivity.kt.
const _kAppCategoryChannel = MethodChannel('kaizen/app_category');

/// Запрашивает Android-категории для списка пакетов и преобразует
/// в наши категориальные ключи через [androidCategoryToOurCategory].
/// Возвращает пустую карту если канал недоступен (не-Android, тесты, ошибка).
Future<Map<String, String>> _fetchAndroidCategoryOverrides(
  List<String> packages,
) async {
  if (packages.isEmpty) return const <String, String>{};
  try {
    final raw = await _kAppCategoryChannel.invokeMethod<Map<Object?, Object?>>(
      'getAppCategories',
      packages,
    );
    if (raw == null) return const <String, String>{};

    final result = <String, String>{};
    raw.forEach((pkg, cat) {
      final pkgStr = pkg as String?;
      final catInt = cat as int?;
      if (pkgStr == null || catInt == null) return;
      final ourCat = androidCategoryToOurCategory(catInt);
      if (ourCat != null) {
        result[pkgStr] = ourCat;
      }
      // null ourCat → пакет попадёт в 'other' внутри categorizeUsageMinutes
    });
    return result;
  } catch (_) {
    // Канал недоступен или ошибка прошивки — fallback: пакеты пойдут в 'other'.
    return const <String, String>{};
  }
}

class ScreenTimeUsageNotifier extends StateNotifier<ScreenTimeUsageState> {
  ScreenTimeUsageNotifier() : super(const ScreenTimeUsageState()) {
    // Стартовая проверка разрешения + загрузка (без блокировки конструктора).
    if (_isAndroid) {
      refresh();
    } else {
      // Не-Android / тесты: сразу «нет разрешения», пустые данные.
      state = state.copyWith(permission: UsagePermissionStatus.denied);
    }
  }

  /// Перепроверяет разрешение и, если оно есть, заново читает использование.
  /// Безопасно вызывать на любой платформе — на не-Android ничего не делает.
  Future<void> refresh() async {
    if (!_isAndroid) {
      state = state.copyWith(
        permission: UsagePermissionStatus.denied,
        usedMinutes: const <String, int>{},
        isLoading: false,
        hasError: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, hasError: false);
    try {
      final granted = (await UsageStats.checkUsagePermission()) ?? false;
      if (!granted) {
        state = state.copyWith(
          permission: UsagePermissionStatus.denied,
          usedMinutes: const <String, int>{},
          isLoading: false,
        );
        return;
      }

      final used = await _queryTodayUsage();
      state = state.copyWith(
        permission: UsagePermissionStatus.granted,
        usedMinutes: used,
        isLoading: false,
      );
    } catch (_) {
      // Плагин/прошивка (MIUI/HyperOS) могут вести себя нестабильно —
      // не роняем UI, показываем состояние ошибки.
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }

  /// Открывает системный экран «Доступ к данным об использовании», чтобы
  /// пользователь выдал разрешение. После возврата UI должен вызвать [refresh].
  Future<void> requestPermission() async {
    if (!_isAndroid) return;
    try {
      await UsageStats.grantUsagePermission();
    } catch (_) {
      // Игнорируем — пользователь увидит, что разрешение не выдано, после refresh.
    }
  }

  /// Запрашивает использование за сегодня (с локальной полуночи до «сейчас»),
  /// конвертирует мс → минуты и агрегирует по категориям.
  ///
  /// Для пакетов, не найденных в whitelist kPackageToCategory, дополнительно
  /// запрашивает ApplicationInfo.category через Android MethodChannel —
  /// это позволяет играм и другим приложениям не быть потерянными.
  Future<Map<String, int>> _queryTodayUsage() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    final perPackageStats =
        await UsageStats.queryAndAggregateUsageStats(midnight, now);

    // packageName → минуты в foreground за сегодня.
    // Используем округление вверх (ceiling): 1–59 сек = 1 мин, чтобы короткие сессии
    // (например, игра 30 сек ночью) не терялись при floor-делении на 60000.
    final perPackageMinutes = <String, int>{};
    perPackageStats.forEach((package, info) {
      final ms = info.totalTimeInForegroundMs ?? 0;
      if (ms <= 0) return;
      // ceil: 1..59 999 мс → 1 мин; 60 000 мс → 1 мин; 60 001 мс → 2 мин.
      final minutes = (ms / 60000).ceil();
      perPackageMinutes[package] = minutes;
    });

    // Находим пакеты, которых НЕТ в нашем whitelist — для них нужен Android-fallback.
    final unknownPackages = perPackageMinutes.keys
        .where((pkg) => !kPackageToCategory.containsKey(pkg))
        .toList();

    // Запрашиваем Android-категории для неизвестных пакетов.
    // На не-Android / в тестах _fetchAndroidCategoryOverrides вернёт {}.
    final androidOverrides = _isAndroid
        ? await _fetchAndroidCategoryOverrides(unknownPackages)
        : const <String, String>{};

    return categorizeUsageMinutes(
      perPackageMinutes,
      androidCategoryOverrides: androidOverrides,
    );
  }
}

final screenTimeUsageProvider =
    StateNotifierProvider<ScreenTimeUsageNotifier, ScreenTimeUsageState>(
  (ref) => ScreenTimeUsageNotifier(),
);
