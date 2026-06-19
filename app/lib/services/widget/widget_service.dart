// Обновление домашнего виджета (Android) без сторонних плагинов.
// Dart по MethodChannel передаёт поля в нативный MainActivity, который пишет их
// в SharedPreferences и шлёт broadcast виджету. Так виджет показывает актуальные
// данные даже когда приложение закрыто (значения сохранены).
//
// Расширение data-bridge по §8 WIDGET.md: добавлены next_items, main_done,
// main_total, kai_emotion, is_harsh, theme_*, last_opened_at.
// Старый ключ main_progress сохранён для обратной совместимости с текущим native.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/daos/items_dao.dart';
import '../../core/database/daos/streak_dao.dart';
import '../../core/theme/app_theme.dart';
import 'kai_widget_emotion.dart';

const _channel = MethodChannel('kaizen/widget');

/// Ключ SharedPreferences для сохранения времени последнего открытия приложения.
const kLastOpenedAtKey = 'last_opened_at';

/// Ключ SharedPreferences для тона (используется внутри ToneNotifier).
const _kToneKey = 'tone_preference';

/// Ключ SharedPreferences для темы (используется внутри ThemeNotifier).
const _kThemePrefsKey = 'app_theme_key';

/// Форматтер времени для поля `time` внутри next_items: 'HH:mm' (локальное время).
/// Например: '14:30'. Native-сторона отображает его как есть (строка).
final _timeFmt = DateFormat('HH:mm');

/// Конвертирует [Color] в hex-строку #RRGGBB (без альфа-канала).
/// Использует `.value` (0xAARRGGBB) — работает на всех версиях Flutter 3.
String _colorToHex(Color c) {
  // ignore: deprecated_member_use
  final argb = c.value; // 0xAARRGGBB
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';
}

/// Сохраняет текущий момент как last_opened_at в SharedPreferences.
/// Вызывается при старте и при onResume в main.dart.
Future<void> saveLastOpenedAt() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kLastOpenedAtKey, DateTime.now().toIso8601String());
}

/// Считывает прогресс по main-задачам на сегодня, ближайшие предстоящие
/// пункты, серию, эмоцию Kai и цвета темы — передаёт виджету по MethodChannel.
/// Только Android; на web/desktop/iOS — no-op.
///
/// Параметры:
/// - [itemsDao], [streakDao] — DAO для чтения из Drift.
/// - [prefs] — SharedPreferences (тема, тон, last_opened_at). Если null,
///   получается через SharedPreferences.getInstance().
Future<void> refreshHomeWidget({
  required ItemsDao itemsDao,
  required StreakDao streakDao,
  SharedPreferences? prefs,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  try {
    final now = DateTime.now();

    // SharedPreferences (тема, тон, last_opened_at)
    final sp = prefs ?? await SharedPreferences.getInstance();

    // --- Прогресс главных задач ---
    final mains = await itemsDao.watchMainItems(now).first;
    final mainDone =
        mains.where((i) => i.status == 'done' || i.status == 'skipped').length;
    final mainTotal = mains.length;

    // --- Стрик ---
    final streak = await streakDao.getStreak();
    final streakVal = streak?.current ?? 0;

    // --- Ближайшие пункты дня (до 4) ---
    final upcoming = await itemsDao.upcomingTodayItems(now);
    final nextItems = upcoming.map((item) {
      return {
        // time — локальное 'HH:mm', например '14:30'
        'time': _timeFmt.format(item.scheduledAt.toLocal()),
        'title': item.title,
        'type': item.type, // task / event / exam / deadline
      };
    }).toList();

    // --- Просрочка (для эмоции anxious) ---
    final hasOverdue = await itemsDao.hasOverdueItems(now);

    // --- Последнее открытие ---
    final lastOpenedStr = sp.getString(kLastOpenedAtKey);
    final lastOpenedAt =
        lastOpenedStr != null ? DateTime.tryParse(lastOpenedStr) : null;

    // --- Эмоция Kai ---
    final kaiEmotion = computeKaiWidgetEmotion(
      mainDone: mainDone,
      mainTotal: mainTotal,
      hasOverdue: hasOverdue,
      lastOpenedAt: lastOpenedAt,
      now: now,
    );

    // --- Тон (harsh?) ---
    final toneStr = sp.getString(_kToneKey);
    final isHarsh = toneStr == 'harsh';

    // --- Цвета активной темы ---
    // Читаем ключ темы из prefs; резолвим через AppTheme.forKey.
    // custom-тема без конфига откатится на focus внутри forKey — допустимо,
    // виджет получит корректные цвета (focus-палитра).
    final themeStr = sp.getString(_kThemePrefsKey);
    final themeKey = themeStr != null
        ? AppThemeKey.values.firstWhere(
            (k) => k.prefsKey == themeStr,
            orElse: () => AppThemeKey.focus,
          )
        : AppThemeKey.focus;
    final themeData = AppTheme.forKey(themeKey);
    final cs = themeData.colorScheme;
    final ext =
        themeData.extension<FocusThemeExtension>();

    final themeAccent = _colorToHex(cs.primary);      // accent
    final themeBg = _colorToHex(themeData.scaffoldBackgroundColor); // bg
    final themeSurface = _colorToHex(cs.surface);     // surface
    final themeText = _colorToHex(cs.onSurface);      // text
    final themeTextMuted = _colorToHex(
      ext?.textMuted ?? cs.onSurface.withValues(alpha: 0.6),
    );

    // --- Обратная совместимость: строка main_progress для текущего native ---
    final progress =
        mainTotal == 0 ? 'No main tasks today' : 'Main: $mainDone / $mainTotal';

    // --- Обновляем last_opened_at перед отправкой (виджет увидит актуальный ts) ---
    final lastOpenedIso = lastOpenedAt?.toIso8601String() ?? now.toIso8601String();

    await _channel.invokeMethod<void>('updateWidget', {
      // Обратная совместимость (текущий native читает эти ключи)
      'main_progress': progress,
      'streak': streakVal.toString(),

      // Новые поля §8 WIDGET.md
      'next_items': jsonEncode(nextItems),
      'main_done': mainDone,
      'main_total': mainTotal,
      'kai_emotion': kaiEmotion,
      'is_harsh': isHarsh,
      'theme_accent': themeAccent,
      'theme_bg': themeBg,
      'theme_surface': themeSurface,
      'theme_text': themeText,
      'theme_text_muted': themeTextMuted,
      'last_opened_at': lastOpenedIso,
    });
  } catch (_) {
    // Виджет — вторичен; ошибки не должны влиять на приложение.
  }
}
