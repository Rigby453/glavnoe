// Обновление домашнего виджета (Android) без сторонних плагинов.
// Dart по MethodChannel передаёт строки в нативный MainActivity, который пишет их
// в SharedPreferences и шлёт broadcast виджету. Так виджет показывает актуальные
// цифры даже когда приложение закрыто (значения сохранены).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/database/daos/items_dao.dart';
import '../../core/database/daos/streak_dao.dart';

const _channel = MethodChannel('kaizen/widget');

/// Считывает прогресс по main-задачам на сегодня и серию, пишет их в виджет.
/// Только Android; на web/desktop/iOS — no-op.
Future<void> refreshHomeWidget({
  required ItemsDao itemsDao,
  required StreakDao streakDao,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  try {
    final now = DateTime.now();
    final mains = await itemsDao.watchMainItems(now).first;
    final done =
        mains.where((i) => i.status == 'done' || i.status == 'skipped').length;
    final total = mains.length;
    final streak = await streakDao.getStreak();

    final progress = total == 0 ? 'No main tasks today' : 'Main: $done / $total';

    await _channel.invokeMethod<void>('updateWidget', {
      'main_progress': progress,
      'streak': (streak?.current ?? 0).toString(),
    });
  } catch (_) {
    // Виджет — вторичен; ошибки не должны влиять на приложение.
  }
}
