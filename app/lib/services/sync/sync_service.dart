// Офлайн-первый сервис синхронизации Kaizen
// Принцип: сначала запись в Drift, синхронизация — вторична.
// Стратегия слияния: last-write-wins по updated_at (сервер авторитетен для возвращаемых им записей).
//
// Текущие ограничения:
// - Удалённые локально записи НЕ синхронизируются: мы отправляем дельту по updated_at,
//   удалённые строки просто отсутствуют в локальной БД.
// TODO: track deletes via SyncQueueTable (таблица уже существует в схеме)

// Именованные параметры конструктора не могут начинаться с "_", поэтому поля
// присваиваются через список инициализации (а не initializing formals).
// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../api/api_client.dart';

class SyncService {
  SyncService({
    required ApiClient apiClient,
    required AppDatabase db,
  })  : _apiClient = apiClient,
        _db = db;

  final ApiClient _apiClient;
  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Основной метод синхронизации
  // ---------------------------------------------------------------------------

  /// Выполняет дельта-синхронизацию с сервером.
  ///
  /// 1. Проверяет наличие токена — без авторизации синхронизация бессмысленна.
  /// 2. Читает last_sync_at из SharedPreferences (по умолчанию — эпоха).
  /// 3. Собирает локальные записи, изменённые после last_sync_at (исходящие).
  /// 4. Вызывает POST /api/v1/sync.
  /// 5. Мержит updated_items из ответа в Drift через insertOnConflictUpdate
  ///    (last-write-wins: сервер авторитетен для возвращаемых записей).
  /// 6. Обновляет last_sync_at = DateTime.now().toUtc().
  ///
  /// Все ошибки поглощаются: метод никогда не бросает в UI — offline-first.
  Future<void> syncNow() async {
    // Шаг 1: без токена синхронизацию не запускаем
    if (_apiClient.token == null) {
      debugPrint('[SyncService] No auth token — skipping sync');
      return;
    }

    try {
      // Шаг 2: читаем метку последней синхронизации
      final lastSyncAt = _apiClient.lastSyncAt;
      final lastSyncDate = DateTime.parse(lastSyncAt);

      // Шаг 3: локальные записи, обновлённые ПОСЛЕ lastSyncAt (исходящие изменения)
      final localItems = await (_db.select(_db.itemsTable)
            ..where((t) => t.updatedAt.isBiggerThanValue(lastSyncDate)))
          .get();

      final outgoing = localItems.map(_itemToSnakeCase).toList();

      debugPrint(
        '[SyncService] Syncing ${outgoing.length} outgoing items, lastSyncAt=$lastSyncAt',
      );

      // Шаг 4: отправляем на сервер
      final response = await _apiClient.sync(outgoing, lastSyncAt);

      // Шаг 5: мержим входящие обновления от сервера в Drift
      final updatedItems =
          (response['updated_items'] as List<dynamic>?) ?? <dynamic>[];

      if (updatedItems.isNotEmpty) {
        await _db.transaction(() async {
          for (final raw in updatedItems) {
            if (raw is! Map<String, dynamic>) continue;
            final companion = _snakeCaseToCompanion(raw);
            await _db
                .into(_db.itemsTable)
                .insertOnConflictUpdate(companion);
          }
        });
        debugPrint('[SyncService] Merged ${updatedItems.length} server items');
      }

      // Шаг 6: сохраняем метку успешной синхронизации
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await _apiClient.saveLastSyncAt(nowUtc);
      debugPrint('[SyncService] Sync complete, last_sync_at=$nowUtc');
    } catch (e, stack) {
      // Offline-first: ошибки синхронизации не должны ломать UI
      debugPrint('[SyncService] Sync failed: $e');
      debugPrintStack(label: '[SyncService]', stackTrace: stack);
    }
  }

  // ---------------------------------------------------------------------------
  // Конвертация ItemsTableData → snake_case Map (для API)
  // ---------------------------------------------------------------------------

  /// Сериализует локальную запись в snake_case для отправки на сервер.
  /// user_id = 'local' до реализации авторизации; сервер игнорирует это поле
  /// и подставляет свой userId из JWT.
  Map<String, dynamic> _itemToSnakeCase(ItemsTableData item) {
    return {
      'id': item.id,
      'user_id': item.userId, // сервер перезапишет своим userId
      'title': item.title,
      'type': item.type,
      'priority': item.priority,
      'status': item.status,
      'scheduled_at': item.scheduledAt.toUtc().toIso8601String(),
      'duration_minutes': item.durationMinutes,
      'is_protected': item.isProtected,
      'recurrence_rule': item.recurrenceRule,
      'created_at': item.createdAt.toUtc().toIso8601String(),
      'updated_at': item.updatedAt.toUtc().toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // Конвертация snake_case Map (от сервера) → ItemsTableCompanion (для Drift)
  // ---------------------------------------------------------------------------

  /// Парсит ответ сервера (snake_case) в Drift-companion для upsert.
  /// Поля обязательны согласно схеме Item в api-spec.yaml.
  ItemsTableCompanion _snakeCaseToCompanion(Map<String, dynamic> m) {
    return ItemsTableCompanion(
      id: Value(m['id'] as String),
      userId: Value(m['user_id'] as String),
      title: Value(m['title'] as String),
      type: Value(m['type'] as String),
      priority: Value((m['priority'] as String?) ?? 'medium'),
      status: Value((m['status'] as String?) ?? 'pending'),
      scheduledAt: Value(DateTime.parse(m['scheduled_at'] as String)),
      durationMinutes: Value((m['duration_minutes'] as int?) ?? 30),
      isProtected: Value((m['is_protected'] as bool?) ?? false),
      recurrenceRule: Value(m['recurrence_rule'] as String?),
      createdAt: Value(DateTime.parse(m['created_at'] as String)),
      updatedAt: Value(DateTime.parse(m['updated_at'] as String)),
    );
  }
}

// ---------------------------------------------------------------------------
// Riverpod провайдер
// ---------------------------------------------------------------------------

/// Провайдер сервиса синхронизации.
/// Зависит от apiClientProvider, appDatabaseProvider, sharedPreferencesProvider.
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    apiClient: ref.read(apiClientProvider),
    db: ref.read(appDatabaseProvider),
  );
});
