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
import '../../core/database/daos/day_logs_dao.dart';
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

      // Исходящие записи воды (append-only): добавленные после lastSyncAt
      final localWater = await (_db.select(_db.waterLogsTable)
            ..where((t) => t.loggedAt.isBiggerThanValue(lastSyncDate)))
          .get();
      final outgoingWater = localWater.map(_waterToSnakeCase).toList();

      // Исходящие записи еды (append-only, ADR-024): созданные после lastSyncAt
      final localFood = await (_db.select(_db.foodLogsTable)
            ..where((t) => t.createdAt.isBiggerThanValue(lastSyncDate)))
          .get();
      final outgoingFood = localFood.map(_foodToSnakeCase).toList();

      // Исходящие удаления (tombstones из sync_queue): items, операция delete
      final deleteRows = await (_db.select(_db.syncQueueTable)
            ..where((t) =>
                t.operation.equals('delete') & t.tableName_.equals('items')))
          .get();
      final deletedItemIds =
          deleteRows.map((r) => r.recordId).toSet().toList();

      // Исходящие записи дневника (изменённые после lastSyncAt)
      final dayLogsDao = DayLogsDao(_db);
      final localDayLogs = await dayLogsDao.changedSince(lastSyncDate);
      final outgoingDayLogs = localDayLogs.map(_dayLogToSnakeCase).toList();

      debugPrint(
        '[SyncService] Syncing ${outgoing.length} items, '
        '${outgoingWater.length} water logs, '
        '${outgoingFood.length} food logs, '
        '${outgoingDayLogs.length} day logs, '
        '${deletedItemIds.length} deletions, lastSyncAt=$lastSyncAt',
      );

      // Шаг 4: отправляем на сервер
      final response = await _apiClient.sync(
        outgoing,
        outgoingWater,
        lastSyncAt,
        deletedItemIds: deletedItemIds,
        dayLogs: outgoingDayLogs,
        foodLogs: outgoingFood,
      );

      // Удаления доставлены — очищаем обработанные tombstones
      if (deleteRows.isNotEmpty) {
        final processedIds = deleteRows.map((r) => r.id).toList();
        await (_db.delete(_db.syncQueueTable)
              ..where((t) => t.id.isIn(processedIds)))
            .go();
      }

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

      // Шаг 5b: мержим записи воды от сервера (upsert по id; append-only)
      final updatedWater =
          (response['updated_water_logs'] as List<dynamic>?) ?? <dynamic>[];

      if (updatedWater.isNotEmpty) {
        await _db.transaction(() async {
          for (final raw in updatedWater) {
            if (raw is! Map<String, dynamic>) continue;
            await _db
                .into(_db.waterLogsTable)
                .insertOnConflictUpdate(_waterSnakeCaseToCompanion(raw));
          }
        });
        debugPrint('[SyncService] Merged ${updatedWater.length} water logs');
      }

      // Шаг 5b': мержим записи еды от сервера (upsert по id; append-only)
      final updatedFood =
          (response['updated_food_logs'] as List<dynamic>?) ?? <dynamic>[];
      if (updatedFood.isNotEmpty) {
        await _db.transaction(() async {
          for (final raw in updatedFood) {
            if (raw is! Map<String, dynamic>) continue;
            final companion = _foodSnakeCaseToCompanion(raw);
            if (companion == null) continue;
            await _db.into(_db.foodLogsTable).insertOnConflictUpdate(companion);
          }
        });
        debugPrint('[SyncService] Merged ${updatedFood.length} food logs');
      }

      // Шаг 5c: мержим записи дневника от сервера (ключ — дата; LWW)
      final updatedDayLogs =
          (response['updated_day_logs'] as List<dynamic>?) ?? <dynamic>[];
      if (updatedDayLogs.isNotEmpty) {
        for (final raw in updatedDayLogs) {
          if (raw is! Map<String, dynamic>) continue;
          final dateStr = raw['date'] as String?;
          if (dateStr == null) continue;
          final date = DateTime.tryParse(dateStr);
          if (date == null) continue;
          await dayLogsDao.upsertFromServerByDate(
            date: date,
            mood: (raw['mood'] as num?)?.toInt(),
            note: raw['note'] as String?,
            insight: raw['insight'] as String?,
            createdAt:
                DateTime.tryParse(raw['created_at'] as String? ?? '') ??
                    DateTime.now(),
            updatedAt:
                DateTime.tryParse(raw['updated_at'] as String? ?? '') ??
                    DateTime.now(),
          );
        }
        debugPrint('[SyncService] Merged ${updatedDayLogs.length} day logs');
      }

      // Шаг 5d: применяем удаления с других устройств (без создания нового
      // надгробия — удаляем напрямую, минуя ItemsDao.deleteItem).
      final serverDeletedIds =
          (response['deleted_item_ids'] as List<dynamic>?) ?? <dynamic>[];
      if (serverDeletedIds.isNotEmpty) {
        for (final raw in serverDeletedIds) {
          if (raw is! String) continue;
          await (_db.delete(_db.itemsTable)..where((t) => t.id.equals(raw)))
              .go();
        }
        debugPrint(
          '[SyncService] Applied ${serverDeletedIds.length} remote deletions',
        );
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

  // ---------------------------------------------------------------------------
  // WaterLog: Drift ↔ snake_case
  // ---------------------------------------------------------------------------

  /// Локальная запись воды → snake_case для отправки (user_id ставит сервер).
  Map<String, dynamic> _waterToSnakeCase(WaterLogsTableData log) {
    return {
      'id': log.id,
      'amount_ml': log.amountMl,
      'logged_at': log.loggedAt.toUtc().toIso8601String(),
    };
  }

  /// Ответ сервера (snake_case) → WaterLogsTableCompanion для upsert.
  /// Локальная таблица не хранит user_id — поле игнорируем.
  WaterLogsTableCompanion _waterSnakeCaseToCompanion(Map<String, dynamic> m) {
    return WaterLogsTableCompanion(
      id: Value(m['id'] as String),
      amountMl: Value((m['amount_ml'] as num).toInt()),
      loggedAt: Value(DateTime.parse(m['logged_at'] as String)),
    );
  }

  // ---------------------------------------------------------------------------
  // FoodLog: Drift ↔ snake_case (append-only, ADR-024)
  // ---------------------------------------------------------------------------

  /// Локальная запись еды → snake_case для отправки (user_id ставит сервер).
  Map<String, dynamic> _foodToSnakeCase(FoodLogsTableData f) {
    final u = f.date.toUtc();
    final dateStr = '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
    return {
      'id': f.id,
      'date': dateStr,
      'meal': f.meal,
      'name': f.name,
      'grams': f.grams,
      'calories': f.calories,
      'protein': f.protein,
      'fat': f.fat,
      'carbs': f.carbs,
      'sugar': f.sugar,
      'fiber': f.fiber,
      'created_at': f.createdAt.toUtc().toIso8601String(),
    };
  }

  /// Ответ сервера (snake_case) → FoodLogsTableCompanion для upsert.
  /// null при битой записи (нет обязательных полей).
  FoodLogsTableCompanion? _foodSnakeCaseToCompanion(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    final dateStr = m['date'] as String?;
    final name = m['name'] as String?;
    if (id == null || dateStr == null || name == null) return null;
    final date = DateTime.tryParse('${dateStr}T00:00:00.000Z');
    final createdAt =
        DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now();
    if (date == null) return null;
    return FoodLogsTableCompanion(
      id: Value(id),
      date: Value(date),
      meal: Value((m['meal'] as String?) ?? 'snack'),
      name: Value(name),
      grams: Value((m['grams'] as num?)?.toDouble() ?? 100),
      calories: Value((m['calories'] as num?)?.toDouble()),
      protein: Value((m['protein'] as num?)?.toDouble()),
      fat: Value((m['fat'] as num?)?.toDouble()),
      carbs: Value((m['carbs'] as num?)?.toDouble()),
      sugar: Value((m['sugar'] as num?)?.toDouble()),
      fiber: Value((m['fiber'] as num?)?.toDouble()),
      createdAt: Value(createdAt),
    );
  }

  // ---------------------------------------------------------------------------
  // DayLog → snake_case (для отправки). Дата — YYYY-MM-DD; user_id ставит сервер.
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _dayLogToSnakeCase(DayLogsTableData d) {
    final u = d.date.toUtc();
    final dateStr = '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
    return {
      'date': dateStr,
      'mood': d.mood,
      'note': d.note,
      'updated_at': d.updatedAt.toUtc().toIso8601String(),
    };
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
