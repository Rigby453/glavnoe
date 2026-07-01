// Триггеры фоновой синхронизации Kaizen (сверх логина и AppLifecycleListener
// в main.dart — см. их там).
//
// syncNow() сам по себе вызывается только при логине и при возврате
// приложения на передний план (resume). Этого недостаточно: пока приложение
// открыто и активно, задачи, добавленные/изменённые на этом устройстве, не
// уезжают на сервер до следующего resume — а на web resume вообще ненадёжен
// (см. web_visibility_web.dart, там объяснение через движок Flutter-web).
//
// Этот сервис добавляет два дополнительных триггера:
//   1. Периодический синк (Timer.periodic), пока приложение на переднем плане.
//   2. Web: синк при возврате вкладки в видимость (document.visibilitychange),
//      независимо от (ненадёжного на web) AppLifecycleListener.onResume.
//
// Оба триггера — fire-and-forget и no-op без токена (см. также
// SyncService.syncNow, который сам не делает сетевой запрос без токена —
// проверка здесь дополнительно избегает даже входа в try-блок синка).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'sync_service.dart';
import 'web_visibility.dart' show registerVisibilityListener;

/// Интервал периодического синка, пока приложение на переднем плане.
const Duration kPeriodicSyncInterval = Duration(seconds: 45);

/// Провайдер интервала — существует ОТДЕЛЬНО от константы, чтобы тесты могли
/// подставить короткий интервал через override (без реального ожидания 45с).
/// В проде всегда возвращает [kPeriodicSyncInterval].
final periodicSyncIntervalProvider = Provider<Duration>(
  (ref) => kPeriodicSyncInterval,
);

class SyncTriggerService {
  SyncTriggerService(this._ref);

  final Ref _ref;

  Timer? _timer;

  /// Отписка от web-слушателя visibilitychange; null если ещё не
  /// регистрировали (или мы не на web — там регистрация no-op).
  void Function()? _cancelWebVisibility;

  /// Запускает периодический таймер синка + (один раз, на web) слушатель
  /// visibilitychange. Идемпотентен: повторный вызов пересоздаёт таймер, но
  /// не плодит второй web-слушатель.
  ///
  /// Звать при холодном старте приложения и при каждом resume.
  void start() {
    _timer?.cancel();
    // Немедленный синк при старте/resume — не ждём первого тика таймера.
    _syncIfAuthenticated();
    // Интервал через провайдер (в проде = kPeriodicSyncInterval), чтобы тесты
    // могли подставить короткий период через override без ожидания 45с.
    _timer = Timer.periodic(
      _ref.read(periodicSyncIntervalProvider),
      (_) => _syncIfAuthenticated(),
    );

    if (kIsWeb && _cancelWebVisibility == null) {
      _cancelWebVisibility = registerVisibilityListener(_syncIfAuthenticated);
    }
  }

  /// Останавливает периодический таймер. Web-слушатель НЕ снимается здесь —
  /// он дешёвый (одна подписка на document на всё время жизни таба) и должен
  /// продолжать ловить возврат видимости даже если start() ещё не звали
  /// повторно; снимается только в [dispose].
  ///
  /// Звать при уходе приложения в фон (pause/hide), чтобы не дёргать сеть
  /// впустую, пока пользователь не смотрит на экран.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Полная остановка: таймер + отписка от web-слушателя.
  /// Звать при dispose корневого виджета / провайдера — иначе слушатель на
  /// document переживёт приложение (утечка на web).
  void dispose() {
    stop();
    _cancelWebVisibility?.call();
    _cancelWebVisibility = null;
  }

  void _syncIfAuthenticated() {
    // Без токена syncNow() сам не пойдёт в сеть, но проверяем здесь заранее,
    // чтобы гостевой режим/разлогин не создавали лишних Future и логов.
    if (_ref.read(apiClientProvider).token == null) return;
    // fire-and-forget: syncNow гасит свои ошибки внутри try/catch.
    unawaited(_ref.read(syncServiceProvider).syncNow());
  }
}

/// Провайдер сервиса триггеров синхронизации.
/// Живёт всё время жизни приложения (как syncServiceProvider/apiClientProvider);
/// dispose() вызывается автоматически при уничтожении ProviderScope.
final syncTriggerServiceProvider = Provider<SyncTriggerService>((ref) {
  final service = SyncTriggerService(ref);
  ref.onDispose(service.dispose);
  return service;
});
